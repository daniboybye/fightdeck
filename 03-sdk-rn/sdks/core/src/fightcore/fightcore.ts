import Decimal from 'decimal.js';
import { money, parseMoney } from './money';
import {
  BetSlip,
  BoutIndex,
  CashOutOffer,
  LegOutcome,
  LegResult,
  Selection,
  Settlement,
  SettlementStatus,
  SlipState,
  VALIDATION_ORDER,
  ValidationErrorCode,
} from './types';

export const MIN_STAKE = parseMoney('1.00');
export const MAX_STAKE = parseMoney('5000.00');
export const MAX_SELECTIONS = 12;
export const MIN_ACCA_LEGS = 2;
export const MAX_PAYOUT = parseMoney('100000.00');
export const CASH_OUT_MARGIN = parseMoney('0.05');

export class FightCore {
  readonly bouts: Map<string, BoutIndex>;

  constructor(bouts: BoutIndex[]) {
    this.bouts = new Map(bouts.map((b) => [b.id, b]));
  }

  combinedOddsExact(selections: Selection[]): Decimal {
    return selections.reduce(
      (acc, sel) => acc.times(sel.odds),
      new Decimal(1),
    );
  }

  slipState(slip: BetSlip, balance: Decimal): SlipState {
    const errors = this.validate(slip, balance);
    const math = this.computeMath(slip.mode, slip.selections, slip.stake);
    return {
      combinedOddsExact: math.combinedExact,
      combinedOddsDisplay: math.combinedDisplay,
      totalStake: math.totalStake,
      potentialReturn: math.potentialReturn,
      potentialProfit: math.potentialProfit,
      errors,
    };
  }

  validate(slip: BetSlip, balance: Decimal): ValidationErrorCode[] {
    const found = new Set<ValidationErrorCode>();

    if (slip.selections.length === 0) {
      found.add('empty_slip');
    }
    if (slip.stake.lessThan(MIN_STAKE)) {
      found.add('stake_below_minimum');
    }
    if (slip.stake.greaterThan(MAX_STAKE)) {
      found.add('stake_above_maximum');
    }
    if (slip.selections.length > MAX_SELECTIONS) {
      found.add('too_many_selections');
    }
    if (
      slip.mode === 'accumulator'
      && slip.selections.length > 0
      && slip.selections.length < MIN_ACCA_LEGS
    ) {
      found.add('accumulator_needs_two_legs');
    }

    const boutIds = slip.selections.map((s) => s.boutId);
    if (new Set(boutIds).size !== boutIds.length) {
      found.add('duplicate_bout');
    }

    let hasUnknownBout = false;
    for (const selection of slip.selections) {
      const bout = this.bouts.get(selection.boutId);
      if (!bout) {
        found.add('unknown_bout');
        hasUnknownBout = true;
        continue;
      }
      const corners = new Set([bout.redFighterId, bout.blueFighterId]);
      if (!corners.has(selection.fighterId)) {
        found.add('fighter_not_in_bout');
      }
    }

    if (slip.selections.length > 0 && !hasUnknownBout) {
      const math = this.computeMath(slip.mode, slip.selections, slip.stake);
      if (math.totalStake.greaterThan(balance)) {
        found.add('insufficient_balance');
      }
      if (math.potentialReturn.greaterThan(MAX_PAYOUT)) {
        found.add('payout_exceeds_limit');
      }
    } else if (slip.stake.greaterThan(balance)) {
      found.add('insufficient_balance');
    }

    return VALIDATION_ORDER.filter((code) => found.has(code));
  }

  settle(slip: BetSlip, voidedBouts: Set<string> = new Set()): Settlement {
    const outcomes = slip.selections.map((s) => this.legOutcome(s, voidedBouts));

    if (slip.mode === 'accumulator') {
      const totalStake = slip.stake;
      if (outcomes.includes('lost')) {
        return this.makeSettlement(slip, outcomes, new Decimal(0), totalStake, 'lost');
      }
      const product = slip.selections.reduce((acc, selection, index) => {
        const outcome = outcomes[index];
        const factor = outcome === 'void' ? new Decimal(1) : selection.odds;
        return acc.times(factor);
      }, new Decimal(1));
      return this.makeSettlement(
        slip,
        outcomes,
        money(slip.stake.times(product)),
        totalStake,
        'won',
      );
    }

    const totalStake = slip.stake.times(slip.selections.length);
    let returned = new Decimal(0);
    slip.selections.forEach((selection, index) => {
      switch (outcomes[index]) {
        case 'won':
          returned = returned.plus(money(slip.stake.times(selection.odds)));
          break;
        case 'void':
          returned = returned.plus(slip.stake);
          break;
        default:
          break;
      }
    });

    const wonCount = outcomes.filter((o) => o === 'won').length;
    let status: SettlementStatus;
    if (wonCount === outcomes.length) {
      status = 'won';
    } else if (wonCount === 0) {
      status = 'lost';
    } else {
      status = 'partially_won';
    }

    return this.makeSettlement(slip, outcomes, returned, totalStake, status);
  }

