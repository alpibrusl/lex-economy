import "./contract" as contract

import "./treasury" as treasury

import "./request_bid" as request_bid

import "lex-trail/log" as tlog

import "std.json" as json

import "std.str" as str

fn open_contract(db :: Db, log :: tlog.Log, request :: request_bid.WorkRequest, bid :: request_bid.Bid, contract_id :: Str, commitment_id :: Str) -> [sql, time] Result[contract.Contract, Str] {
  if bid.state != request_bid.BidAccepted {
    Err("bid_not_accepted")
  } else {
    if bid.request_id != request.id {
      Err("bid_request_mismatch")
    } else {
      match treasury.commit_funds(db, log, request.buyer, request.id, commitment_id, bid.price.cents, bid.price.currency) {
        Err(e) => Err(e),
        Ok(_) => Ok({ id: contract_id, buyer: request.buyer, supplier: bid.supplier, price: bid.price, state: contract.Awarded }),
      }
    }
  }
}

fn settle_contract(db :: Db, log :: tlog.Log, c :: contract.Contract, commitment_id :: Str, paid_cents :: Int) -> [sql, time] Result[contract.Contract, Str] {
  match c.state {
    Verified(verdict) => match verdict {
      Fulfilled => settle_paying(db, log, c, commitment_id, paid_cents),
      PartiallyFulfilled(_) => settle_paying(db, log, c, commitment_id, paid_cents),
      Rejected(_) => if paid_cents != 0 {
        Err("rejected_verdict_cannot_pay")
      } else {
        match treasury.release_commitment(db, log, commitment_id) {
          Err(e) => Err(e),
          Ok(_) => match contract.transition(c, contract.WasDisputed) {
            Err(e) => Err(e),
            Ok(disputed) => match tlog.append(log, "contract_failed", None, failed_payload(disputed.supplier)) {
              Err(e) => Err(e),
              Ok(_) => Ok(disputed),
            },
          },
        }
      },
      Ambiguous(_) => Err("ambiguous_verdict_needs_arbitration"),
    },
    _ => Err("not_verified"),
  }
}

fn settle_paying(db :: Db, log :: tlog.Log, c :: contract.Contract, commitment_id :: Str, paid_cents :: Int) -> [sql, time] Result[contract.Contract, Str] {
  match treasury.settle_commitment(db, log, commitment_id, paid_cents, c.supplier) {
    Err(e) => Err(e),
    Ok(_) => match contract.transition(c, contract.WasSettled) {
      Err(e) => Err(e),
      Ok(settled) => match tlog.append(log, "contract_settled", None, settled_payload(settled.supplier)) {
        Err(e) => Err(e),
        Ok(_) => Ok(settled),
      },
    },
  }
}

fn settled_payload(supplier :: Str) -> Str {
  str.concat("{", str.concat(str.concat(json.stringify("company"), ":"), str.concat(json.stringify(supplier), "}")))
}

fn failed_payload(supplier :: Str) -> Str {
  str.concat("{", str.concat(str.concat(json.stringify("company"), ":"), str.concat(json.stringify(supplier), "}")))
}

