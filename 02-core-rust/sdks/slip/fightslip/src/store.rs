//! The observable bet slip. Both hosts used to keep their own copy of `syncMode` and
//! `placeBet`; those live here now, so a rule change lands once.

use crate::engine::SlipEngine;
use crate::ffi::{parse_amount, SlipError, SlipHandle, SlipSnapshot, SlipStateRecord};
use fightcore::money;
use fightcore::types::{BetSlip, Selection};
use rust_decimal::Decimal;
use std::sync::{Arc, Mutex, MutexGuard};

/// Receives the whole slip after every change. There is no replay on registration: a host
/// reads `current_snapshot` once to start from, and is told about every change after that.
#[uniffi::export(foreign)]
pub trait SlipSnapshotListener: Send + Sync {
    fn on_snapshot(&self, snapshot: SlipSnapshot);
}

struct StoreInner {
    slip: BetSlip,
    balance: Decimal,
    /// Set by a successful `place_bet`, cleared by the next change to the legs. Both hosts
    /// used to keep this and decide for themselves when it went away.
    confirmation: Option<String>,
    engine: Arc<SlipEngine>,
    listeners: Vec<Arc<dyn SlipSnapshotListener>>,
}

fn lock(inner: &Mutex<StoreInner>) -> MutexGuard<'_, StoreInner> {
    inner.lock().unwrap_or_else(|poisoned| poisoned.into_inner())
}

#[derive(uniffi::Object)]
pub struct BetSlipStore {
    inner: Mutex<StoreInner>,
}

#[uniffi::export]
impl BetSlipStore {
    #[uniffi::constructor]
    pub fn new(handle: Arc<SlipHandle>, balance: String) -> Result<Arc<Self>, SlipError> {
        let balance = parse_amount("balance", &balance)?;
        Ok(Arc::new(Self {
            inner: Mutex::new(StoreInner {
                slip: BetSlip {
                    mode: SlipEngine::mode_for(0),
                    selections: vec![],
                    stake: money::parse_exact("10.00"),
                    stake_raw: "10.00".to_string(),
                },
                balance,
                confirmation: None,
                engine: Arc::clone(&handle.engine),
                listeners: vec![],
            }),
        }))
    }

    pub fn add_listener(&self, listener: Arc<dyn SlipSnapshotListener>) {
        lock(&self.inner).listeners.push(listener);
    }

    pub fn current_snapshot(&self) -> SlipSnapshot {
        Self::snapshot_of(&lock(&self.inner))
    }

    pub fn set_stake(&self, stake: String) {
        {
            let mut inner = lock(&self.inner);
            inner.slip.stake_raw = stake.clone();
            // Keep the last good stake when the text is garbage; validation reads stake_raw.
            if let Ok(parsed) = money::try_parse(&stake) {
                inner.slip.stake = parsed;
            }
        }
        self.notify();
    }

    pub fn toggle_selection(&self, bout_id: String, fighter_id: String, odds: String) {
        {
            let mut inner = lock(&self.inner);
            let parsed_odds = money::try_parse(&odds).unwrap_or(Decimal::ZERO);
            let existing = inner.slip.selections.iter().position(|s| s.bout_id == bout_id);
            match existing {
                Some(index) if inner.slip.selections[index].fighter_id == fighter_id => {
                    inner.slip.selections.remove(index);
                }
                Some(index) => {
                    inner.slip.selections[index] =
                        Selection { bout_id, fighter_id, odds: parsed_odds };
                }
                None => inner
                    .slip
                    .selections
                    .push(Selection { bout_id, fighter_id, odds: parsed_odds }),
            }
            Self::sync_mode(&mut inner);
            inner.confirmation = None;
        }
        self.notify();
    }

    pub fn remove_selection(&self, bout_id: String, fighter_id: String) {
        {
            let mut inner = lock(&self.inner);
            inner
                .slip
                .selections
                .retain(|s| !(s.bout_id == bout_id && s.fighter_id == fighter_id));
            Self::sync_mode(&mut inner);
            inner.confirmation = None;
        }
        self.notify();
    }

    pub fn deposit(&self, amount: String) -> Result<String, SlipError> {
        let parsed = parse_amount("amount", &amount)?;
        let balance = {
            let mut inner = lock(&self.inner);
            inner.balance += parsed;
            inner.balance
        };
        self.notify();
        Ok(money::format(balance))
    }

    /// Validates, takes the stake, empties the slip and leaves the confirmation in the next
    /// snapshot. A slip with errors is left exactly as it was: the hosts disable the button
    /// while any error stands, so there is nothing to report back.
    pub fn place_bet(&self) {
        {
            let mut inner = lock(&self.inner);
            let state = inner.engine.slip_state(&inner.slip, inner.balance);
            if !state.errors.is_empty() {
                return;
            }
            inner.balance -= state.total_stake;
            inner.slip.selections.clear();
            Self::sync_mode(&mut inner);
            inner.confirmation = Some(format!(
                "{} returns if it lands",
                money::format_currency(state.potential_return)
            ));
        }
        self.notify();
    }
}

impl BetSlipStore {
    fn sync_mode(inner: &mut StoreInner) {
        inner.slip.mode = SlipEngine::mode_for(inner.slip.selections.len());
    }

    fn snapshot_of(inner: &StoreInner) -> SlipSnapshot {
        SlipSnapshot {
            slip: inner.slip.clone().into(),
            state: SlipStateRecord::new(
                inner.engine.slip_state(&inner.slip, inner.balance),
                &inner.slip,
            ),
            balance: money::format(inner.balance),
            balance_display: money::format_currency(inner.balance),
            confirmation: inner.confirmation.clone(),
        }
    }

    /// Listeners may re-enter and call back into the store; never hold the mutex across them.
    fn notify(&self) {
        let (snapshot, listeners) = {
            let inner = lock(&self.inner);
            (Self::snapshot_of(&inner), inner.listeners.clone())
        };
        for listener in listeners {
            listener.on_snapshot(snapshot.clone());
        }
    }
}