  cashOutOffer(slip: BetSlip, settledBouts: Set<string>): CashOutOffer {
    if (slip.mode !== 'accumulator') {
      return { available: false, amount: new Decimal(0), reason: 'not_an_accumulator' };
    }

    const outcomes = new Map<string, LegOutcome>();
    for (const selection of slip.selections) {
      if (settledBouts.has(selection.boutId)) {
        outcomes.set(selection.boutId, this.legOutcome(selection, new Set()));
      }
    }

    if ([...outcomes.values()].includes('lost')) {
      return { available: false, amount: new Decimal(0), reason: 'bet_already_lost' };
    }

    const allBoutIds = new Set(slip.selections.map((s) => s.boutId));
    const settledIntersection = [...settledBouts].filter((id) => allBoutIds.has(id));
    if (settledIntersection.length === allBoutIds.size) {
      return { available: false, amount: new Decimal(0), reason: 'bet_already_settled' };
    }

    let fairValue = slip.stake;
    for (const selection of slip.selections) {
      if (outcomes.get(selection.boutId) === 'won') {
        fairValue = fairValue.times(selection.odds);
      }
    }

    const amount = money(fairValue.times(new Decimal(1).minus(CASH_OUT_MARGIN)));
    return { available: true, amount, reason: null };
  }

  private computeMath(
    mode: BetSlip['mode'],
    selections: Selection[],
    stake: Decimal,
  ) {
    if (mode === 'accumulator') {
      const exact = this.combinedOddsExact(selections);
      const totalStake = stake;
      const potentialReturn = money(stake.times(exact));
      return {
        combinedExact: exact,
        combinedDisplay: money(exact),
        totalStake: money(totalStake),
        potentialReturn,
        potentialProfit: money(potentialReturn.minus(totalStake)),
      };
    }

    const totalStake = stake.times(selections.length);
    const potentialReturn = selections.reduce(
      (acc, selection) => acc.plus(money(stake.times(selection.odds))),
      new Decimal(0),
    );
    return {
      combinedExact: null,
      combinedDisplay: null,
      totalStake: money(totalStake),
      potentialReturn: money(potentialReturn),
      potentialProfit: money(potentialReturn.minus(totalStake)),
    };
  }

  private legOutcome(selection: Selection, voidedBouts: Set<string>): LegOutcome {
    if (voidedBouts.has(selection.boutId)) {
      return 'void';
    }
    const bout = this.bouts.get(selection.boutId);
    if (!bout) {
      return 'lost';
    }
    return bout.winnerId === selection.fighterId ? 'won' : 'lost';
  }

  private makeSettlement(
    slip: BetSlip,
    outcomes: LegOutcome[],
    returned: Decimal,
    totalStake: Decimal,
    status: SettlementStatus,
  ): Settlement {
    const legs: LegResult[] = slip.selections.map((selection, index) => ({
      boutId: selection.boutId,
      fighterId: selection.fighterId,
      outcome: outcomes[index],
    }));
    const roundedReturn = money(returned);
    return {
      legs,
      returned: roundedReturn,
      profit: money(roundedReturn.minus(totalStake)),
      status,
    };
  }
}

export function boutIndexFromDataset(events: Array<{ bouts: Array<{
  id: string;
  redCorner: { fighterId: string };
  blueCorner: { fighterId: string };
  result: { winnerId: string };
}> }>): BoutIndex[] {
  return events.flatMap((event) =>
    event.bouts.map((bout) => ({
      id: bout.id,
      redFighterId: bout.redCorner.fighterId,
      blueFighterId: bout.blueCorner.fighterId,
      winnerId: bout.result.winnerId,
    })),
  );
}
