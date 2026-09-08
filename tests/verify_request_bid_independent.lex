import "../src/request_bid" as rb
import "../src/contract" as contract
import "std.io" as io
import "std.str" as str
import "std.list" as list

fn usd(cents :: Int) -> contract.Money {
  { cents: cents, currency: "USD" }
}

fn eur(cents :: Int) -> contract.Money {
  { cents: cents, currency: "EUR" }
}

fn make_request(state :: rb.RequestState) -> rb.WorkRequest {
  {
    id: "r-1",
    buyer: "buyer-a",
    capability: "haul",
    description: "haul gravel",
    budget_ceiling: usd(50000),
    criteria: [{ attr: "weight", description: "max load" }],
    deadline_ms: 1000,
    state: state,
  }
}

fn make_bid(id :: Str, request_id :: Str, state :: rb.BidState, cents :: Int) -> rb.Bid {
  {
    id: id,
    request_id: request_id,
    supplier: str.concat("supplier-", id),
    price: usd(cents),
    message: "bid",
    state: state,
  }
}

fn check_bool(name :: Str, got :: Bool, want :: Bool) -> [io] Bool {
  if got == want {
    io.print("OK")
    io.print(name)
    true
  } else {
    io.print("FAIL")
    io.print(name)
    false
  }
}

fn check_str(name :: Str, got :: Str, want :: Str) -> [io] Bool {
  if got == want {
    io.print("OK")
    io.print(name)
    true
  } else {
    io.print("FAIL")
    io.print(name)
    io.print(str.concat("got=", got))
    io.print(str.concat("want=", want))
    false
  }
}

fn criterion_matches(got :: rb.Criterion, want :: rb.Criterion) -> Bool {
  got.attr == want.attr and got.description == want.description
}

fn request_matches(got :: rb.WorkRequest, want :: rb.WorkRequest) -> Bool {
  got.id == want.id and
  got.buyer == want.buyer and
  got.capability == want.capability and
  got.description == want.description and
  got.budget_ceiling.cents == want.budget_ceiling.cents and
  got.budget_ceiling.currency == want.budget_ceiling.currency and
  list.len(got.criteria) == list.len(want.criteria) and
  got.deadline_ms == want.deadline_ms and
  got.state == want.state
}

fn bid_matches(got :: rb.Bid, want :: rb.Bid) -> Bool {
  got.id == want.id and
  got.request_id == want.request_id and
  got.supplier == want.supplier and
  got.price.cents == want.price.cents and
  got.price.currency == want.price.currency and
  got.message == want.message and
  got.state == want.state
}

fn find_bid_state(bids :: List[rb.Bid], id :: Str) -> rb.BidState {
  match list.head(bids) {
    None => rb.BidRejected,
    Some(b) => if b.id == id {
      b.state
    } else {
      find_bid_state(list.tail(bids), id)
    },
  }
}

fn verify_post_request() -> [io] Bool {
  let req := rb.post_request(
    "r-1",
    "buyer-a",
    "haul",
    "haul gravel",
    usd(50000),
    [{ attr: "weight", description: "max load" }],
    1000,
  )
  let want := make_request(rb.ReqOpen)
  check_bool("post_request fields and ReqOpen state", request_matches(req, want), true)
}

fn verify_submit_bid_success() -> [io] Bool {
  let req := make_request(rb.ReqOpen)
  match rb.submit_bid(req, "b-1", "supplier-s", usd(40000), "we can do this", 500) {
    Ok(bid) => {
      let want := {
        id: "b-1",
        request_id: "r-1",
        supplier: "supplier-s",
        price: usd(40000),
        message: "we can do this",
        state: rb.BidSubmitted,
      }
      check_bool("submit_bid success", bid_matches(bid, want), true)
    },
    Err(msg) => {
      io.print("FAIL submit_bid success unexpected Err")
      io.print(msg)
      false
    },
  }
}

fn verify_submit_bid_request_not_open() -> [io] Bool {
  let req := make_request(rb.ReqAwarded)
  match rb.submit_bid(req, "b-1", "supplier-s", usd(40000), "bid", 500) {
    Err("request_not_open") => check_bool("submit_bid request_not_open", true, true),
    Err(msg) => check_str("submit_bid request_not_open", msg, "request_not_open"),
    Ok(_) => check_bool("submit_bid request_not_open", false, true),
  }
}

fn verify_submit_bid_deadline_passed() -> [io] Bool {
  let req := make_request(rb.ReqOpen)
  match rb.submit_bid(req, "b-1", "supplier-s", usd(40000), "bid", 1001) {
    Err("deadline_passed") => check_bool("submit_bid deadline_passed", true, true),
    Err(msg) => check_str("submit_bid deadline_passed", msg, "deadline_passed"),
    Ok(_) => check_bool("submit_bid deadline_passed", false, true),
  }
}

