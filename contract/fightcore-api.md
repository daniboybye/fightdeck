# FightCore — the contract

**Frozen.** Every implementation — hand-written Swift, hand-written Kotlin, the Swift
core, the Rust core — implements exactly this and passes exactly the fixtures in
`fixtures/`. Names are given in a language-neutral form; each implementation renders
them in its own idiom (`camelCase` in Swift and Kotlin, `snake_case` in Rust).

If a rule below turns out to be ambiguous, the fix is to sharpen this document and
regenerate the fixtures, never to make one implementation special.

## Why this document exists

Five apps are built by five separate agents. They will drift. This is the thing that
catches the drift before an audience does — and drift about money is the worst kind,
because two phones on a projector showing different payouts for the same accumulator
destroys the talk in one slide.

---

## 1. Money and rounding

Money is a **decimal** type. Never a binary float.

- Swift: `Decimal`
- Rust: `rust_decimal::Decimal`
- Kotlin: `java.math.BigDecimal`
- TypeScript: a decimal library, or integer minor units. Not `number`.

**Currency** is EUR throughout. Amounts carry 2 decimal places.

**Rounding mode is HALF_UP**, and it is applied **only when producing a monetary
amount**. This is the single most important rule in the document, because Swift's
`Decimal`, `BigDecimal` and `rust_decimal` all default to something different, and an
implementation that takes the default will pass most fixtures and fail a few by one cent.

**Intermediate values are never rounded.** In particular, accumulator odds are
multiplied at full precision and only the resulting money is rounded. The rounded
combined-odds figure exists for display and must not feed the payout:

```
stake 10.00 on the seven Freedom 250 winners
  combined odds (exact)     36.11129032875
  combined odds (display)   36.11
  return (correct)          361.11     <- 10.00 * 36.11129032875, rounded once
  return (wrong)            361.10     <- 10.00 * 36.11, rounded twice
```

One cent. It is in the fixtures deliberately.

---

## 2. Odds

Odds are a decimal value greater than `1.00`, stored and transported as a **string**
so that no parser has an opportunity to introduce a float.

### Representations

| Representation | Example | Used for |
| --- | --- | --- |
| Decimal | `4.60` | canonical, all arithmetic |
| Fractional | `18/5` | display toggle |
| American | `+360` | **not supported** — provenance only, lives in the dataset |

American odds are deliberately out of scope. The audience is European and supporting a
third notation adds conversion surface without adding anything to the comparison.

### Operations

```
decimal_to_fractional(decimal) -> string
fractional_to_decimal(string)  -> decimal
implied_probability(decimal)   -> decimal      // 1 / decimal, 4 dp, HALF_UP
```

`decimal_to_fractional` returns the profit part as a **fully reduced** fraction:
`4.60 -> 18/5`, `1.20 -> 1/5`, `2.50 -> 3/2`. Reduction is by greatest common divisor;
`36/10` is a failure, not a variant.

`fractional_to_decimal` accepts `n/d` with positive integers and returns
`n/d + 1` at 2 dp, HALF_UP.

---

## 3. Selections and the slip

### Selection

```
Selection {
    bout_id:    string      // e.g. "ufc-328-bout-01"
    fighter_id: string      // the pick; must be one of the bout's two corners
    odds:       decimal     // price captured when the selection was added
}
```

Odds are captured **at add time**. A later price move does not retroactively change a
selection already on the slip; that is what real slips do, and it makes the fixtures
stable.

### Slip

```
BetSlip {
    mode:         Single | Accumulator
    selections:   [Selection]
    stake:        decimal
}
```

**Single** mode means the stake is placed on *each* selection independently: total
outlay is `stake * count(selections)`. **Accumulator** means one stake across all legs,
and every leg must win.

### Derived state

```
SlipState {
    combined_odds_exact:    decimal   // full precision, accumulator only
    combined_odds_display:  decimal   // 2 dp, HALF_UP
    total_stake:            decimal   // stake, or stake * n for singles
    potential_return:       decimal   // 2 dp, HALF_UP
    potential_profit:       decimal   // potential_return - total_stake
    errors:                 [ValidationError]
}
```

For **accumulator**: `combined_odds_exact` is the product of all selection odds.
`potential_return = round(stake * combined_odds_exact)`.

For **single**: `potential_return = sum over selections of round(stake * odds)`.
Each leg is rounded on its own, because each is a separate bet — rounding the sum
instead is a different (and wrong) number.

`combined_odds_exact` and `combined_odds_display` are undefined for single mode.

---

## 4. Validation

Evaluated against these limits:

```
MIN_STAKE          = 1.00
MAX_STAKE          = 5000.00
MAX_SELECTIONS     = 12
MIN_ACCA_LEGS      = 2
MAX_PAYOUT         = 100000.00
```

### Errors

| Code | Raised when |
| --- | --- |
| `empty_slip` | no selections |
| `stake_below_minimum` | `stake < MIN_STAKE` |
| `stake_above_maximum` | `stake > MAX_STAKE` |
| `insufficient_balance` | `total_stake > balance` |
| `too_many_selections` | `count > MAX_SELECTIONS` |
| `accumulator_needs_two_legs` | accumulator mode with fewer than `MIN_ACCA_LEGS` |
| `duplicate_bout` | two selections on the same `bout_id` |
| `unknown_bout` | `bout_id` is not in the dataset |
| `fighter_not_in_bout` | `fighter_id` is neither corner of that bout |
| `payout_exceeds_limit` | `potential_return > MAX_PAYOUT` |

**All applicable errors are returned, not just the first.** A slip that is both
underfunded and over the leg limit reports both. Returning one error at a time makes a
form that fights the user, and it also makes for a weaker fixture.

