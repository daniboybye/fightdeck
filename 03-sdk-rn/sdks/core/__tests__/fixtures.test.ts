import * as fs from 'fs';
import * as path from 'path';
import Decimal from 'decimal.js';
import {
  boutIndexFromDataset,
  FightCore,
  formatExactOdds,
  formatImpliedProbability,
  formatMoney,
  fractionalToDecimal,
  decimalToFractional,
  parseMoney,
  parseOdds,
  BetSlip,
  Selection,
} from '../src/fightcore';

const REPO_ROOT = path.resolve(__dirname, '../../../..');
const FIXTURES = path.join(REPO_ROOT, 'contract/fixtures');
const DATASET = path.join(REPO_ROOT, 'dataset/events.json');

function loadJSON<T>(name: string): T {
  return JSON.parse(fs.readFileSync(path.join(FIXTURES, `${name}.json`), 'utf8')) as T;
}

function fixtureCore(): FightCore {
  const events = JSON.parse(fs.readFileSync(DATASET, 'utf8')) as {
    events: Parameters<typeof boutIndexFromDataset>[0];
  };
  return new FightCore(boutIndexFromDataset(events.events));
}

function slipFromCase(testCase: {
  mode: 'single' | 'accumulator';
  stake: string;
  selections: Array<{ boutId: string; fighterId: string; odds: string }>;
}): BetSlip {
  const selections: Selection[] = testCase.selections.map((s) => ({
    boutId: s.boutId,
    fighterId: s.fighterId,
    odds: parseOdds(s.odds),
  }));
  return { mode: testCase.mode, selections, stake: parseMoney(testCase.stake) };
}

describe('FightCore fixtures', () => {
  const core = fixtureCore();

  test('odds-conversion.json (40 cases)', () => {
    const root = loadJSON<{ cases: Array<{
      id: string;
      decimal: string;
      fractional: string;
      impliedProbability: string;
    }> }>('odds-conversion');

    expect(root.cases).toHaveLength(40);
    for (const testCase of root.cases) {
      const decimal = parseOdds(testCase.decimal);
      expect(decimalToFractional(decimal)).toBe(testCase.fractional);
      expect(formatImpliedProbability(decimal)).toBe(testCase.impliedProbability);
      const roundTrip = fractionalToDecimal(testCase.fractional);
      expect(formatMoney(roundTrip)).toBe(formatMoney(decimal));
    }
  });

  test('slip-math.json (6 cases)', () => {
    const root = loadJSON<{ cases: Array<{
      id: string;
      mode: 'single' | 'accumulator';
      stake: string;
      selections: Array<{ boutId: string; fighterId: string; odds: string }>;
      expect: {
        combinedOddsExact?: string;
        combinedOddsDisplay?: string;
        totalStake: string;
        potentialReturn: string;
        potentialProfit: string;
      };
    }> }>('slip-math');

    expect(root.cases).toHaveLength(6);
    for (const testCase of root.cases) {
      const slip = slipFromCase(testCase);
      const state = core.slipState(slip, new Decimal(10_000));
      if (testCase.expect.combinedOddsExact) {
        expect(formatExactOdds(state.combinedOddsExact!)).toBe(testCase.expect.combinedOddsExact);
      }
      if (testCase.expect.combinedOddsDisplay) {
        expect(formatMoney(state.combinedOddsDisplay!)).toBe(testCase.expect.combinedOddsDisplay);
      }
      expect(formatMoney(state.totalStake)).toBe(testCase.expect.totalStake);
      expect(formatMoney(state.potentialReturn)).toBe(testCase.expect.potentialReturn);
      expect(formatMoney(state.potentialProfit)).toBe(testCase.expect.potentialProfit);
    }
  });

  test('slip-validation.json (14 cases)', () => {
    const root = loadJSON<{ cases: Array<{
      id: string;
      mode: 'single' | 'accumulator';
      stake: string;
      balance: string;
      selections: Array<{ boutId: string; fighterId: string; odds: string }>;
      expect: { errors: string[] };
    }> }>('slip-validation');

    expect(root.cases).toHaveLength(14);
    for (const testCase of root.cases) {
      const slip = slipFromCase(testCase);
      const errors = core.validate(slip, parseMoney(testCase.balance));
      expect(errors).toEqual(testCase.expect.errors);
    }
  });

  test('settlement.json (7 cases)', () => {
    const root = loadJSON<{ cases: Array<{
      id: string;
      mode: 'single' | 'accumulator';
      stake: string;
      selections: Array<{ boutId: string; fighterId: string; odds: string }>;
      voidedBouts?: string[];
      expect: {
        legs: Array<{ boutId: string; fighterId: string; outcome: string }>;
        returned: string;
        profit: string;
        status: string;
      };
    }> }>('settlement');

    expect(root.cases).toHaveLength(7);
    for (const testCase of root.cases) {
      const slip = slipFromCase(testCase);
      const voided = new Set(testCase.voidedBouts ?? []);
      const result = core.settle(slip, voided);
      expect(formatMoney(result.returned)).toBe(testCase.expect.returned);
      expect(formatMoney(result.profit)).toBe(testCase.expect.profit);
      expect(result.status).toBe(testCase.expect.status);
      testCase.expect.legs.forEach((expected, index) => {
        expect(result.legs[index].boutId).toBe(expected.boutId);
        expect(result.legs[index].fighterId).toBe(expected.fighterId);
        expect(result.legs[index].outcome).toBe(expected.outcome);
      });
    }
  });

  test('cash-out.json (5 cases)', () => {
    const root = loadJSON<{ cases: Array<{
      id: string;
      mode: 'single' | 'accumulator';
      stake: string;
      selections: Array<{ boutId: string; fighterId: string; odds: string }>;
      settledBouts: string[];
      expect: { available: boolean; amount: string; reason: string | null };
    }> }>('cash-out');

    expect(root.cases).toHaveLength(5);
    for (const testCase of root.cases) {
      const slip = slipFromCase(testCase);
      const settled = new Set(testCase.settledBouts);
      const offer = core.cashOutOffer(slip, settled);
      expect(offer.available).toBe(testCase.expect.available);
      expect(formatMoney(offer.amount)).toBe(testCase.expect.amount);
      expect(offer.reason).toBe(testCase.expect.reason);
    }
  });
});
