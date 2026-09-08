import "std.list" as list

import "lex-trail/event" as ev

import "lex-schema/json_value" as jv

type Reputation = { company :: Str, contracts_completed :: Int, contracts_failed :: Int, contracts_disputed :: Int, verification_pass_rate_bp :: Int }

type Acc = { contracts_completed :: Int, contracts_failed :: Int, contracts_disputed :: Int, verification_passed :: Int, verification_failed :: Int }

fn company_payload(company :: Str) -> Str {
  str.concat("{\"company\": \"", str.concat(company, "\"}"))
}

fn verification_rate_bp(passed :: Int, failed :: Int) -> Int {
  let total := passed + failed
  if total == 0 {
    0
  } else {
    (passed * 10000 + total / 2) / total
  }
}

fn event_company(e :: ev.Event) -> Option[Str] {
  match jv.parse_into_errors(e.payload_json) {
    Err(_) => None,
    Ok(json) => {
      match jv.get_field(json, "company") {
        Some(JStr(c)) => Some(c),
        _ => None,
      }
    },
  }
}

# 3 verification_passed + 4 verification_failed => round(30000 / 7) = 4286 bp
fn project(events :: List[ev.Event], company :: Str) -> Reputation
  examples {
    project([], "Acme") => { company: "Acme", contracts_completed: 0, contracts_failed: 0, contracts_disputed: 0, verification_pass_rate_bp: 0 },
    project([ev.make("contract_settled", None, company_payload("Acme"), 0), ev.make("contract_failed", None, company_payload("Acme"), 0), ev.make("contract_disputed", None, company_payload("Acme"), 0), ev.make("verification_passed", None, company_payload("Acme"), 0), ev.make("verification_failed", None, company_payload("Acme"), 0), ev.make("contract_settled", None, company_payload("OtherCo"), 0), ev.make("contract_settled", None, "{ not json", 0), ev.make("contract_settled", None, "{}", 0), ev.make("unknown_kind", None, company_payload("Acme"), 0)], "Acme") => { company: "Acme", contracts_completed: 1, contracts_failed: 1, contracts_disputed: 1, verification_pass_rate_bp: 5000 },
    project([ev.make("verification_passed", None, company_payload("Acme"), 0), ev.make("verification_passed", None, company_payload("Acme"), 0), ev.make("verification_passed", None, company_payload("Acme"), 0), ev.make("verification_failed", None, company_payload("Acme"), 0), ev.make("verification_failed", None, company_payload("Acme"), 0), ev.make("verification_failed", None, company_payload("Acme"), 0), ev.make("verification_failed", None, company_payload("Acme"), 0)], "Acme") => { company: "Acme", contracts_completed: 0, contracts_failed: 0, contracts_disputed: 0, verification_pass_rate_bp: 4286 }
  }
{
  let zero := { contracts_completed: 0, contracts_failed: 0, contracts_disputed: 0, verification_passed: 0, verification_failed: 0 }
  let acc := list.fold(events, zero, fn (state :: Acc, e :: ev.Event) -> Acc {
    match event_company(e) {
      None => state,
      Some(c) => {
        if c != company {
          state
        } else {
          match e.kind {
            "contract_settled" => { contracts_completed: state.contracts_completed + 1, contracts_failed: state.contracts_failed, contracts_disputed: state.contracts_disputed, verification_passed: state.verification_passed, verification_failed: state.verification_failed },
            "contract_failed" => { contracts_completed: state.contracts_completed, contracts_failed: state.contracts_failed + 1, contracts_disputed: state.contracts_disputed, verification_passed: state.verification_passed, verification_failed: state.verification_failed },
            "contract_disputed" => { contracts_completed: state.contracts_completed, contracts_failed: state.contracts_failed, contracts_disputed: state.contracts_disputed + 1, verification_passed: state.verification_passed, verification_failed: state.verification_failed },
            "verification_passed" => { contracts_completed: state.contracts_completed, contracts_failed: state.contracts_failed, contracts_disputed: state.contracts_disputed, verification_passed: state.verification_passed + 1, verification_failed: state.verification_failed },
            "verification_failed" => { contracts_completed: state.contracts_completed, contracts_failed: state.contracts_failed, contracts_disputed: state.contracts_disputed, verification_passed: state.verification_passed, verification_failed: state.verification_failed + 1 },
            _ => state,
          }
        }
      },
    }
  })
  { company: company, contracts_completed: acc.contracts_completed, contracts_failed: acc.contracts_failed, contracts_disputed: acc.contracts_disputed, verification_pass_rate_bp: verification_rate_bp(acc.verification_passed, acc.verification_failed) }
}

