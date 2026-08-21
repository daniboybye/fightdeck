//! UniFFI boundary types and exports.

use crate::core::{
    BetMode, BetSlip, BoutIndex, CashOutOffer, FightCore, LegOutcome, Selection, Settlement,
    SettlementStatus, SlipState, ValidationError,
};
use crate::money;
use crate::odds;
use rust_decimal::Decimal;
use std::collections::HashSet;
use std::sync::{Arc, Mutex};

// MARK: - Errors

#[derive(Debug, thiserror::Error, uniffi::Error)]
pub enum FightCoreError {
    #[error("network")]
    Network { retryable: bool },
    #[error("decoding")]
    Decoding { field: String },
    #[error("validation")]
    Validation { errors: Vec<ValidationErrorRecord> },
}

// MARK: - Records exposed across FFI

#[derive(uniffi::Record, Clone, Debug)]
pub struct SelectionRecord {
    pub bout_id: String,
    pub fighter_id: String,
    pub odds: String,
}

#[derive(uniffi::Enum, Clone, Debug, PartialEq, Eq)]
pub enum BetModeRecord {
    Single,
    Accumulator,
}

#[derive(uniffi::Record, Clone, Debug)]
pub struct BetSlipRecord {
    pub mode: BetModeRecord,
    pub selections: Vec<SelectionRecord>,
    pub stake: String,
}

#[derive(uniffi::Enum, Clone, Debug, PartialEq, Eq)]
pub enum ValidationErrorRecord {
    EmptySlip,
    StakeBelowMinimum,
    StakeAboveMaximum,
    InsufficientBalance,
    TooManySelections,
    AccumulatorNeedsTwoLegs,
    DuplicateBout,
    UnknownBout,
    FighterNotInBout,
    PayoutExceedsLimit,
}

#[derive(uniffi::Record, Clone, Debug)]
pub struct SlipStateRecord {
    pub combined_odds_exact: Option<String>,
    pub combined_odds_display: Option<String>,
    pub total_stake: String,
    pub potential_return: String,
    pub potential_profit: String,
    pub errors: Vec<ValidationErrorRecord>,
}

#[derive(uniffi::Enum, Clone, Debug, PartialEq, Eq)]
pub enum LegOutcomeRecord {
    Won,
    Lost,
    Void,
}

#[derive(uniffi::Record, Clone, Debug)]
pub struct LegResultRecord {
    pub bout_id: String,
    pub fighter_id: String,
    pub outcome: LegOutcomeRecord,
}

#[derive(uniffi::Enum, Clone, Debug, PartialEq, Eq)]
pub enum SettlementStatusRecord {
    Won,
    Lost,
    Void,
    PartiallyWon,
}

#[derive(uniffi::Record, Clone, Debug)]
pub struct SettlementRecord {
    pub legs: Vec<LegResultRecord>,
    pub returned: String,
    pub profit: String,
    pub status: SettlementStatusRecord,
}

#[derive(uniffi::Record, Clone, Debug)]
pub struct CashOutOfferRecord {
    pub available: bool,
    pub amount: String,
    pub reason: Option<String>,
}

#[derive(uniffi::Record, Clone, Debug)]
pub struct BoutIndexRecord {
    pub id: String,
    pub red_fighter_id: String,
    pub blue_fighter_id: String,
    pub winner_id: String,
}

#[derive(uniffi::Record, Clone, Debug)]
pub struct EventRecord {
    pub id: String,
    pub name: String,
    pub date: String,
    pub venue: String,
    pub city: String,
    pub poster_path: String,
    pub bouts: Vec<BoutRecord>,
}

#[derive(uniffi::Record, Clone, Debug)]
pub struct BoutRecord {
    pub id: String,
    pub order: u32,
    pub segment: String,
    pub weight_class: String,
    pub title_fight: bool,
    pub scheduled_rounds: u32,
    pub red_fighter_id: String,
    pub red_fighter_name: String,
    pub red_odds: String,
    pub blue_fighter_id: String,
    pub blue_fighter_name: String,
    pub blue_odds: String,
    pub winner_id: String,
    pub winner_name: String,
    pub method: String,
    pub detail: String,
    pub end_round: u32,
    pub end_time: String,
}

