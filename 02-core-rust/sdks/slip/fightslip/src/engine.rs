//! Pure slip logic: combined odds, validation, settlement, cash-out.
//!
//! Every number here is checked against `contract/fixtures/`.

use fightcore::money;
use fightcore::types::{
    BetMode, BetSlip, BoutIndex, CashOutOffer, LegOutcome, LegResult, Selection, Settlement,
    SettlementStatus, SlipState, ValidationError, CASH_OUT_MARGIN, MAX_PAYOUT, MAX_SELECTIONS,
    MAX_STAKE, MIN_ACCA_LEGS, MIN_STAKE,
};
use rust_decimal::Decimal;
use std::collections::{HashMap, HashSet};

struct SlipMath {
    combined_exact: Option<Decimal>,
    combined_display: Option<Decimal>,
    total_stake: Decimal,
    potential_return: Decimal,
    potential_profit: Decimal,
}

pub struct SlipEngine {
    bouts: HashMap<String, BoutIndex>,
    min_stake: Decimal,
    max_stake: Decimal,
    max_payout: Decimal,
    cash_out_margin: Decimal,
}

impl SlipEngine {
    pub fn new(bouts: Vec<BoutIndex>) -> Self {
        Self {
            bouts: bouts.into_iter().map(|b| (b.id.clone(), b)).collect(),
            min_stake: money::parse_exact(MIN_STAKE),
            max_stake: money::parse_exact(MAX_STAKE),
            max_payout: money::parse_exact(MAX_PAYOUT),
            cash_out_margin: money::parse_exact(CASH_OUT_MARGIN),
        }
    }

    pub fn combined_odds_exact(&self, selections: &[Selection]) -> Decimal {
        selections.iter().fold(Decimal::ONE, |acc, sel| acc * sel.odds)
    }

    pub fn slip_state(&self, slip: &BetSlip, balance: Decimal) -> SlipState {
        let errors = self.validate(slip, balance);
        let math = self.compute_math(slip.mode, &slip.selections, slip.stake);
        SlipState {
            combined_odds_exact: math.combined_exact,
            combined_odds_display: math.combined_display,
            total_stake: math.total_stake,
            potential_return: math.potential_return,
            potential_profit: math.potential_profit,
            errors,
        }
    }

    /// The slip mode is derived, never picked: one leg is a single, two or more an accumulator.
    /// Both hosts used to carry a copy of this rule.
    pub fn mode_for(selection_count: usize) -> BetMode {
        if selection_count >= MIN_ACCA_LEGS {
            BetMode::Accumulator
        } else {
            BetMode::Single
        }
    }

    pub fn validate(&self, slip: &BetSlip, balance: Decimal) -> Vec<ValidationError> {
        let mut found = HashSet::new();

        if slip.selections.is_empty() {
            found.insert(ValidationError::EmptySlip);
        }
        if money::try_parse(&slip.stake_raw).is_err() {
            found.insert(ValidationError::InvalidStake);
        }
        if slip.stake < self.min_stake {
            found.insert(ValidationError::StakeBelowMinimum);
        }
        if slip.stake > self.max_stake {
            found.insert(ValidationError::StakeAboveMaximum);
        }
        if slip.selections.len() > MAX_SELECTIONS {
            found.insert(ValidationError::TooManySelections);
        }
        if slip.mode == BetMode::Accumulator
            && !slip.selections.is_empty()
            && slip.selections.len() < MIN_ACCA_LEGS
        {
            found.insert(ValidationError::AccumulatorNeedsTwoLegs);
        }

        let bout_ids: Vec<_> = slip.selections.iter().map(|s| s.bout_id.as_str()).collect();
        if bout_ids.len() != bout_ids.iter().collect::<HashSet<_>>().len() {
            found.insert(ValidationError::DuplicateBout);
        }

        let mut has_unknown_bout = false;
        for selection in &slip.selections {
            let Some(bout) = self.bouts.get(&selection.bout_id) else {
                found.insert(ValidationError::UnknownBout);
                has_unknown_bout = true;
                continue;
            };
            let corners = HashSet::from([&bout.red_fighter_id, &bout.blue_fighter_id]);
            if !corners.contains(&selection.fighter_id) {
                found.insert(ValidationError::FighterNotInBout);
            }
        }

        if !slip.selections.is_empty() && !has_unknown_bout {
            let math = self.compute_math(slip.mode, &slip.selections, slip.stake);
            if math.total_stake > balance {
                found.insert(ValidationError::InsufficientBalance);
            }
            if math.potential_return > self.max_payout {
                found.insert(ValidationError::PayoutExceedsLimit);
            }
        } else if slip.stake > balance {
            found.insert(ValidationError::InsufficientBalance);
        }

        ValidationError::ORDER
            .iter()
            .copied()
            .filter(|e| found.contains(e))
            .collect()
    }

