//! The `fightslip` UniFFI namespace: records, conversions and the stateless handle.

use crate::engine::SlipEngine;
use fightcore::money;
use fightcore::types::{
    BetMode, BetSlip, BoutIndex, CashOutOffer, LegOutcome, Selection, Settlement,
    SettlementStatus, SlipState, ValidationError,
};
use rust_decimal::Decimal;
use std::collections::HashSet;
use std::sync::Arc;

#[derive(Debug, thiserror::Error, uniffi::Error)]
pub enum SlipError {
    #[error("decoding")]
    Decoding { field: String },
    #[error("validation")]
    Validation { codes: Vec<String> },
}

impl SlipError {
    pub(crate) fn decoding(field: &str) -> Self {
        Self::Decoding { field: field.to_string() }
    }
}

pub(crate) fn parse_amount(field: &str, value: &str) -> Result<Decimal, SlipError> {
    money::try_parse(value).map_err(|_| SlipError::decoding(field))
}

// MARK: - Records

#[derive(uniffi::Record, Clone, Debug)]
pub struct SelectionRecord {
    pub bout_id: String,
    pub fighter_id: String,
    pub odds: String,
}

#[derive(uniffi::Enum, Clone, Copy, Debug, PartialEq, Eq)]
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

#[derive(uniffi::Enum, Clone, Copy, Debug, PartialEq, Eq)]
pub enum ValidationErrorRecord {
    EmptySlip,
    InvalidStake,
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
    pub mode: BetModeRecord,
    pub selection_count: u32,
    pub combined_odds_exact: Option<String>,
    pub combined_odds_display: Option<String>,
    pub total_stake: String,
    pub potential_return: String,
    pub potential_profit: String,
    pub errors: Vec<ValidationErrorRecord>,
    /// Ready-made summary rows, so both hosts render the same labels in the same order.
    pub summary_rows: Vec<SummaryRow>,
}

#[derive(uniffi::Record, Clone, Debug)]
pub struct SummaryRow {
    pub label: String,
    pub value: String,
}

#[derive(uniffi::Enum, Clone, Copy, Debug, PartialEq, Eq)]
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

#[derive(uniffi::Enum, Clone, Copy, Debug, PartialEq, Eq)]
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
    pub status_headline: String,
}

#[derive(uniffi::Record, Clone, Debug)]
pub struct CashOutOfferRecord {
    pub available: bool,
    pub amount: String,
    pub reason: Option<String>,
    pub headline: String,
}

#[derive(uniffi::Record, Clone, Debug)]
pub struct BoutIndexRecord {
    pub id: String,
    pub red_fighter_id: String,
    pub blue_fighter_id: String,
    pub winner_id: String,
}

/// What `place_bet` did, so neither host has to work out the balance or the message.
#[derive(uniffi::Record, Clone, Debug)]
pub struct PlaceBetOutcome {
    pub placed: bool,
    pub stake_taken: String,
    pub new_balance: String,
    pub potential_return: String,
    pub message: Option<String>,
    pub errors: Vec<ValidationErrorRecord>,
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
            odds: money::try_parse(&value.odds).unwrap_or(Decimal::ZERO),
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
            stake_raw: value.stake.clone(),
            stake: money::try_parse(&value.stake).unwrap_or(Decimal::ZERO),
        }
    }
}

impl From<BetSlip> for BetSlipRecord {
    fn from(value: BetSlip) -> Self {
        BetSlipRecord {
            mode: value.mode.into(),
            selections: value.selections.into_iter().map(Into::into).collect(),
            stake: value.stake_raw,
        }
    }
}

