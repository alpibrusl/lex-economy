import "../src/evidence" as evidence

import "../src/contract" as contract

import "../src/request_bid" as request_bid

import "std.io" as io

import "std.str" as str

import "std.list" as list

fn evidence_item(attr :: Str, satisfied :: Bool, note :: Str) -> evidence.EvidenceItem {
  { attr: attr, satisfied: satisfied, note: note }
}

fn criterion(attr :: Str, description :: Str) -> request_bid.Criterion {
  { attr: attr, description: description }
}

fn verdict_eq(got :: contract.Verdict, want :: contract.Verdict) -> Bool {
  match got {
    Fulfilled => match want {
      Fulfilled => true,
      _ => false,
    },
    PartiallyFulfilled(got_unmet) => match want {
      PartiallyFulfilled(want_unmet) => list_eq(got_unmet, want_unmet),
      _ => false,
    },
    Rejected(got_unmet) => match want {
      Rejected(want_unmet) => list_eq(got_unmet, want_unmet),
      _ => false,
    },
    Ambiguous(got_unassessed) => match want {
      Ambiguous(want_unassessed) => list_eq(got_unassessed, want_unassessed),
      _ => false,
    },
  }
}

fn list_eq(xs :: List[Str], ys :: List[Str]) -> Bool {
  if list.len(xs) != list.len(ys) {
    false
  } else {
    list_eq_same_len(xs, ys)
  }
}

fn list_eq_same_len(xs :: List[Str], ys :: List[Str]) -> Bool {
  match list.head(xs) {
    None => true,
    Some(x) => match list.head(ys) {
      None => false,
      Some(y) => if x == y {
        list_eq_same_len(list.tail(xs), list.tail(ys))
      } else {
        false
      },
    },
  }
}

fn str_list(xs :: List[Str]) -> Str {
  str.concat("[", str.concat(str.join(xs, ", "), "]"))
}

fn verdict_str(v :: contract.Verdict) -> Str {
  match v {
    Fulfilled => "Fulfilled",
    PartiallyFulfilled(unmet) => str.concat("PartiallyFulfilled(", str.concat(str_list(unmet), ")")),
    Rejected(unmet) => str.concat("Rejected(", str.concat(str_list(unmet), ")")),
    Ambiguous(unassessed) => str.concat("Ambiguous(", str.concat(str_list(unassessed), ")")),
  }
}

fn evidence_opt_str(o :: Option[evidence.EvidenceItem]) -> Str {
  match o {
    None => "None",
    Some(item) => str.concat("Some({ attr: ", str.concat(item.attr, str.concat(", satisfied: ", str.concat(bool_str(item.satisfied), str.concat(", note: ", str.concat(item.note, " })")))))),
  }
}

fn bool_str(b :: Bool) -> Str {
  if b {
    "true"
  } else {
    "false"
  }
}

fn check_evidence_item(name :: Str, got :: Option[evidence.EvidenceItem], want :: Option[evidence.EvidenceItem]) -> [io] Bool {
  if got == want {
    io.print("OK")
    io.print(name)
    true
  } else {
    io.print("FAIL")
    io.print(name)
    io.print(str.concat("got=", evidence_opt_str(got)))
    io.print(str.concat("want=", evidence_opt_str(want)))
    false
  }
}

fn check_verdict(name :: Str, got :: contract.Verdict, want :: contract.Verdict) -> [io] Bool {
  if verdict_eq(got, want) {
    io.print("OK")
    io.print(name)
    true
  } else {
    io.print("FAIL")
    io.print(name)
    io.print(str.concat("got=", verdict_str(got)))
    io.print(str.concat("want=", verdict_str(want)))
    false
  }
}

fn verify_find_evidence_found() -> [io] Bool {
  let items := [evidence_item("license", true, "valid"), evidence_item("insurance", false, "expired")]
  check_evidence_item("find_evidence found", evidence.find_evidence(items, "insurance"), Some(evidence_item("insurance", false, "expired")))
}

fn verify_find_evidence_not_found_empty() -> [io] Bool {
  check_evidence_item("find_evidence not found empty", evidence.find_evidence([], "license"), None)
}

fn verify_find_evidence_not_found_nonempty() -> [io] Bool {
  let items := [evidence_item("license", true, "valid")]
  check_evidence_item("find_evidence not found nonempty", evidence.find_evidence(items, "insurance"), None)
}

fn verify_evaluate_empty_criteria() -> [io] Bool {
  check_verdict("evaluate empty criteria", evidence.evaluate([], []), contract.Fulfilled)
}

fn verify_evaluate_all_unassessed() -> [io] Bool {
  let criteria := [criterion("license", "must be licensed"), criterion("insurance", "must be insured")]
  check_verdict("evaluate all unassessed", evidence.evaluate(criteria, []), contract.Ambiguous(["license", "insurance"]))
}

fn verify_evaluate_unassessed_wins_over_unmet() -> [io] Bool {
  let criteria := [criterion("license", "must be licensed"), criterion("insurance", "must be insured")]
  let items := [evidence_item("license", false, "missing")]
  check_verdict("evaluate unassessed wins over unmet", evidence.evaluate(criteria, items), contract.Ambiguous(["insurance"]))
}

fn verify_evaluate_all_met() -> [io] Bool {
  let criteria := [criterion("license", "must be licensed"), criterion("insurance", "must be insured")]
  let items := [evidence_item("license", true, "valid"), evidence_item("insurance", true, "valid")]
  check_verdict("evaluate all met", evidence.evaluate(criteria, items), contract.Fulfilled)
}

fn verify_evaluate_all_unmet() -> [io] Bool {
  let criteria := [criterion("license", "must be licensed"), criterion("insurance", "must be insured")]
  let items := [evidence_item("license", false, "missing"), evidence_item("insurance", false, "missing")]
  check_verdict("evaluate all unmet", evidence.evaluate(criteria, items), contract.Rejected(["license", "insurance"]))
}

fn verify_evaluate_met_unmet_mix() -> [io] Bool {
  let criteria := [criterion("bond", "must be bonded"), criterion("license", "must be licensed"), criterion("insurance", "must be insured")]
  let items := [evidence_item("bond", false, "missing"), evidence_item("license", true, "valid"), evidence_item("insurance", false, "expired")]
  check_verdict("evaluate met/unmet mix preserves order", evidence.evaluate(criteria, items), contract.PartiallyFulfilled(["bond", "insurance"]))
}

fn main() -> [io] Unit {
  let r1 := verify_find_evidence_found()
  let r2 := verify_find_evidence_not_found_empty()
  let r3 := verify_find_evidence_not_found_nonempty()
  let r4 := verify_evaluate_empty_criteria()
  let r5 := verify_evaluate_all_unassessed()
  let r6 := verify_evaluate_unassessed_wins_over_unmet()
  let r7 := verify_evaluate_all_met()
  let r8 := verify_evaluate_all_unmet()
  let r9 := verify_evaluate_met_unmet_mix()
  let all_pass := r1 and r2 and r3 and r4 and r5 and r6 and r7 and r8 and r9
  if all_pass {
    io.print("ALL CHECKS PASSED")
  } else {
    io.print("SOME CHECKS FAILED")
  }
}

