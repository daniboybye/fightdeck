//! The contract vocabulary. Every feature SDK speaks these types; none of them redefine one.

use rust_decimal::Decimal;

pub const MIN_STAKE: &str = "1.00";
pub const MAX_STAKE: &str = "5000.00";
pub const MAX_SELECTIONS: usize = 12;
pub const MIN_ACCA_LEGS: usize = 2;
pub const MAX_PAYOUT: &str = "100000.00";
pub const CASH_OUT_MARGIN: &str = "0.05";

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum BetMode {
    Single,
    Accumulator,
}

impl BetMode {
    pub fn parse(s: &str) -> Self {
        match s {
            "accumulator" => Self::Accumulator,
            _ => Self::Single,
        }
    }

    pub fn code(&self) -> &'static str {
        match self {
            Self::Single => "single",
            Self::Accumulator => "accumulator",
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Selection {
    pub bout_id: String,
    pub fighter_id: String,
    pub odds: Decimal,
}

#[derive(Debug, Clone)]
pub struct BetSlip {
    pub mode: BetMode,
    pub selections: Vec<Selection>,
    pub stake: Decimal,
    /// Raw stake text from the host; [stake] mirrors it when parsing succeeds.
    pub stake_raw: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum ValidationError {
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

impl ValidationError {
    pub const ORDER: [ValidationError; 11] = [
        Self::EmptySlip,
        Self::InvalidStake,
        Self::StakeBelowMinimum,
        Self::StakeAboveMaximum,
        Self::InsufficientBalance,
        Self::TooManySelections,
        Self::AccumulatorNeedsTwoLegs,
        Self::DuplicateBout,
        Self::UnknownBout,
        Self::FighterNotInBout,
        Self::PayoutExceedsLimit,
    ];

    pub fn code(&self) -> &'static str {
        match self {
            Self::EmptySlip => "empty_slip",
            Self::InvalidStake => "invalid_stake",
            Self::StakeBelowMinimum => "stake_below_minimum",
            Self::StakeAboveMaximum => "stake_above_maximum",
            Self::InsufficientBalance => "insufficient_balance",
            Self::TooManySelections => "too_many_selections",
            Self::AccumulatorNeedsTwoLegs => "accumulator_needs_two_legs",
            Self::DuplicateBout => "duplicate_bout",
            Self::UnknownBout => "unknown_bout",
            Self::FighterNotInBout => "fighter_not_in_bout",
            Self::PayoutExceedsLimit => "payout_exceeds_limit",
        }
    }

    /// What the slip screen prints under the summary: the code, humanised.
    pub fn message(&self) -> String {
        crate::display::humanise(self.code())
    }
}

#[derive(Debug, Clone)]
pub struct SlipState {
    pub combined_odds_exact: Option<Decimal>,
    pub combined_odds_display: Option<Decimal>,
    pub total_stake: Decimal,
    pub potential_return: Decimal,
    pub potential_profit: Decimal,
    pub errors: Vec<ValidationError>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LegOutcome {
    Won,
    Lost,
    Void,
}

impl LegOutcome {
    pub fn code(&self) -> &'static str {
        match self {
            Self::Won => "won",
            Self::Lost => "lost",
            Self::Void => "void",
        }
    }
}

#[derive(Debug, Clone)]
pub struct LegResult {
    pub bout_id: String,
    pub fighter_id: String,
    pub outcome: LegOutcome,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SettlementStatus {
    Won,
    Lost,
    Void,
    PartiallyWon,
}

impl SettlementStatus {
    pub fn code(&self) -> &'static str {
        match self {
            Self::Won => "won",
            Self::Lost => "lost",
            Self::Void => "void",
            Self::PartiallyWon => "partially_won",
        }
    }
}

#[derive(Debug, Clone)]
pub struct Settlement {
    pub legs: Vec<LegResult>,
    pub returned: Decimal,
    pub profit: Decimal,
    pub status: SettlementStatus,
}

#[derive(Debug, Clone)]
pub struct CashOutOffer {
    pub available: bool,
    pub amount: Decimal,
    pub reason: Option<String>,
}

#[derive(Debug, Clone)]
pub struct BoutIndex {
    pub id: String,
    pub red_fighter_id: String,
    pub blue_fighter_id: String,
    pub winner_id: String,
}
