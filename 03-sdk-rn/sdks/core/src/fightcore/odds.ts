import Decimal from 'decimal.js';
import { money, parseMoney, round } from './money';

function gcd(a: number, b: number): number {
  let x = Math.abs(a);
  let y = Math.abs(b);
  while (y !== 0) {
    const temp = y;
    y = x % y;
    x = temp;
  }
  return Math.max(x, 1);
}

export function decimalToFractional(decimalOdds: Decimal.Value): string {
  const profit = new Decimal(decimalOdds).minus(1);
  const scaled = profit.times(10_000).toNumber();
  const divisor = gcd(Math.round(scaled), 10_000);
  return `${Math.round(scaled) / divisor}/${10_000 / divisor}`;
}

export function fractionalToDecimal(fractional: string): Decimal {
  const parts = fractional.split('/');
  if (parts.length !== 2) {
    return new Decimal(0);
  }
  const numerator = Number(parts[0]);
  const denominator = Number(parts[1]);
  if (!Number.isFinite(numerator) || !Number.isFinite(denominator) || denominator <= 0) {
    return new Decimal(0);
  }
  const profit = new Decimal(numerator).dividedBy(denominator);
  return money(profit.plus(1));
}

export function impliedProbability(decimalOdds: Decimal.Value): Decimal {
  return round(new Decimal(1).dividedBy(decimalOdds), 4);
}

export function formatExactOdds(value: Decimal.Value): string {
  const d = new Decimal(value);
  // Match Swift NumberFormatter: up to 12 fraction digits, no grouping.
  return d.toFixed(12).replace(/\.?0+$/, '');
}

export function formatOdds(value: Decimal.Value): string {
  return money(value).toFixed(2);
}

export function formatImpliedProbability(decimalOdds: Decimal.Value): string {
  return impliedProbability(decimalOdds).toFixed(4);
}

export function parseOdds(value: string): Decimal {
  return parseMoney(value);
}
