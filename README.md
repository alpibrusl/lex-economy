# lex-economy

Contracts, treasury, and reputation for a Lex agent economy — the layer that turns
existing primitives (`lex-soft` identity/ledger/spend/matchmaking, `lex-guard` spend
gating, `lex-x402` payment rail, `lex-trail` audit log) into an actual market, with
typed contracts a company can bid on, win, deliver against, and get paid for.

## Status

Early. Building module by module, starting with `identity` and `treasury` — the two
with the tightest, most mechanically-checkable specs (see each module's own header
comment for its invariants and how they're tested).

## Conventions

- **Mechanism, not policy.** This package never imports a consumer (e.g. `lex-loom`)
  and never names a specific company or product.
- **Pure core, effectful edges.** Each module keeps its types, validation and state
  transitions in a pure part, so importing it for the pure half doesn't inherit a
  wider effect footprint than needed.
- **Every state change is attested.** Storage-backed modules append a `lex-trail`
  event with a fixed `kind` string; verdicts and settlements should be
  reconstructible from the trail alone.
- **Money is integer cents.** No floats anywhere in this package.
- **Tests must be able to fail.** Every module ships positive tests, negative
  controls, and at least one documented "sabotage" test (disable the invariant, watch
  the test catch it).

## The loop

```sh
lex pkg install
lex check <each src/*.lex file>
lex fmt --check src/ tests/
lex test tests/
```