fn verify_submit_bid_currency_mismatch() -> [io] Bool {
  let req := make_request(rb.ReqOpen)
  match rb.submit_bid(req, "b-1", "supplier-s", eur(40000), "bid", 500) {
    Err("currency_mismatch") => check_bool("submit_bid currency_mismatch", true, true),
    Err(msg) => check_str("submit_bid currency_mismatch", msg, "currency_mismatch"),
    Ok(_) => check_bool("submit_bid currency_mismatch", false, true),
  }
}

fn verify_submit_bid_over_budget() -> [io] Bool {
  let req := make_request(rb.ReqOpen)
  match rb.submit_bid(req, "b-1", "supplier-s", usd(50001), "bid", 500) {
    Err("over_budget") => check_bool("submit_bid over_budget", true, true),
    Err(msg) => check_str("submit_bid over_budget", msg, "over_budget"),
    Ok(_) => check_bool("submit_bid over_budget", false, true),
  }
}

fn verify_submit_bid_exact_budget() -> [io] Bool {
  let req := make_request(rb.ReqOpen)
  match rb.submit_bid(req, "b-1", "supplier-s", usd(50000), "bid", 500) {
    Ok(bid) => check_bool("submit_bid exact budget allowed", bid.price.cents == 50000 and bid.state == rb.BidSubmitted, true),
    Err(_) => check_bool("submit_bid exact budget allowed", false, true),
  }
}

fn verify_withdraw_bid_success() -> [io] Bool {
  let bid := make_bid("b-1", "r-1", rb.BidSubmitted, 40000)
  match rb.withdraw_bid(bid) {
    Ok(updated) => check_bool("withdraw_bid success", updated.state == rb.BidWithdrawn and updated.id == "b-1", true),
    Err(_) => check_bool("withdraw_bid success", false, true),
  }
}

fn verify_withdraw_bid_double_withdrawal() -> [io] Bool {
  let bid := make_bid("b-1", "r-1", rb.BidWithdrawn, 40000)
  match rb.withdraw_bid(bid) {
    Err("not_submitted") => check_bool("withdraw_bid double withdrawal", true, true),
    Err(msg) => check_str("withdraw_bid double withdrawal", msg, "not_submitted"),
    Ok(_) => check_bool("withdraw_bid double withdrawal", false, true),
  }
}

fn verify_withdraw_bid_not_submitted() -> [io] Bool {
  let bid := make_bid("b-1", "r-1", rb.BidAccepted, 40000)
  match rb.withdraw_bid(bid) {
    Err("not_submitted") => check_bool("withdraw_bid accepted rejected", true, true),
    Err(msg) => check_str("withdraw_bid accepted rejected", msg, "not_submitted"),
    Ok(_) => check_bool("withdraw_bid accepted rejected", false, true),
  }
}

fn verify_award_success() -> [io] Bool {
  let req := make_request(rb.ReqOpen)
  let bids := [
    make_bid("b-1", "r-1", rb.BidSubmitted, 40000),
    make_bid("b-2", "r-1", rb.BidSubmitted, 42000),
    make_bid("b-3", "r-2", rb.BidSubmitted, 30000),
    make_bid("b-4", "r-1", rb.BidWithdrawn, 41000),
  ]
  match rb.award(req, bids, "b-1") {
    Ok((awarded_req, updated_bids)) => {
      let r1 := check_bool("award success request state", awarded_req.state == rb.ReqAwarded, true)
      let r2 := check_bool("award success winner accepted", find_bid_state(updated_bids, "b-1") == rb.BidAccepted, true)
      let r3 := check_bool("award success competitor rejected", find_bid_state(updated_bids, "b-2") == rb.BidRejected, true)
      let r4 := check_bool("award success other request untouched", find_bid_state(updated_bids, "b-3") == rb.BidSubmitted, true)
      let r5 := check_bool("award success withdrawn untouched", find_bid_state(updated_bids, "b-4") == rb.BidWithdrawn, true)
      let r6 := check_bool("award success list length preserved", list.len(updated_bids) == 4, true)
      r1 and r2 and r3 and r4 and r5 and r6
    },
    Err(msg) => {
      io.print("FAIL award success unexpected Err")
      io.print(msg)
      false
    },
  }
}

fn verify_award_request_not_open() -> [io] Bool {
  let req := make_request(rb.ReqAwarded)
  let bids := [make_bid("b-1", "r-1", rb.BidSubmitted, 40000)]
  match rb.award(req, bids, "b-1") {
    Err("request_not_open") => check_bool("award request_not_open", true, true),
    Err(msg) => check_str("award request_not_open", msg, "request_not_open"),
    Ok(_) => check_bool("award request_not_open", false, true),
  }
}

fn verify_award_invalid_bid() -> [io] Bool {
  let req := make_request(rb.ReqOpen)
  let bids := [make_bid("b-1", "r-1", rb.BidSubmitted, 40000)]
  match rb.award(req, bids, "b-2") {
    Err("invalid_bid") => check_bool("award invalid_bid", true, true),
    Err(msg) => check_str("award invalid_bid", msg, "invalid_bid"),
    Ok(_) => check_bool("award invalid_bid", false, true),
  }
}