impl From<ValidationError> for ValidationErrorRecord {
    fn from(value: ValidationError) -> Self {
        match value {
            ValidationError::EmptySlip => Self::EmptySlip,
            ValidationError::InvalidStake => Self::InvalidStake,
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

impl From<ValidationErrorRecord> for ValidationError {
    fn from(value: ValidationErrorRecord) -> Self {
        match value {
            ValidationErrorRecord::EmptySlip => Self::EmptySlip,
            ValidationErrorRecord::InvalidStake => Self::InvalidStake,
            ValidationErrorRecord::StakeBelowMinimum => Self::StakeBelowMinimum,
            ValidationErrorRecord::StakeAboveMaximum => Self::StakeAboveMaximum,
            ValidationErrorRecord::InsufficientBalance => Self::InsufficientBalance,
            ValidationErrorRecord::TooManySelections => Self::TooManySelections,
            ValidationErrorRecord::AccumulatorNeedsTwoLegs => Self::AccumulatorNeedsTwoLegs,
            ValidationErrorRecord::DuplicateBout => Self::DuplicateBout,
            ValidationErrorRecord::UnknownBout => Self::UnknownBout,
            ValidationErrorRecord::FighterNotInBout => Self::FighterNotInBout,
            ValidationErrorRecord::PayoutExceedsLimit => Self::PayoutExceedsLimit,
        }
    }
}

impl SlipStateRecord {
    /// The only way to build one. `mode` and `selection_count` are read off the slip the state
    /// was computed from, so a record cannot be handed out disagreeing with it.
    pub(crate) fn new(state: SlipState, slip: &BetSlip) -> Self {
        let mut summary_rows = vec![SummaryRow {
            label: "Total stake".into(),
            value: money::format_currency(state.total_stake),
        }];
        if let Some(display) = state.combined_odds_display {
            summary_rows.push(SummaryRow {
                label: "Combined odds".into(),
                value: money::format(display),
            });
        }
        summary_rows.push(SummaryRow {
            label: "Potential return".into(),
            value: money::format_currency(state.potential_return),
        });
        summary_rows.push(SummaryRow {
            label: "Potential profit".into(),
            value: money::format_currency(state.potential_profit),
        });

        SlipStateRecord {
            mode: slip.mode.into(),
            selection_count: slip.selections.len() as u32,
            combined_odds_exact: state.combined_odds_exact.map(money::format_exact_odds),
            combined_odds_display: state.combined_odds_display.map(money::format),
            total_stake: money::format(state.total_stake),
            potential_return: money::format(state.potential_return),
            potential_profit: money::format(state.potential_profit),
            errors: state.errors.into_iter().map(Into::into).collect(),
            summary_rows,
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
        let headline = match value.status {
            SettlementStatus::Won => format!("Won {}", money::format_currency(value.returned)),
            SettlementStatus::Lost => "Lost".to_string(),
            SettlementStatus::Void => {
                format!("Void — {} returned", money::format_currency(value.returned))
            }
            SettlementStatus::PartiallyWon => {
                format!("Partially won {}", money::format_currency(value.returned))
            }
        };
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
            status_headline: headline,
        }
    }
}

impl From<CashOutOffer> for CashOutOfferRecord {
    fn from(value: CashOutOffer) -> Self {
        let headline = if value.available {
            format!("Cash out for {}", money::format_currency(value.amount))
        } else {
            match value.reason.as_deref() {
                Some("not_an_accumulator") => "Cash out is accumulators only".to_string(),
                Some("bet_already_lost") => "This bet has already lost".to_string(),
                Some("bet_already_settled") => "Every leg has settled".to_string(),
                _ => "Cash out unavailable".to_string(),
            }
        };
        CashOutOfferRecord {
            available: value.available,
            amount: money::format(value.amount),
            reason: value.reason,
            headline,
        }
    }
}

impl From<BoutIndexRecord> for BoutIndex {
    fn from(value: BoutIndexRecord) -> Self {
        BoutIndex {
            id: value.id,
            red_fighter_id: value.red_fighter_id,
            blue_fighter_id: value.blue_fighter_id,
            winner_id: value.winner_id,
        }
    }
}

// MARK: - Stateless handle

#[derive(uniffi::Object)]
pub struct SlipHandle {
    pub(crate) engine: Arc<SlipEngine>,
}

#[uniffi::export]
impl SlipHandle {
    #[uniffi::constructor]
    pub fn new(bouts: Vec<BoutIndexRecord>) -> Arc<Self> {
        let bouts = bouts.into_iter().map(Into::into).collect();
        Arc::new(Self { engine: Arc::new(SlipEngine::new(bouts)) })
    }

    pub fn slip_state(
        &self,
        slip: BetSlipRecord,
        balance: String,
    ) -> Result<SlipStateRecord, SlipError> {
        let balance = parse_amount("balance", &balance)?;
        let slip: BetSlip = slip.into();
        Ok(SlipStateRecord::new(self.engine.slip_state(&slip, balance), &slip))
    }

    pub fn validate(
        &self,
        slip: BetSlipRecord,
        balance: String,
    ) -> Result<Vec<ValidationErrorRecord>, SlipError> {
        let balance = parse_amount("balance", &balance)?;
        Ok(self
            .engine
            .validate(&slip.into(), balance)
            .into_iter()
            .map(Into::into)
            .collect())
    }

    pub fn settle(&self, slip: BetSlipRecord, voided_bouts: Vec<String>) -> SettlementRecord {
        let voided: HashSet<String> = voided_bouts.into_iter().collect();
        self.engine.settle(&slip.into(), &voided).into()
    }

    pub fn cash_out_offer(
        &self,
        slip: BetSlipRecord,
        settled_bouts: Vec<String>,
    ) -> CashOutOfferRecord {
        let settled: HashSet<String> = settled_bouts.into_iter().collect();
        self.engine.cash_out_offer(&slip.into(), &settled).into()
    }
}

#[uniffi::export]
pub fn validation_error_code(error: ValidationErrorRecord) -> String {
    ValidationError::from(error).code().to_string()
}

/// The label the slip screen puts above the legs.
#[uniffi::export]
pub fn bet_type_title(mode: BetModeRecord) -> String {
    match mode {
        BetModeRecord::Single => "Single".to_string(),
        BetModeRecord::Accumulator => "Accumulator".to_string(),
    }
}
