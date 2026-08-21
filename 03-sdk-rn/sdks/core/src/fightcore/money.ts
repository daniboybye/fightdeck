import Decimal from 'decimal.js';

Decimal.set({ precision: 40, rounding: Decimal.ROUND_HALF_UP });

export type Money = Decimal;

export function parseMoney(value: string): Money {
  return new Decimal(value);
}

/** Round to monetary scale (2 dp, HALF_UP). */
export function money(value: Decimal.Value): Money {
  return new Decimal(value).toDecimalPlaces(2, Decimal.ROUND_HALF_UP);
}

/** Round to arbitrary scale (HALF_UP). */
export function round(value: Decimal.Value, scale: number): Money {
  return new Decimal(value).toDecimalPlaces(scale, Decimal.ROUND_HALF_UP);
}

export function formatMoney(value: Decimal.Value): string {
  return money(value).toFixed(2);
}

export function formatCurrency(value: Decimal.Value): string {
  return `€${formatMoney(value)}`;
}