#[derive(uniffi::Record, Clone, Debug)]
pub struct FighterRecord {
    pub id: String,
    pub name: String,
    pub nickname: Option<String>,
    pub country: Option<String>,
    pub height_cm: Option<u32>,
    pub reach_in: Option<u32>,
    pub stance: Option<String>,
    pub record_display: String,
    pub portrait_path: String,
}

// MARK: - Conversions

impl From<BetModeRecord> for BetMode {
    fn from(value: BetModeRecord) -> Self {
        match value {
            BetModeRecord::Single => BetMode::Single,
            BetModeRecord::Accumulator => BetMode::Accumulator,
        }
    }
}

impl From<BetMode> for BetModeRecord {
    fn from(value: BetMode) -> Self {
        match value {
            BetMode::Single => BetModeRecord::Single,
            BetMode::Accumulator => BetModeRecord::Accumulator,
        }
    }
}

impl From<SelectionRecord> for Selection {
    fn from(value: SelectionRecord) -> Self {
        Selection {
            bout_id: value.bout_id,
            fighter_id: value.fighter_id,
            odds: money::parse(&value.odds),
        }
    }
}

impl From<Selection> for SelectionRecord {
    fn from(value: Selection) -> Self {
        SelectionRecord {
            bout_id: value.bout_id,
            fighter_id: value.fighter_id,
            odds: money::format(value.odds),
        }
    }
}

impl From<BetSlipRecord> for BetSlip {
    fn from(value: BetSlipRecord) -> Self {
        BetSlip {
            mode: value.mode.into(),
            selections: value.selections.into_iter().map(Into::into).collect(),
            stake: money::parse(&value.stake),
        }
    }
}

impl From<BetSlip> for BetSlipRecord {
    fn from(value: BetSlip) -> Self {
        BetSlipRecord {
            mode: value.mode.into(),
            selections: value.selections.into_iter().map(Into::into).collect(),
            stake: money::format(value.stake),
        }
    }
}

impl From<ValidationError> for ValidationErrorRecord {
    fn from(value: ValidationError) -> Self {
        match value {
            ValidationError::EmptySlip => Self::EmptySlip,
            ValidationError::StakeBelowMinimum => Self::StakeBelowMinimum,
            ValidationError::StakeAboveMaximum => Self::StakeAboveMaximum,
            ValidationError::InsufficientBalance => Self::InsufficientBalance,
            ValidationError::TooManySelections => Self::TooManySelections,
            ValidationError::AccumulatorNeedsTwoLegs => Self::AccumulatorNeedsTwoLegs,
            ValidationError::DuplicateBout => Self::DuplicateBout,
            ValidationError::UnknownBout => Self::UnknownBout,
            ValidationError::FighterNotInBout => Self::FighterNotInBout,
            ValidationError::PayoutExceedsLimit => Self::PayoutExceedsLimit,
        }
    }
}

impl From<SlipState> for SlipStateRecord {
    fn from(value: SlipState) -> Self {
        SlipStateRecord {
            combined_odds_exact: value
                .combined_odds_exact
                .map(money::format_exact_odds),
            combined_odds_display: value.combined_odds_display.map(money::format),
            total_stake: money::format(value.total_stake),
            potential_return: money::format(value.potential_return),
            potential_profit: money::format(value.potential_profit),
            errors: value.errors.into_iter().map(Into::into).collect(),
        }
    }
}

impl From<LegOutcome> for LegOutcomeRecord {
    fn from(value: LegOutcome) -> Self {
        match value {
            LegOutcome::Won => Self::Won,
            LegOutcome::Lost => Self::Lost,
            LegOutcome::Void => Self::Void,
        }
    }
}

impl From<SettlementStatus> for SettlementStatusRecord {
    fn from(value: SettlementStatus) -> Self {
        match value {
            SettlementStatus::Won => Self::Won,
            SettlementStatus::Lost => Self::Lost,
            SettlementStatus::Void => Self::Void,
            SettlementStatus::PartiallyWon => Self::PartiallyWon,
        }
    }
}

