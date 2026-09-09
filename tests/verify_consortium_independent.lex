import "../src/consortium" as consortium

import "../src/contract" as contract

import "std.io" as io

import "std.list" as list

fn report(name :: Str, got :: Bool, want :: Bool) -> [io] Unit {
  if got == want {
    io.print("OK")
    io.print(name)
  } else {
    io.print("FAIL")
    io.print(name)
  }
}

fn check(name :: Str, got :: Bool, want :: Bool) -> [io] Bool {
  report(name, got, want)
  got == want
}

fn check_terminate(name :: Str, view :: consortium.PortfolioView, rule :: consortium.TerminationRule, want :: Bool) -> [io] Bool {
  check(name, consortium.should_terminate(view, rule), want)
}

fn company_in(companies :: List[Str], company :: Str) -> Bool {
  list.len(list.filter(companies, fn (c :: Str) -> Bool {
    c == company
  })) > 0
}

fn main() -> [io] Unit {
  let rule := { max_spend_cents: 10000, deadline_ms: 2000 }
  let r1 := check_terminate("none_hold", { objective_met: false, total_spent_cents: 5000, open_contracts: 2, remaining_capital_cents: 1000, now_ms: 1000 }, rule, false)
  let r2 := check_terminate("objective_met_alone", { objective_met: true, total_spent_cents: 5000, open_contracts: 2, remaining_capital_cents: 1000, now_ms: 1000 }, rule, true)
  let r3 := check_terminate("spend_exactly_at_ceiling", { objective_met: false, total_spent_cents: 10000, open_contracts: 2, remaining_capital_cents: 1000, now_ms: 1000 }, rule, true)
  let r4 := check_terminate("spend_over_ceiling", { objective_met: false, total_spent_cents: 10500, open_contracts: 2, remaining_capital_cents: 1000, now_ms: 1000 }, rule, true)
  let r5 := check_terminate("past_deadline", { objective_met: false, total_spent_cents: 5000, open_contracts: 2, remaining_capital_cents: 1000, now_ms: 2500 }, rule, true)
  let r6 := check_terminate("condition4_zero_capital", { objective_met: false, total_spent_cents: 5000, open_contracts: 0, remaining_capital_cents: 0, now_ms: 1000 }, rule, true)
  let r7 := check_terminate("condition4_negative_capital", { objective_met: false, total_spent_cents: 5000, open_contracts: 0, remaining_capital_cents: -100, now_ms: 1000 }, rule, true)
  let r8 := check_terminate("near_miss_zero_contracts_positive_capital", { objective_met: false, total_spent_cents: 5000, open_contracts: 0, remaining_capital_cents: 1000, now_ms: 1000 }, rule, false)
  let r9 := check_terminate("near_miss_exhausted_capital_open_contracts", { objective_met: false, total_spent_cents: 5000, open_contracts: 1, remaining_capital_cents: 0, now_ms: 1000 }, rule, false)
  let r10 := check_terminate("exactly_at_deadline", { objective_met: false, total_spent_cents: 5000, open_contracts: 2, remaining_capital_cents: 1000, now_ms: 2000 }, rule, false)
  let max_spend := { cents: 500000, currency: "USD" }
  let built := consortium.new_consortium("consortium-1", "deliver widgets", ["company-a", "company-b"], max_spend)
  let n1 := check("new_id", built.id == "consortium-1", true)
  let n2 := check("new_objective", built.objective == "deliver widgets", true)
  let n3 := check("new_companies_has_a", company_in(built.companies, "company-a"), true)
  let n4 := check("new_companies_has_b", company_in(built.companies, "company-b"), true)
  let n5 := check("new_companies_len", list.len(built.companies) == 2, true)
  let n6 := check("new_max_spend_cents", built.max_spend.cents == 500000, true)
  let n7 := check("new_max_spend_currency", built.max_spend.currency == "USD", true)
  if r1 and r2 and r3 and r4 and r5 and r6 and r7 and r8 and r9 and r10 and n1 and n2 and n3 and n4 and n5 and n6 and n7 {
    io.print("ALL CHECKS PASSED")
  } else {
    io.print("SOME CHECKS FAILED")
  }
}

