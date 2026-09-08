import "../src/reputation" as rep
import "lex-trail/event" as ev
import "std.io" as io

fn company_payload(company :: Str) -> Str {
  str.concat("{\"company\": \"", str.concat(company, "\"}"))
}

fn event(kind :: Str, company :: Str) -> ev.Event {
  ev.make(kind, None, company_payload(company), 0)
}

fn event_raw(kind :: Str, payload_json :: Str) -> ev.Event {
  ev.make(kind, None, payload_json, 0)
}

fn reputations_equal(got :: rep.Reputation, want :: rep.Reputation) -> Bool {
  got.company == want.company and
  got.contracts_completed == want.contracts_completed and
  got.contracts_failed == want.contracts_failed and
  got.contracts_disputed == want.contracts_disputed and
  got.verification_pass_rate_bp == want.verification_pass_rate_bp
}

fn print_reputation(prefix :: Str, r :: rep.Reputation) -> [io] Unit {
  io.print(prefix)
  io.print(str.concat("company=", r.company))
  io.print(str.concat("completed=", int.to_str(r.contracts_completed)))
  io.print(str.concat("failed=", int.to_str(r.contracts_failed)))
  io.print(str.concat("disputed=", int.to_str(r.contracts_disputed)))
  io.print(str.concat("rate_bp=", int.to_str(r.verification_pass_rate_bp)))
}

fn check(name :: Str, got :: rep.Reputation, want :: rep.Reputation) -> [io] Bool {
  if reputations_equal(got, want) {
    io.print("OK")
    io.print(name)
    true
  } else {
    io.print("FAIL")
    io.print(name)
    print_reputation("got=", got)
    print_reputation("want=", want)
    false
  }
}

fn verify_empty_events() -> [io] Bool {
  # No events -> all counters zero, rate zero.
  let want := { company: "Acme", contracts_completed: 0, contracts_failed: 0, contracts_disputed: 0, verification_pass_rate_bp: 0 }
  check("empty_events", rep.project([], "Acme"), want)
}

fn verify_other_company_ignored() -> [io] Bool {
  # Events for BetaCorp must not affect Acme's reputation.
  let want := { company: "Acme", contracts_completed: 0, contracts_failed: 0, contracts_disputed: 0, verification_pass_rate_bp: 0 }
  check("other_company_ignored", rep.project([
    event("contract_settled", "BetaCorp"),
    event("verification_passed", "BetaCorp"),
    event("verification_failed", "BetaCorp")
  ], "Acme"), want)
}

fn verify_unparseable_payload_skipped() -> [io] Bool {
  # Malformed JSON is skipped; the valid event still counts.
  let want := { company: "Acme", contracts_completed: 1, contracts_failed: 0, contracts_disputed: 0, verification_pass_rate_bp: 0 }
  check("unparseable_payload_skipped", rep.project([
    event_raw("contract_settled", "{ not json"),
    event("contract_settled", "Acme")
  ], "Acme"), want)
}

fn verify_missing_company_field_skipped() -> [io] Bool {
  # JSON with no "company" string field is skipped.
  let want := { company: "Acme", contracts_completed: 0, contracts_failed: 1, contracts_disputed: 0, verification_pass_rate_bp: 0 }
  check("missing_company_field_skipped", rep.project([
    event_raw("contract_settled", "{}"),
    event("contract_failed", "Acme")
  ], "Acme"), want)
}

fn verify_company_field_not_string_skipped() -> [io] Bool {
  # Non-string "company" value is skipped.
  let want := { company: "Acme", contracts_completed: 0, contracts_failed: 0, contracts_disputed: 1, verification_pass_rate_bp: 0 }
  check("company_field_not_string_skipped", rep.project([
    event_raw("contract_settled", "{\"company\": 123}"),
    event("contract_disputed", "Acme")
  ], "Acme"), want)
}

fn verify_unknown_kind_skipped() -> [io] Bool {
  # Kinds outside the recognized set are ignored.
  let want := { company: "Acme", contracts_completed: 1, contracts_failed: 0, contracts_disputed: 0, verification_pass_rate_bp: 0 }
  check("unknown_kind_skipped", rep.project([
    event("weird_kind", "Acme"),
    event("contract_settled", "Acme")
  ], "Acme"), want)
}

fn verify_zero_verification_rate_is_zero() -> [io] Bool {
  # No verification events -> rate must be exactly 0, not a crash.
  let want := { company: "Acme", contracts_completed: 1, contracts_failed: 1, contracts_disputed: 1, verification_pass_rate_bp: 0 }
  check("zero_verification_rate_is_zero", rep.project([
    event("contract_settled", "Acme"),
    event("contract_failed", "Acme"),
    event("contract_disputed", "Acme")
  ], "Acme"), want)
}