impl From<Settlement> for SettlementRecord {
    fn from(value: Settlement) -> Self {
        SettlementRecord {
            legs: value
                .legs
                .into_iter()
                .map(|leg| LegResultRecord {
                    bout_id: leg.bout_id,
                    fighter_id: leg.fighter_id,
                    outcome: leg.outcome.into(),
                })
                .collect(),
            returned: money::format(value.returned),
            profit: money::format(value.profit),
            status: value.status.into(),
        }
    }
}

impl From<CashOutOffer> for CashOutOfferRecord {
    fn from(value: CashOutOffer) -> Self {
        CashOutOfferRecord {
            available: value.available,
            amount: money::format(value.amount),
            reason: value.reason,
        }
    }
}

// MARK: - Ports (foreign traits — implemented in Swift/Kotlin shells)

#[uniffi::export(foreign)]
pub trait Clock: Send + Sync {
    fn now(&self) -> i64;
}

#[uniffi::export(foreign)]
pub trait PreferencesStore: Send + Sync {
    fn read(&self, key: String) -> Option<String>;
    fn write(&self, key: String, value: String);
}

#[uniffi::export(foreign)]
pub trait SlipStateListener: Send + Sync {
    fn on_slip_state_changed(&self, state: SlipStateRecord);
}

// FightRepository — async foreign trait (platform implements; Rust could consume it).
#[uniffi::export(with_foreign, async_runtime = "tokio")]
#[async_trait::async_trait]
pub trait FightRepository: Send + Sync {
    async fn load_events(&self) -> Result<Vec<EventRecord>, FightCoreError>;
    async fn load_fighters(&self) -> Result<Vec<FighterRecord>, FightCoreError>;
}

// MARK: - Pure API (no I/O)

#[uniffi::export]
pub fn decimal_to_fractional(decimal_odds: String) -> String {
    odds::decimal_to_fractional(money::parse(&decimal_odds))
}

#[uniffi::export]
pub fn fractional_to_decimal(fractional: String) -> String {
    money::format(odds::fractional_to_decimal(&fractional))
}

#[uniffi::export]
pub fn implied_probability(decimal_odds: String) -> String {
    money::format_implied_probability(odds::implied_probability(money::parse(&decimal_odds)))
}

#[uniffi::export]
pub fn format_money(amount: String) -> String {
    money::format(money::parse(&amount))
}

#[uniffi::export]
pub fn format_currency(amount: String) -> String {
    money::format_currency(money::parse(&amount))
}

#[uniffi::export]
pub fn format_exact_odds(amount: String) -> String {
    money::format_exact_odds(money::parse(&amount))
}

#[derive(uniffi::Object)]
pub struct FightCoreHandle {
    core: Arc<FightCore>,
}

#[uniffi::export]
impl FightCoreHandle {
    #[uniffi::constructor]
    pub fn new(bouts: Vec<BoutIndexRecord>) -> Arc<Self> {
        let bouts = bouts
            .into_iter()
            .map(|b| BoutIndex {
                id: b.id,
                red_fighter_id: b.red_fighter_id,
                blue_fighter_id: b.blue_fighter_id,
                winner_id: b.winner_id,
            })
            .collect();
        Arc::new(Self {
            core: Arc::new(FightCore::new(bouts)),
        })
    }

    pub fn slip_state(&self, slip: BetSlipRecord, balance: String) -> SlipStateRecord {
        self.core
            .slip_state(&slip.into(), money::parse(&balance))
            .into()
    }

    pub fn validate(&self, slip: BetSlipRecord, balance: String) -> Vec<ValidationErrorRecord> {
        self.core
            .validate(&slip.into(), money::parse(&balance))
            .into_iter()
            .map(Into::into)
            .collect()
    }

    pub fn settle(&self, slip: BetSlipRecord, voided_bouts: Vec<String>) -> SettlementRecord {
        let voided: HashSet<String> = voided_bouts.into_iter().collect();
        self.core.settle(&slip.into(), &voided).into()
    }

    pub fn cash_out_offer(
        &self,
        slip: BetSlipRecord,
        settled_bouts: Vec<String>,
    ) -> CashOutOfferRecord {
        let settled: HashSet<String> = settled_bouts.into_iter().collect();
        self.core.cash_out_offer(&slip.into(), &settled).into()
    }
}