fn verify_award_bid_request_mismatch() -> [io] Bool {
  let req := make_request(rb.ReqOpen)
  let bids := [make_bid("b-1", "r-2", rb.BidSubmitted, 40000)]
  match rb.award(req, bids, "b-1") {
    Err("bid_request_mismatch") => check_bool("award bid_request_mismatch", true, true),
    Err(msg) => check_str("award bid_request_mismatch", msg, "bid_request_mismatch"),
    Ok(_) => check_bool("award bid_request_mismatch", false, true),
  }
}

fn verify_award_withdrawn_winner_is_invalid() -> [io] Bool {
  let req := make_request(rb.ReqOpen)
  let bids := [make_bid("b-1", "r-1", rb.BidWithdrawn, 40000)]
  match rb.award(req, bids, "b-1") {
    Err("invalid_bid") => check_bool("award withdrawn winner invalid", true, true),
    Err(msg) => check_str("award withdrawn winner invalid", msg, "invalid_bid"),
    Ok(_) => check_bool("award withdrawn winner invalid", false, true),
  }
}

fn verify_cancel_request_success() -> [io] Bool {
  let req := make_request(rb.ReqOpen)
  match rb.cancel_request(req) {
    Ok(updated) => check_bool("cancel_request success", updated.state == rb.ReqCancelled and updated.id == "r-1", true),
    Err(_) => check_bool("cancel_request success", false, true),
  }
}

fn verify_cancel_request_not_open() -> [io] Bool {
  let req := make_request(rb.ReqCancelled)
  match rb.cancel_request(req) {
    Err("request_not_open") => check_bool("cancel_request not_open", true, true),
    Err(msg) => check_str("cancel_request not_open", msg, "request_not_open"),
    Ok(_) => check_bool("cancel_request not_open", false, true),
  }
}

fn verify_cancel_request_awarded_rejected() -> [io] Bool {
  let req := make_request(rb.ReqAwarded)
  match rb.cancel_request(req) {
    Err("request_not_open") => check_bool("cancel_request awarded rejected", true, true),
    Err(msg) => check_str("cancel_request awarded rejected", msg, "request_not_open"),
    Ok(_) => check_bool("cancel_request awarded rejected", false, true),
  }
}

fn verify_cancel_request_expired_rejected() -> [io] Bool {
  let req := make_request(rb.ReqExpired)
  match rb.cancel_request(req) {
    Err("request_not_open") => check_bool("cancel_request expired rejected", true, true),
    Err(msg) => check_str("cancel_request expired rejected", msg, "request_not_open"),
    Ok(_) => check_bool("cancel_request expired rejected", false, true),
  }
}

fn verify_is_terminal() -> [io] Bool {
  let r1 := check_bool("is_terminal ReqOpen false", rb.is_terminal(make_request(rb.ReqOpen)), false)
  let r2 := check_bool("is_terminal ReqAwarded true", rb.is_terminal(make_request(rb.ReqAwarded)), true)
  let r3 := check_bool("is_terminal ReqCancelled true", rb.is_terminal(make_request(rb.ReqCancelled)), true)
  let r4 := check_bool("is_terminal ReqExpired true", rb.is_terminal(make_request(rb.ReqExpired)), true)
  r1 and r2 and r3 and r4
}

fn verify_reuses_contract_money() -> [io] Bool {
  # This is a structural check: the module imports contract and uses contract.Money.
  # If it compiled, the type is contract.Money. We additionally verify the money fields behave as ints.
  let req := make_request(rb.ReqOpen)
  check_bool("reuses contract.Money", req.budget_ceiling.cents == 50000 and req.budget_ceiling.currency == "USD", true)
}

fn main() -> [io] Unit {
  let r1 := verify_post_request()
  let r2 := verify_submit_bid_success()
  let r3 := verify_submit_bid_request_not_open()
  let r4 := verify_submit_bid_deadline_passed()
  let r5 := verify_submit_bid_currency_mismatch()
  let r6 := verify_submit_bid_over_budget()
  let r7 := verify_submit_bid_exact_budget()
  let r8 := verify_withdraw_bid_success()
  let r9 := verify_withdraw_bid_double_withdrawal()
  let r10 := verify_withdraw_bid_not_submitted()
  let r11 := verify_award_success()
  let r12 := verify_award_request_not_open()
  let r13 := verify_award_invalid_bid()
  let r14 := verify_award_bid_request_mismatch()
  let r15 := verify_award_withdrawn_winner_is_invalid()
  let r16 := verify_cancel_request_success()
  let r17 := verify_cancel_request_not_open()
  let r18 := verify_cancel_request_awarded_rejected()
  let r19 := verify_cancel_request_expired_rejected()
  let r20 := verify_is_terminal()
  let r21 := verify_reuses_contract_money()
  if r1 and r2 and r3 and r4 and r5 and r6 and r7 and r8 and r9 and r10 and r11 and r12 and r13 and r14 and r15 and r16 and r17 and r18 and r19 and r20 and r21 {
    io.print("ALL CHECKS PASSED")
  } else {
    io.print("SOME CHECKS FAILED")
  }
}
