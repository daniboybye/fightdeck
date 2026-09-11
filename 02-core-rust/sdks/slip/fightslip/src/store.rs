//! The observable bet slip. Both hosts used to keep their own copy of `syncMode` and
//! `placeBet`; those live here now, so a rule change lands once.

use crate::engine::SlipEngine;
use crate::ffi::{
    parse_amount, BetSlipRecord, BetModeRecord, PlaceBetOutcome, SlipError, SlipHandle,
    SlipStateRecord,
};
use fightcore::money;
use fightcore::types::{BetSlip, Selection};
use rust_decimal::Decimal;
use std::sync::{Arc, Mutex, MutexGuard};

#[uniffi::export(foreign)]
pub trait SlipStateListener: Send + Sync {
    fn on_slip_state_changed(&self, state: SlipStateRecord);
}

struct StoreInner {
    slip: BetSlip,
    balance: Decimal,
    engine: Arc<SlipEngine>,
    listeners: Vec<Arc<dyn SlipStateListener>>,
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
                engine: Arc::clone(&handle.engine),
                listeners: vec![],
            }),
        }))
    }

    pub fn add_listener(&self, listener: Arc<dyn SlipStateListener>) {
        lock(&self.inner).listeners.push(listener);
        self.notify();
    }

    pub fn current_state(&self) -> SlipStateRecord {
        let inner = lock(&self.inner);
        Self::state_of(&inner)
    }

    pub fn current_slip(&self) -> BetSlipRecord {
        lock(&self.inner).slip.clone().into()
    }

    pub fn balance(&self) -> String {
        money::format(lock(&self.inner).balance)
    }

    pub fn mode(&self) -> BetModeRecord {
        lock(&self.inner).slip.mode.into()
    }

    pub fn set_balance(&self, balance: String) -> Result<(), SlipError> {
        let parsed = parse_amount("balance", &balance)?;
        lock(&self.inner).balance = parsed;
        self.notify();
        Ok(())
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
        }
        self.notify();
    }

    pub fn clear(&self) {
        {
            let mut inner = lock(&self.inner);
            inner.slip.selections.clear();
            Self::sync_mode(&mut inner);
        }
        self.notify();
    }

    pub fn is_selected(&self, bout_id: String, fighter_id: String) -> bool {
        lock(&self.inner)
            .slip
            .selections
            .iter()
            .any(|s| s.bout_id == bout_id && s.fighter_id == fighter_id)
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

    /// Validates, takes the stake, empties the slip and reports the confirmation copy. This
    /// was the last betting workflow still written twice in Swift and Kotlin.
    pub fn place_bet(&self) -> PlaceBetOutcome {
        let outcome = {
            let mut inner = lock(&self.inner);
            let state = inner.engine.slip_state(&inner.slip, inner.balance);
            if !state.errors.is_empty() {
                PlaceBetOutcome {
                    placed: false,
                    stake_taken: money::format(Decimal::ZERO),
                    new_balance: money::format(inner.balance),
                    potential_return: money::format(state.potential_return),
                    message: None,
                    errors: state.errors.into_iter().map(Into::into).collect(),
                }
            } else {
                inner.balance -= state.total_stake;
                inner.slip.selections.clear();
                Self::sync_mode(&mut inner);
                PlaceBetOutcome {
                    placed: true,
                    stake_taken: money::format(state.total_stake),
                    new_balance: money::format(inner.balance),
                    potential_return: money::format(state.potential_return),
                    message: Some(format!(
                        "{} returns if it lands",
                        money::format_currency(state.potential_return)
                    )),
                    errors: vec![],
                }
            }
        };
        self.notify();
        outcome
    }
}

impl BetSlipStore {
    fn sync_mode(inner: &mut StoreInner) {
        inner.slip.mode = SlipEngine::mode_for(inner.slip.selections.len());
    }

    fn state_of(inner: &StoreInner) -> SlipStateRecord {
        SlipStateRecord::new(
            inner.engine.slip_state(&inner.slip, inner.balance),
            &inner.slip,
        )
    }

    /// Listeners may re-enter and call back into the store; never hold the mutex across them.
    fn notify(&self) {
        let (state, listeners) = {
            let inner = lock(&self.inner);
            (Self::state_of(&inner), inner.listeners.clone())
        };
        for listener in listeners {
            listener.on_slip_state_changed(state.clone());
        }
    }
}