**Order is stable**: errors come back in the order listed in the table above. Two
implementations that agree on the set but not the order would otherwise fail the
fixtures for no good reason.

Validation is **pure**. It reads the slip, the balance and the dataset, and returns
errors. It does not mutate, log or throw.

---

## 5. Settlement

Settlement runs a slip against the real results.

```
settle(slip, results) -> Settlement

Settlement {
    legs:     [LegOutcome]
    returned: decimal          // 2 dp, HALF_UP
    profit:   decimal          // returned - total_stake
    status:   Won | Lost | Void | PartiallyWon
}
```

```
LegOutcome = Won | Lost | Void
```

### Rules

- A leg is **Won** when its `fighter_id` matches the bout's winner.
- A leg is **Lost** when the other corner won.
- A leg is **Void** when the bout was a draw or a no contest. **A void leg's odds
  become `1.00`** — it drops out of the accumulator without killing it. None of the
  twenty real bouts is void; the rule is exercised by a synthetic fixture, which is
  labelled as such.

**Accumulator**: if any leg is Lost, `returned = 0.00` and status is `Lost`. Otherwise
`returned = round(stake * product(effective odds))` where a void leg contributes
`1.00`, and status is `Won`.

**Single**: each leg settles on its own.
`returned = sum over legs of (round(stake * odds) if Won, stake if Void, 0 if Lost)`.
Status is `Won` if every leg won, `Lost` if none did, otherwise `PartiallyWon`.

---

## 6. Cash-out

Real cash-out pricing is proprietary and unknowable. This is a **defined, deterministic
model** so that all implementations produce identical offers — the point of the screen
is the shared arithmetic, not a trading algorithm.

```
CASH_OUT_MARGIN = 0.05      // the operator's cut
```

```
cash_out_offer(slip, results) -> CashOutOffer

CashOutOffer {
    available: bool
    amount:    decimal      // 2 dp, HALF_UP; 0.00 when unavailable
    reason:    string?      // why not, when unavailable
}
```

Accumulator only. Rules, in order:

1. Any leg Lost → `available = false`, `amount = 0.00`, reason `bet_already_lost`
2. Every leg settled → `available = false`, reason `bet_already_settled`
3. Otherwise:
   ```
   fair_value = stake * product(odds of legs already Won)
   amount     = round(fair_value * (1 - CASH_OUT_MARGIN))
   ```
   Legs still pending contribute nothing. With no legs settled yet this correctly
   yields `stake * 0.95`: you get most of your money back and the operator keeps the
   spread.

Single-mode slips have no cash-out: `available = false`, reason `not_an_accumulator`.

---

## 7. Ports the core does not implement

The core is headless and pure. Everything below is a **port**: declared by the core,
implemented by the platform. This is the same shape in all four implementations, and it
is the thing the Rust section of the talk is about — the core defines the hole, the
shell fills it.

```
port Clock {
    now() -> timestamp
}

port PreferencesStore {
    read(key: string)  -> string?
    write(key: string, value: string)
}

port FightRepository {
    load_events()   async throws -> [Event]
    load_fighters() async throws -> [Fighter]
}
```

`PreferencesStore` is the interesting one and it is chosen on purpose: it lands on
`UserDefaults` on iOS and `SharedPreferences` on Android, and the Android side has no
native API at all, so every core has to answer the question differently. That asymmetry
is a slide.

Implementations:

- **Swift core** — a Swift protocol, implemented in Kotlin on the Android side
- **Rust core** — a UniFFI foreign trait (`#[uniffi::export(with_foreign)]`), not the
  deprecated callback interface
- **Native baseline** — an ordinary protocol and interface, written twice

---

## 8. Async across the boundary

`FightRepository` is async, deliberately, because how each technology carries async
across an FFI boundary is one of the things being compared.

- **Swift core** — `async throws`, surfacing on the Android side as a Kotlin `suspend`
  function
- **Rust core** — `#[uniffi::export(async_runtime = "tokio")]`, surfacing as Swift
  `async` and Kotlin `suspend`
- **Native baseline** — `async` and `suspend`, written twice

Errors cross as a typed domain error, never as a string:

```
FightCoreError =
    | Network(retryable: bool)
    | Decoding(field: string)
    | Validation(errors: [ValidationError])
```

Swift uses typed throws. Rust uses `#[derive(uniffi::Error)]`. Neither is allowed to
degrade into an untyped message on the far side.

---

## 9. Observable state

Each core exposes the slip as observable state so the UI can bind to it:

- **Swift core** — `@Observable`, tracked directly by SwiftUI and, via Skip's bridge,
  by Compose
- **Rust core** — a foreign trait listener; the Swift wrapper republishes as
  `@Observable`, the Kotlin wrapper fills a `MutableStateFlow`. UniFFI knows nothing
  about either, and writing that glue by hand is precisely the cost being measured
- **Native baseline** — `@Observable` and `StateFlow`, written twice

---

## 10. Fixtures

`fixtures/` holds the golden files. Every implementation loads the same JSON and must
match every expected value exactly — a cent of difference is a failure.

| File | Covers |
| --- | --- |
| `odds-conversion.json` | Every price in the dataset, all three notations, round-tripped |
| `slip-math.json` | Combined odds, returns, the double-rounding trap |
| `slip-validation.json` | Every error code, plus multi-error slips |
| `settlement.json` | Real results: singles, accumulators, the seven-fold |
| `cash-out.json` | Partially settled accumulators |

Regenerate with `./tools/build-fixtures.py`. Expected values are **computed** from the
rules in this document, never typed in by hand — a hand-typed expectation is just a
second implementation with no tests.
