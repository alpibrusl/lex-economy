import "../src/evidence" as evidence

import "../src/contract" as contract

import "../src/request_bid" as request_bid

import "std.list" as list

fn evidence_item(attr :: Str, satisfied :: Bool, note :: Str) -> evidence.EvidenceItem {
  { attr: attr, satisfied: satisfied, note: note }
}

fn criterion(attr :: Str, description :: Str) -> request_bid.Criterion {
  { attr: attr, description: description }
}

fn test_find_evidence_found_first_match() -> Bool
  examples {
    test_find_evidence_found_first_match() => true
  }
{
  let items :: List[evidence.EvidenceItem] := [evidence_item("license", true, "valid"), evidence_item("insurance", false, "expired")]
  evidence.find_evidence(items, "license") == Some(evidence_item("license", true, "valid"))
}

fn test_find_evidence_found_later_match() -> Bool
  examples {
    test_find_evidence_found_later_match() => true
  }
{
  let items :: List[evidence.EvidenceItem] := [evidence_item("license", true, "valid"), evidence_item("insurance", false, "expired")]
  evidence.find_evidence(items, "insurance") == Some(evidence_item("insurance", false, "expired"))
}

fn test_find_evidence_not_found_empty() -> Bool
  examples {
    test_find_evidence_not_found_empty() => true
  }
{
  evidence.find_evidence([], "license") == None
}

fn test_find_evidence_not_found_nonempty() -> Bool
  examples {
    test_find_evidence_not_found_nonempty() => true
  }
{
  let items :: List[evidence.EvidenceItem] := [evidence_item("license", true, "valid")]
  evidence.find_evidence(items, "insurance") == None
}

fn test_find_evidence_first_match_wins() -> Bool
  examples {
    test_find_evidence_first_match_wins() => true
  }
{
  let items :: List[evidence.EvidenceItem] := [evidence_item("license", false, "first"), evidence_item("license", true, "second")]
  evidence.find_evidence(items, "license") == Some(evidence_item("license", false, "first"))
}

fn test_find_evidence_satisfied_true() -> Bool
  examples {
    test_find_evidence_satisfied_true() => true
  }
{
  let items :: List[evidence.EvidenceItem] := [evidence_item("bond", true, "posted")]
  evidence.find_evidence(items, "bond") == Some(evidence_item("bond", true, "posted"))
}

fn test_evaluate_empty_criteria() -> Bool
  examples {
    test_evaluate_empty_criteria() => true
  }
{
  evidence.evaluate([], []) == contract.Fulfilled
}

fn test_evaluate_all_unassessed() -> Bool
  examples {
    test_evaluate_all_unassessed() => true
  }
{
  let criteria :: List[request_bid.Criterion] := [criterion("license", "must be licensed"), criterion("insurance", "must be insured")]
  evidence.evaluate(criteria, []) == contract.Ambiguous(["license", "insurance"])
}

fn test_evaluate_unassessed_wins_over_unmet() -> Bool
  examples {
    test_evaluate_unassessed_wins_over_unmet() => true
  }
{
  let criteria :: List[request_bid.Criterion] := [criterion("license", "must be licensed"), criterion("insurance", "must be insured")]
  let evidence_items :: List[evidence.EvidenceItem] := [evidence_item("license", false, "missing")]
  evidence.evaluate(criteria, evidence_items) == contract.Ambiguous(["insurance"])
}

fn test_evaluate_all_met() -> Bool
  examples {
    test_evaluate_all_met() => true
  }
{
  let criteria :: List[request_bid.Criterion] := [criterion("license", "must be licensed"), criterion("insurance", "must be insured")]
  let evidence_items :: List[evidence.EvidenceItem] := [evidence_item("license", true, "valid"), evidence_item("insurance", true, "valid")]
  evidence.evaluate(criteria, evidence_items) == contract.Fulfilled
}

