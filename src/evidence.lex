import "./contract" as contract

import "./request_bid" as request_bid

import "std.list" as list

type EvidenceItem = { attr :: Str, satisfied :: Bool, note :: Str }

fn find_evidence(evidence :: List[EvidenceItem], attr :: Str) -> Option[EvidenceItem]
  examples {
    find_evidence([{ attr: "license", satisfied: true, note: "valid" }, { attr: "insurance", satisfied: false, note: "expired" }], "insurance") => Some({ attr: "insurance", satisfied: false, note: "expired" }),
    find_evidence([], "license") => None,
    find_evidence([{ attr: "license", satisfied: true, note: "valid" }], "insurance") => None
  }
{
  match list.head(evidence) {
    None => None,
    Some(item) => if item.attr == attr {
      Some(item)
    } else {
      find_evidence(list.tail(evidence), attr)
    },
  }
}

fn evaluate(criteria :: List[request_bid.Criterion], evidence :: List[EvidenceItem]) -> contract.Verdict
  examples {
    evaluate([], []) => contract.Fulfilled,
    evaluate([{ attr: "license", description: "must be licensed" }, { attr: "insurance", description: "must be insured" }], []) => contract.Ambiguous(["license", "insurance"]),
    evaluate([{ attr: "license", description: "must be licensed" }, { attr: "insurance", description: "must be insured" }], [{ attr: "license", satisfied: false, note: "missing" }]) => contract.Ambiguous(["insurance"]),
    evaluate([{ attr: "license", description: "must be licensed" }, { attr: "insurance", description: "must be insured" }], [{ attr: "license", satisfied: true, note: "valid" }, { attr: "insurance", satisfied: true, note: "valid" }]) => contract.Fulfilled,
    evaluate([{ attr: "license", description: "must be licensed" }, { attr: "insurance", description: "must be insured" }], [{ attr: "license", satisfied: false, note: "missing" }, { attr: "insurance", satisfied: false, note: "missing" }]) => contract.Rejected(["license", "insurance"]),
    evaluate([{ attr: "license", description: "must be licensed" }, { attr: "insurance", description: "must be insured" }, { attr: "bond", description: "must be bonded" }], [{ attr: "license", satisfied: true, note: "valid" }, { attr: "insurance", satisfied: false, note: "expired" }, { attr: "bond", satisfied: true, note: "valid" }]) => contract.PartiallyFulfilled(["insurance"])
  }
{
  evaluate_rec(criteria, evidence, [], [], [])
}

fn evaluate_rec(criteria :: List[request_bid.Criterion], evidence :: List[EvidenceItem], unassessed_acc :: List[Str], met_acc :: List[Str], unmet_acc :: List[Str]) -> contract.Verdict {
  match list.head(criteria) {
    None => decide_verdict(list.reverse(unassessed_acc), list.reverse(met_acc), list.reverse(unmet_acc)),
    Some(criterion) => match find_evidence(evidence, criterion.attr) {
      None => evaluate_rec(list.tail(criteria), evidence, list.cons(criterion.attr, unassessed_acc), met_acc, unmet_acc),
      Some(item) => if item.satisfied {
        evaluate_rec(list.tail(criteria), evidence, unassessed_acc, list.cons(criterion.attr, met_acc), unmet_acc)
      } else {
        evaluate_rec(list.tail(criteria), evidence, unassessed_acc, met_acc, list.cons(criterion.attr, unmet_acc))
      },
    },
  }
}

fn decide_verdict(unassessed :: List[Str], met :: List[Str], unmet :: List[Str]) -> contract.Verdict {
  if list.is_empty(unassessed) and list.is_empty(met) and list.is_empty(unmet) {
    contract.Fulfilled
  } else {
    if list.is_empty(unassessed) {
      if list.is_empty(unmet) {
        contract.Fulfilled
      } else {
        if list.is_empty(met) {
          contract.Rejected(unmet)
        } else {
          contract.PartiallyFulfilled(unmet)
        }
      }
    } else {
      contract.Ambiguous(unassessed)
    }
  }
}