// MARK: - Observable slip store

struct BetSlipStoreInner {
    slip: BetSlip,
    balance: Decimal,
    core: Arc<FightCore>,
    listeners: Vec<Arc<dyn SlipStateListener>>,
}

#[derive(uniffi::Object)]
pub struct BetSlipStore {
    inner: Mutex<BetSlipStoreInner>,
}

#[uniffi::export]
impl BetSlipStore {
    #[uniffi::constructor]
    pub fn new(core: Arc<FightCoreHandle>, balance: String) -> Arc<Self> {
        Arc::new(Self {
            inner: Mutex::new(BetSlipStoreInner {
                slip: BetSlip {
                    mode: BetMode::Accumulator,
                    selections: vec![],
                    stake: money::parse("10.00"),
                },
                balance: money::parse(&balance),
                core: Arc::clone(&core.core),
                listeners: vec![],
            }),
        })
    }

    pub fn add_listener(&self, listener: Arc<dyn SlipStateListener>) {
        let mut inner = self.inner.lock().unwrap();
        inner.listeners.push(listener);
        Self::notify_listeners(&mut inner);
    }

    pub fn current_state(&self) -> SlipStateRecord {
        let inner = self.inner.lock().unwrap();
        inner.core.slip_state(&inner.slip, inner.balance).into()
    }

    pub fn current_slip(&self) -> BetSlipRecord {
        let inner = self.inner.lock().unwrap();
        inner.slip.clone().into()
    }

    pub fn balance(&self) -> String {
        money::format(self.inner.lock().unwrap().balance)
    }

    pub fn set_balance(&self, balance: String) {
        let mut inner = self.inner.lock().unwrap();
        inner.balance = money::parse(&balance);
        Self::notify_listeners(&mut inner);
    }

    pub fn set_mode(&self, mode: BetModeRecord) {
        let mut inner = self.inner.lock().unwrap();
        inner.slip.mode = mode.into();
        Self::notify_listeners(&mut inner);
    }

    pub fn set_stake(&self, stake: String) {
        let mut inner = self.inner.lock().unwrap();
        inner.slip.stake = money::parse(&stake);
        Self::notify_listeners(&mut inner);
    }

    pub fn toggle_selection(&self, bout_id: String, fighter_id: String, odds: String) {
        let mut inner = self.inner.lock().unwrap();
        let parsed_odds = money::parse(&odds);
        if let Some(index) = inner
            .slip
            .selections
            .iter()
            .position(|s| s.bout_id == bout_id)
        {
            let existing = &inner.slip.selections[index];
            if existing.fighter_id == fighter_id {
                inner.slip.selections.remove(index);
            } else {
                inner.slip.selections[index] = Selection {
                    bout_id,
                    fighter_id,
                    odds: parsed_odds,
                };
            }
        } else {
            inner.slip.selections.push(Selection {
                bout_id,
                fighter_id,
                odds: parsed_odds,
            });
        }
        Self::notify_listeners(&mut inner);
    }

    pub fn remove_selection(&self, bout_id: String, fighter_id: String) {
        let mut inner = self.inner.lock().unwrap();
        inner.slip.selections.retain(|s| {
            !(s.bout_id == bout_id && s.fighter_id == fighter_id)
        });
        Self::notify_listeners(&mut inner);
    }

    pub fn is_selected(&self, bout_id: String, fighter_id: String) -> bool {
        let inner = self.inner.lock().unwrap();
        inner.slip.selections.iter().any(|s| {
            s.bout_id == bout_id && s.fighter_id == fighter_id
        })
    }

    pub fn deposit(&self, amount: String) {
        let mut inner = self.inner.lock().unwrap();
        inner.balance += money::parse(&amount);
        Self::notify_listeners(&mut inner);
    }
}

impl BetSlipStore {
    fn notify_listeners(inner: &mut BetSlipStoreInner) {
        let state: SlipStateRecord = inner.core.slip_state(&inner.slip, inner.balance).into();
        for listener in &inner.listeners {
            listener.on_slip_state_changed(state.clone());
        }
    }
}