fn verify_non_trivial_verification_rate() -> [io] Bool {
  # Hand-computed: 2 passed + 3 failed = 5 total.
  # rate = round((2 * 10000) / 5) = round(20000 / 5) = round(4000.0) = 4000 bp.
  let want := { company: "Acme", contracts_completed: 0, contracts_failed: 0, contracts_disputed: 0, verification_pass_rate_bp: 4000 }
  check("non_trivial_verification_rate", rep.project([
    event("verification_passed", "Acme"),
    event("verification_passed", "Acme"),
    event("verification_failed", "Acme"),
    event("verification_failed", "Acme"),
    event("verification_failed", "Acme")
  ], "Acme"), want)
}

fn verify_rounding_up() -> [io] Bool {
  # Hand-computed: 1 passed + 6 failed = 7 total.
  # rate = round((1 * 10000) / 7) = round(1428.571...) = 1429 bp.
  let want := { company: "Acme", contracts_completed: 0, contracts_failed: 0, contracts_disputed: 0, verification_pass_rate_bp: 1429 }
  check("rounding_up", rep.project([
    event("verification_passed", "Acme"),
    event("verification_failed", "Acme"),
    event("verification_failed", "Acme"),
    event("verification_failed", "Acme"),
    event("verification_failed", "Acme"),
    event("verification_failed", "Acme"),
    event("verification_failed", "Acme")
  ], "Acme"), want)
}

fn verify_perfect_rate() -> [io] Bool {
  # All verification events passed -> 10000 bp.
  let want := { company: "Acme", contracts_completed: 0, contracts_failed: 0, contracts_disputed: 0, verification_pass_rate_bp: 10000 }
  check("perfect_rate", rep.project([
    event("verification_passed", "Acme"),
    event("verification_passed", "Acme"),
    event("verification_passed", "Acme")
  ], "Acme"), want)
}

fn verify_all_fail_rate() -> [io] Bool {
  # All verification events failed -> 0 bp.
  let want := { company: "Acme", contracts_completed: 0, contracts_failed: 0, contracts_disputed: 0, verification_pass_rate_bp: 0 }
  check("all_fail_rate", rep.project([
    event("verification_failed", "Acme"),
    event("verification_failed", "Acme"),
    event("verification_failed", "Acme")
  ], "Acme"), want)
}

fn verify_full_mix() -> [io] Bool {
  # Target company Acme: 2 settled, 1 failed, 3 disputed, 2 passed, 3 failed verification.
  # Other company, unparseable, missing company, unknown kind all ignored.
  # Verification rate: round((2 * 10000) / 5) = 4000 bp.
  let want := { company: "Acme", contracts_completed: 2, contracts_failed: 1, contracts_disputed: 3, verification_pass_rate_bp: 4000 }
  check("full_mix", rep.project([
    event("contract_settled", "Acme"),
    event("contract_settled", "Acme"),
    event("contract_failed", "Acme"),
    event("contract_disputed", "Acme"),
    event("contract_disputed", "Acme"),
    event("contract_disputed", "Acme"),
    event("verification_passed", "Acme"),
    event("verification_passed", "Acme"),
    event("verification_failed", "Acme"),
    event("verification_failed", "Acme"),
    event("verification_failed", "Acme"),
    event("contract_settled", "BetaCorp"),
    event_raw("contract_settled", "{ not json"),
    event_raw("contract_settled", "{}"),
    event("unknown_kind", "Acme")
  ], "Acme"), want)
}

fn main() -> [io] Unit {
  let r1 := verify_empty_events()
  let r2 := verify_other_company_ignored()
  let r3 := verify_unparseable_payload_skipped()
  let r4 := verify_missing_company_field_skipped()
  let r5 := verify_company_field_not_string_skipped()
  let r6 := verify_unknown_kind_skipped()
  let r7 := verify_zero_verification_rate_is_zero()
  let r8 := verify_non_trivial_verification_rate()
  let r9 := verify_rounding_up()
  let r10 := verify_perfect_rate()
  let r11 := verify_all_fail_rate()
  let r12 := verify_full_mix()
  if r1 and r2 and r3 and r4 and r5 and r6 and r7 and r8 and r9 and r10 and r11 and r12 {
    io.print("ALL CHECKS PASSED")
  } else {
    io.print("SOME CHECKS FAILED")
  }
}