fn test_evaluate_all_unmet() -> Bool
  examples {
    test_evaluate_all_unmet() => true
  }
{
  let criteria :: List[request_bid.Criterion] := [criterion("license", "must be licensed"), criterion("insurance", "must be insured")]
  let evidence_items :: List[evidence.EvidenceItem] := [evidence_item("license", false, "missing"), evidence_item("insurance", false, "missing")]
  evidence.evaluate(criteria, evidence_items) == contract.Rejected(["license", "insurance"])
}

fn test_evaluate_met_unmet_mix() -> Bool
  examples {
    test_evaluate_met_unmet_mix() => true
  }
{
  let criteria :: List[request_bid.Criterion] := [criterion("license", "must be licensed"), criterion("insurance", "must be insured"), criterion("bond", "must be bonded")]
  let evidence_items :: List[evidence.EvidenceItem] := [evidence_item("license", true, "valid"), evidence_item("insurance", false, "expired"), evidence_item("bond", true, "valid")]
  evidence.evaluate(criteria, evidence_items) == contract.PartiallyFulfilled(["insurance"])
}

fn test_evaluate_partially_fulfilled_preserves_order() -> Bool
  examples {
    test_evaluate_partially_fulfilled_preserves_order() => true
  }
{
  let criteria :: List[request_bid.Criterion] := [criterion("bond", "must be bonded"), criterion("license", "must be licensed"), criterion("insurance", "must be insured")]
  let evidence_items :: List[evidence.EvidenceItem] := [evidence_item("bond", false, "missing"), evidence_item("license", true, "valid"), evidence_item("insurance", false, "expired")]
  evidence.evaluate(criteria, evidence_items) == contract.PartiallyFulfilled(["bond", "insurance"])
}

fn test_evaluate_extra_evidence_ignored() -> Bool
  examples {
    test_evaluate_extra_evidence_ignored() => true
  }
{
  let criteria :: List[request_bid.Criterion] := [criterion("license", "must be licensed")]
  let evidence_items :: List[evidence.EvidenceItem] := [evidence_item("insurance", false, "ignored"), evidence_item("license", true, "valid"), evidence_item("bond", false, "ignored")]
  evidence.evaluate(criteria, evidence_items) == contract.Fulfilled
}

fn test_evaluate_single_met() -> Bool
  examples {
    test_evaluate_single_met() => true
  }
{
  let criteria :: List[request_bid.Criterion] := [criterion("license", "must be licensed")]
  let evidence_items :: List[evidence.EvidenceItem] := [evidence_item("license", true, "valid")]
  evidence.evaluate(criteria, evidence_items) == contract.Fulfilled
}

fn test_evaluate_single_unmet() -> Bool
  examples {
    test_evaluate_single_unmet() => true
  }
{
  let criteria :: List[request_bid.Criterion] := [criterion("license", "must be licensed")]
  let evidence_items :: List[evidence.EvidenceItem] := [evidence_item("license", false, "missing")]
  evidence.evaluate(criteria, evidence_items) == contract.Rejected(["license"])
}

fn test_evaluate_single_unassessed() -> Bool
  examples {
    test_evaluate_single_unassessed() => true
  }
{
  let criteria :: List[request_bid.Criterion] := [criterion("license", "must be licensed")]
  evidence.evaluate(criteria, []) == contract.Ambiguous(["license"])
}

fn run_all() -> Bool {
  test_find_evidence_found_first_match() and test_find_evidence_found_later_match() and test_find_evidence_not_found_empty() and test_find_evidence_not_found_nonempty() and test_find_evidence_first_match_wins() and test_find_evidence_satisfied_true() and test_evaluate_empty_criteria() and test_evaluate_all_unassessed() and test_evaluate_unassessed_wins_over_unmet() and test_evaluate_all_met() and test_evaluate_all_unmet() and test_evaluate_met_unmet_mix() and test_evaluate_partially_fulfilled_preserves_order() and test_evaluate_extra_evidence_ignored() and test_evaluate_single_met() and test_evaluate_single_unmet() and test_evaluate_single_unassessed()
}