    pub fn settle(&self, slip: &BetSlip, voided_bouts: &HashSet<String>) -> Settlement {
        let outcomes: Vec<LegOutcome> = slip
            .selections
            .iter()
            .map(|s| self.leg_outcome(s, voided_bouts))
            .collect();

        match slip.mode {
            BetMode::Accumulator => {
                let total_stake = slip.stake;
                if outcomes.contains(&LegOutcome::Lost) {
                    return self.make_settlement(
                        slip,
                        &outcomes,
                        Decimal::ZERO,
                        total_stake,
                        SettlementStatus::Lost,
                    );
                }
                let product = slip
                    .selections
                    .iter()
                    .zip(outcomes.iter())
                    .fold(Decimal::ONE, |acc, (sel, outcome)| {
                        let factor = if *outcome == LegOutcome::Void {
                            Decimal::ONE
                        } else {
                            sel.odds
                        };
                        acc * factor
                    });
                self.make_settlement(
                    slip,
                    &outcomes,
                    money::money(slip.stake * product),
                    total_stake,
                    SettlementStatus::Won,
                )
            }
            BetMode::Single => {
                let total_stake = slip.stake * Decimal::from(slip.selections.len());
                let mut returned = Decimal::ZERO;
                for (selection, outcome) in slip.selections.iter().zip(outcomes.iter()) {
                    match outcome {
                        LegOutcome::Won => returned += money::money(slip.stake * selection.odds),
                        LegOutcome::Void => returned += slip.stake,
                        LegOutcome::Lost => {}
                    }
                }
                let won_count = outcomes.iter().filter(|&&o| o == LegOutcome::Won).count();
                let status = if won_count == outcomes.len() {
                    SettlementStatus::Won
                } else if won_count == 0 {
                    SettlementStatus::Lost
                } else {
                    SettlementStatus::PartiallyWon
                };
                self.make_settlement(slip, &outcomes, returned, total_stake, status)
            }
        }
    }

    pub fn cash_out_offer(&self, slip: &BetSlip, settled_bouts: &HashSet<String>) -> CashOutOffer {
        if slip.mode != BetMode::Accumulator {
            return CashOutOffer {
                available: false,
                amount: Decimal::ZERO,
                reason: Some("not_an_accumulator".to_string()),
            };
        }

        let mut outcomes: HashMap<&str, LegOutcome> = HashMap::new();
        for selection in &slip.selections {
            if settled_bouts.contains(&selection.bout_id) {
                outcomes.insert(
                    selection.bout_id.as_str(),
                    self.leg_outcome(selection, &HashSet::new()),
                );
            }
        }

        if outcomes.values().any(|&o| o == LegOutcome::Lost) {
            return CashOutOffer {
                available: false,
                amount: Decimal::ZERO,
                reason: Some("bet_already_lost".to_string()),
            };
        }

        let all_bout_ids: HashSet<_> = slip.selections.iter().map(|s| s.bout_id.clone()).collect();
        if all_bout_ids.is_subset(settled_bouts) {
            return CashOutOffer {
                available: false,
                amount: Decimal::ZERO,
                reason: Some("bet_already_settled".to_string()),
            };
        }

        let mut fair_value = slip.stake;
        for selection in &slip.selections {
            if outcomes.get(selection.bout_id.as_str()) == Some(&LegOutcome::Won) {
                fair_value *= selection.odds;
            }
        }

        let amount = money::money(fair_value * (Decimal::ONE - self.cash_out_margin));
        CashOutOffer { available: true, amount, reason: None }
    }

    fn compute_math(&self, mode: BetMode, selections: &[Selection], stake: Decimal) -> SlipMath {
        match mode {
            BetMode::Accumulator => {
                let exact = self.combined_odds_exact(selections);
                let total_stake = stake;
                let potential_return = money::money(stake * exact);
                SlipMath {
                    combined_exact: Some(exact),
                    combined_display: Some(money::money(exact)),
                    total_stake: money::money(total_stake),
                    potential_return,
                    potential_profit: money::money(potential_return - total_stake),
                }
            }
            BetMode::Single => {
                let total_stake = stake * Decimal::from(selections.len());
                let potential_return = selections
                    .iter()
                    .fold(Decimal::ZERO, |acc, sel| acc + money::money(stake * sel.odds));
                SlipMath {
                    combined_exact: None,
                    combined_display: None,
                    total_stake: money::money(total_stake),
                    potential_return: money::money(potential_return),
                    potential_profit: money::money(potential_return - total_stake),
                }
            }
        }
    }

    fn leg_outcome(&self, selection: &Selection, voided_bouts: &HashSet<String>) -> LegOutcome {
        if voided_bouts.contains(&selection.bout_id) {
            return LegOutcome::Void;
        }
        let Some(bout) = self.bouts.get(&selection.bout_id) else {
            return LegOutcome::Lost;
        };
        if bout.winner_id == selection.fighter_id {
            LegOutcome::Won
        } else {
            LegOutcome::Lost
        }
    }

    fn make_settlement(
        &self,
        slip: &BetSlip,
        outcomes: &[LegOutcome],
        returned: Decimal,
        total_stake: Decimal,
        status: SettlementStatus,
    ) -> Settlement {
        let legs = slip
            .selections
            .iter()
            .zip(outcomes.iter())
            .map(|(sel, outcome)| LegResult {
                bout_id: sel.bout_id.clone(),
                fighter_id: sel.fighter_id.clone(),
                outcome: *outcome,
            })
            .collect();
        let rounded_return = money::money(returned);
        Settlement {
            legs,
            returned: rounded_return,
            profit: money::money(rounded_return - total_stake),
            status,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn invalid_stake_raw_flags_validation_not_zero_stake() {
        let slip = BetSlip {
            mode: BetMode::Single,
            selections: vec![Selection {
                bout_id: "bout-1".into(),
                fighter_id: "fighter-1".into(),
                odds: money::parse_exact("2.00"),
            }],
            stake: money::parse_exact("10.00"),
            stake_raw: "10..00".into(),
        };
        let engine = SlipEngine::new(vec![]);
        let errors = engine.validate(&slip, money::parse_exact("500.00"));
        assert!(errors.contains(&ValidationError::InvalidStake));
        assert!(!errors.contains(&ValidationError::StakeBelowMinimum));
    }

    #[test]
    fn mode_follows_leg_count() {
        assert_eq!(SlipEngine::mode_for(0), BetMode::Single);
        assert_eq!(SlipEngine::mode_for(1), BetMode::Single);
        assert_eq!(SlipEngine::mode_for(2), BetMode::Accumulator);
    }
}
