import Decimal from 'decimal.js';

export type BetMode = 'single' | 'accumulator';

export interface Selection {
  boutId: string;
  fighterId: string;
  odds: Decimal;
}

export interface BetSlip {
  mode: BetMode;
  selections: Selection[];
  stake: Decimal;
}

export type ValidationErrorCode =
  | 'empty_slip'
  | 'stake_below_minimum'
  | 'stake_above_maximum'
  | 'insufficient_balance'
  | 'too_many_selections'
  | 'accumulator_needs_two_legs'
  | 'duplicate_bout'
  | 'unknown_bout'
  | 'fighter_not_in_bout'
  | 'payout_exceeds_limit';

export const VALIDATION_ORDER: ValidationErrorCode[] = [
  'empty_slip',
  'stake_below_minimum',
  'stake_above_maximum',
  'insufficient_balance',
  'too_many_selections',
  'accumulator_needs_two_legs',
  'duplicate_bout',
  'unknown_bout',
  'fighter_not_in_bout',
  'payout_exceeds_limit',
];

export interface SlipState {
  combinedOddsExact: Decimal | null;
  combinedOddsDisplay: Decimal | null;
  totalStake: Decimal;
  potentialReturn: Decimal;
  potentialProfit: Decimal;
  errors: ValidationErrorCode[];
}

export type LegOutcome = 'won' | 'lost' | 'void';

export interface LegResult {
  boutId: string;
  fighterId: string;
  outcome: LegOutcome;
}

export type SettlementStatus = 'won' | 'lost' | 'void' | 'partially_won';

export interface Settlement {
  legs: LegResult[];
  returned: Decimal;
  profit: Decimal;
  status: SettlementStatus;
}

export interface CashOutOffer {
  available: boolean;
  amount: Decimal;
  reason: string | null;
}

export interface BoutIndex {
  id: string;
  redFighterId: string;
  blueFighterId: string;
  winnerId: string;
}
