import "../src/reputation" as rep
import "lex-trail/event" as ev

fn payload(company :: Str, extra :: Str) -> Str {
  str.concat("{\"company\": \"", str.concat(company, str.concat("\"", extra)))
}

fn company_payload(company :: Str) -> Str {
  payload(company, "}")
}

fn event(kind :: Str, company :: Str) -> ev.Event {
  ev.make(kind, None, company_payload(company), 0)
}

fn event_raw(kind :: Str, payload_json :: Str) -> ev.Event {
  ev.make(kind, None, payload_json, 0)
}

fn test_empty_events() -> Bool
  examples { test_empty_events() => true }
{
  let r := rep.project([], "Acme")
  r.company == "Acme" and r.contracts_completed == 0 and r.contracts_failed == 0 and r.contracts_disputed == 0 and r.verification_pass_rate_bp == 0
}

fn test_other_company_ignored() -> Bool
  examples { test_other_company_ignored() => true }
{
  let r := rep.project([event("contract_settled", "OtherCo"), event("contract_failed", "OtherCo")], "Acme")
  r.contracts_completed == 0 and r.contracts_failed == 0 and r.contracts_disputed == 0 and r.verification_pass_rate_bp == 0
}

fn test_unparseable_payload_skipped() -> Bool
  examples { test_unparseable_payload_skipped() => true }
{
  let r := rep.project([event_raw("contract_settled", "{ not json"), event("contract_settled", "Acme")], "Acme")
  r.contracts_completed == 1 and r.contracts_failed == 0 and r.contracts_disputed == 0
}

fn test_missing_company_field_skipped() -> Bool
  examples { test_missing_company_field_skipped() => true }
{
  let r := rep.project([event_raw("contract_settled", "{}"), event("contract_settled", "Acme")], "Acme")
  r.contracts_completed == 1 and r.contracts_failed == 0 and r.contracts_disputed == 0
}

fn test_company_field_not_string_skipped() -> Bool
  examples { test_company_field_not_string_skipped() => true }
{
  let r := rep.project([event_raw("contract_settled", "{\"company\": 123}"), event("contract_settled", "Acme")], "Acme")
  r.contracts_completed == 1 and r.contracts_failed == 0 and r.contracts_disputed == 0
}

fn test_unknown_kind_skipped() -> Bool
  examples { test_unknown_kind_skipped() => true }
{
  let r := rep.project([event("unknown_kind", "Acme"), event("contract_settled", "Acme")], "Acme")
  r.contracts_completed == 1 and r.contracts_failed == 0 and r.contracts_disputed == 0
}

fn test_zero_verification_rate_is_zero() -> Bool
  examples { test_zero_verification_rate_is_zero() => true }
{
  let r := rep.project([event("contract_settled", "Acme"), event("contract_failed", "Acme")], "Acme")
  r.verification_pass_rate_bp == 0
}

fn test_mixed_contract_counts() -> Bool
  examples { test_mixed_contract_counts() => true }
{
  let r := rep.project([
    event("contract_settled", "Acme"),
    event("contract_settled", "Acme"),
    event("contract_failed", "Acme"),
    event("contract_disputed", "Acme"),
    event("contract_disputed", "Acme"),
    event("contract_disputed", "Acme")
  ], "Acme")
  r.contracts_completed == 2 and r.contracts_failed == 1 and r.contracts_disputed == 3
}

fn test_verification_rate_rounding() -> Bool
  examples { test_verification_rate_rounding() => true }
{
  # 3 passed + 4 failed => round(30000 / 7) = 4286 bp
  let r := rep.project([
    event("verification_passed", "Acme"),
    event("verification_passed", "Acme"),
    event("verification_passed", "Acme"),
    event("verification_failed", "Acme"),
    event("verification_failed", "Acme"),
    event("verification_failed", "Acme"),
    event("verification_failed", "Acme")
  ], "Acme")
  r.verification_pass_rate_bp == 4286
}

fn test_perfect_verification_rate() -> Bool
  examples { test_perfect_verification_rate() => true }
{
  let r := rep.project([
    event("verification_passed", "Acme"),
    event("verification_passed", "Acme"),
    event("verification_passed", "Acme")
  ], "Acme")
  r.verification_pass_rate_bp == 10000
}

fn test_zero_pass_some_fail() -> Bool
  examples { test_zero_pass_some_fail() => true }
{
  let r := rep.project([
    event("verification_failed", "Acme"),
    event("verification_failed", "Acme"),
    event("verification_failed", "Acme")
  ], "Acme")
  r.verification_pass_rate_bp == 0
}

fn test_all_skipped_result_is_zero() -> Bool
  examples { test_all_skipped_result_is_zero() => true }
{
  let r := rep.project([
    event_raw("contract_settled", "{ not json"),
    event_raw("contract_settled", "{}"),
    event("unknown_kind", "Acme"),
    event("contract_settled", "OtherCo")
  ], "Acme")
  r.company == "Acme" and r.contracts_completed == 0 and r.contracts_failed == 0 and r.contracts_disputed == 0 and r.verification_pass_rate_bp == 0
}

fn test_full_mix() -> Bool
  examples { test_full_mix() => true }
{
  let r := rep.project([
    event("contract_settled", "Acme"),
    event("contract_failed", "Acme"),
    event("contract_disputed", "Acme"),
    event("verification_passed", "Acme"),
    event("verification_failed", "Acme"),
    event("contract_settled", "OtherCo"),
    event_raw("contract_settled", "{ not json"),
    event_raw("contract_settled", "{}"),
    event("unknown_kind", "Acme")
  ], "Acme")
  r.company == "Acme" and r.contracts_completed == 1 and r.contracts_failed == 1 and r.contracts_disputed == 1 and r.verification_pass_rate_bp == 5000
}

fn run_all() -> Bool {
  test_empty_events() and
  test_other_company_ignored() and
  test_unparseable_payload_skipped() and
  test_missing_company_field_skipped() and
  test_company_field_not_string_skipped() and
  test_unknown_kind_skipped() and
  test_zero_verification_rate_is_zero() and
  test_mixed_contract_counts() and
  test_verification_rate_rounding() and
  test_perfect_verification_rate() and
  test_zero_pass_some_fail() and
  test_all_skipped_result_is_zero() and
  test_full_mix()
}
