# Contract

**This directory is frozen.** It was finished before any application code was written,
and that ordering is the point: five apps built by five agents drift, and the only thing
that reliably catches the drift is a specification that predates all of them.

## What is here

| Path | What it is |
| --- | --- |
| [`fightcore-api.md`](fightcore-api.md) | The full specification. Types, rounding, validation, settlement, cash-out, ports. |
| `fixtures/` | Golden files. Every implementation loads these and must match exactly. |

Regenerate the fixtures with `./tools/build-fixtures.py`. Do not hand-edit them — the
expected values are computed from the rules in the spec, and a hand-typed expectation is
a second implementation that nothing tests.

## The rules every implementation follows

1. **Money is decimal.** `Decimal`, `rust_decimal::Decimal`, `BigDecimal`. Never a
   binary float, not even briefly, not even for display.
2. **Round HALF_UP, once, at the end.** Intermediate values keep full precision.
   `slip-math.json` contains a case that differs by exactly one cent between the correct
   approach and the obvious wrong one.
3. **Validation returns every applicable error**, in the order given in the spec, and
   never throws.
4. **The core is headless and pure.** No I/O, no clock, no storage, no logging. Anything
   that touches the outside world is a port, declared by the core and implemented by the
   platform.
5. **Errors are typed.** They cross the FFI boundary as a domain error type. An error
   that arrives on the far side as a string has failed.

## What the fixtures cover

| File | Cases | Notable |
| --- | --- | --- |
| `odds-conversion.json` | 40 | Every price in the dataset. Fractions must be fully reduced. |
| `slip-math.json` | 6 | Includes the double-rounding trap. |
| `slip-validation.json` | 14 | Every error code, plus a slip that trips three at once. |
| `settlement.json` | 7 | Real results. One clearly-labelled synthetic case for the void rule. |
| `cash-out.json` | 5 | Partially settled accumulators. |

## The headline numbers

Worth knowing by heart, because they get said out loud on stage:

- The seven-fold on every Freedom 250 winner pays **36.11129032875**. A €10 stake
  returns **€361.11**. An implementation that rounds the odds first returns €361.10 and
  is wrong.
- Seven of the twenty bouts were won by the longer price, so the demo has real upsets
  to settle rather than a card of chalk.
- Gaethje at **4.60** and Strickland at **4.75** are the two prices the audience will
  remember.

## For the agent building an approach

You receive: this directory, `shared-ui-spec/`, `dataset/`, `versions.lock.toml`, and a
brief describing what your specific approach must demonstrate.

Rules of engagement:

- **Do not modify anything in `contract/`, `dataset/` or `shared-ui-spec/`.** If the
  spec is wrong or ambiguous, say so and stop. Do not work around it locally — a local
  workaround is precisely the drift this directory exists to prevent.
- **Do not touch another approach's directory.** Ever.
- Your core passes every fixture before your UI is considered started.
- The host apps must be visually indistinguishable across approaches. The mechanism of
  sharing is the only thing that is allowed to differ, because it is the only thing
  being measured.
