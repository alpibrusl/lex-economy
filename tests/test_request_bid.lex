import "../src/request_bid" as rb

import "../src/contract" as contract

import "std.str" as str

import "std.list" as list

fn base_request(state :: rb.RequestState) -> rb.WorkRequest {
  { id: "r-1", buyer: "buyer-a", capability: "haul", description: "haul gravel", budget_ceiling: { cents: 50000, currency: "USD" }, criteria: [], deadline_ms: 1000, state: state }
}

fn base_bid(id :: Str, request_id :: Str, state :: rb.BidState, cents :: Int) -> rb.Bid {
  { id: id, request_id: request_id, supplier: str.concat("supplier-", id), price: { cents: cents, currency: "USD" }, message: "bid", state: state }
}

fn test_post_request_initial_state() -> Bool
  examples {
    test_post_request_initial_state() => true
  }
{
  let req := rb.post_request("r-1", "buyer-a", "haul", "haul gravel", { cents: 50000, currency: "USD" }, [{ attr: "weight", description: "max load" }], 1000)
  req.id == "r-1" and req.buyer == "buyer-a" and req.capability == "haul" and req.description == "haul gravel" and req.budget_ceiling.cents == 50000 and req.budget_ceiling.currency == "USD" and req.deadline_ms == 1000 and req.state == rb.ReqOpen
}

fn test_submit_bid_success() -> Bool
  examples {
    test_submit_bid_success() => true
  }
{
  let req := base_request(rb.ReqOpen)
  match rb.submit_bid(req, "b-1", "supplier-s", { cents: 40000, currency: "USD" }, "bid", 500) {
    Ok(bid) => bid.id == "b-1" and bid.request_id == "r-1" and bid.supplier == "supplier-s" and bid.price.cents == 40000 and bid.price.currency == "USD" and bid.message == "bid" and bid.state == rb.BidSubmitted,
    Err(_) => false,
  }
}

fn test_submit_bid_request_not_open() -> Bool
  examples {
    test_submit_bid_request_not_open() => true
  }
{
  match rb.submit_bid(base_request(rb.ReqAwarded), "b-1", "supplier-s", { cents: 40000, currency: "USD" }, "bid", 500) {
    Ok(_) => false,
    Err(e) => e == "request_not_open",
  }
}

fn test_submit_bid_deadline_passed() -> Bool
  examples {
    test_submit_bid_deadline_passed() => true
  }
{
  match rb.submit_bid(base_request(rb.ReqOpen), "b-1", "supplier-s", { cents: 40000, currency: "USD" }, "bid", 1500) {
    Ok(_) => false,
    Err(e) => e == "deadline_passed",
  }
}

fn test_submit_bid_currency_mismatch() -> Bool
  examples {
    test_submit_bid_currency_mismatch() => true
  }
{
  match rb.submit_bid(base_request(rb.ReqOpen), "b-1", "supplier-s", { cents: 40000, currency: "EUR" }, "bid", 500) {
    Ok(_) => false,
    Err(e) => e == "currency_mismatch",
  }
}

fn test_submit_bid_over_budget() -> Bool
  examples {
    test_submit_bid_over_budget() => true
  }
{
  match rb.submit_bid(base_request(rb.ReqOpen), "b-1", "supplier-s", { cents: 60000, currency: "USD" }, "bid", 500) {
    Ok(_) => false,
    Err(e) => e == "over_budget",
  }
}

fn test_withdraw_bid_success() -> Bool
  examples {
    test_withdraw_bid_success() => true
  }
{
  let bid := base_bid("b-1", "r-1", rb.BidSubmitted, 40000)
  match rb.withdraw_bid(bid) {
    Ok(b) => b.state == rb.BidWithdrawn and b.id == "b-1" and b.request_id == "r-1",
    Err(_) => false,
  }
}

fn test_withdraw_bid_double_withdrawal_rejected() -> Bool
  examples {
    test_withdraw_bid_double_withdrawal_rejected() => true
  }
{
  let bid := base_bid("b-1", "r-1", rb.BidWithdrawn, 40000)
  match rb.withdraw_bid(bid) {
    Ok(_) => false,
    Err(e) => e == "not_submitted",
  }
}

fn test_award_success() -> Bool
  examples {
    test_award_success() => true
  }
{
  let req := base_request(rb.ReqOpen)
  let bids := [base_bid("b-1", "r-1", rb.BidSubmitted, 40000), base_bid("b-2", "r-1", rb.BidSubmitted, 42000), base_bid("b-3", "r-2", rb.BidSubmitted, 30000), base_bid("b-4", "r-1", rb.BidWithdrawn, 41000)]
  match rb.award(req, bids, "b-1") {
    Ok((awarded_req, updated_bids)) => {
      awarded_req.state == rb.ReqAwarded and list.len(updated_bids) == 4 and bid_state(updated_bids, "b-1") == rb.BidAccepted and bid_state(updated_bids, "b-2") == rb.BidRejected and bid_state(updated_bids, "b-3") == rb.BidSubmitted and bid_state(updated_bids, "b-4") == rb.BidWithdrawn
    },
    Err(_) => false,
  }
}

fn bid_state(bids :: List[rb.Bid], id :: Str) -> rb.BidState {
  match list.head(bids) {
    None => rb.BidRejected,
    Some(b) => if b.id == id {
      b.state
    } else {
      bid_state(list.tail(bids), id)
    },
  }
}

fn test_award_request_not_open() -> Bool
  examples {
    test_award_request_not_open() => true
  }
{
  let req := base_request(rb.ReqAwarded)
  let bids := [base_bid("b-1", "r-1", rb.BidSubmitted, 40000)]
  match rb.award(req, bids, "b-1") {
    Ok(_) => false,
    Err(e) => e == "request_not_open",
  }
}

fn test_award_invalid_bid() -> Bool
  examples {
    test_award_invalid_bid() => true
  }
{
  let req := base_request(rb.ReqOpen)
  let bids := [base_bid("b-1", "r-1", rb.BidSubmitted, 40000)]
  match rb.award(req, bids, "b-2") {
    Ok(_) => false,
    Err(e) => e == "invalid_bid",
  }
}

fn test_award_bid_request_mismatch() -> Bool
  examples {
    test_award_bid_request_mismatch() => true
  }
{
  let req := base_request(rb.ReqOpen)
  let bids := [base_bid("b-1", "r-2", rb.BidSubmitted, 40000)]
  match rb.award(req, bids, "b-1") {
    Ok(_) => false,
    Err(e) => e == "bid_request_mismatch",
  }
}

fn test_cancel_request_success() -> Bool
  examples {
    test_cancel_request_success() => true
  }
{
  match rb.cancel_request(base_request(rb.ReqOpen)) {
    Ok(req) => req.state == rb.ReqCancelled and req.id == "r-1",
    Err(_) => false,
  }
}

fn test_cancel_request_not_open() -> Bool
  examples {
    test_cancel_request_not_open() => true
  }
{
  match rb.cancel_request(base_request(rb.ReqCancelled)) {
    Ok(_) => false,
    Err(e) => e == "request_not_open",
  }
}

fn test_is_terminal_open() -> Bool
  examples {
    test_is_terminal_open() => true
  }
{
  not rb.is_terminal(base_request(rb.ReqOpen))
}

fn test_is_terminal_awarded() -> Bool
  examples {
    test_is_terminal_awarded() => true
  }
{
  rb.is_terminal(base_request(rb.ReqAwarded))
}

fn test_is_terminal_cancelled() -> Bool
  examples {
    test_is_terminal_cancelled() => true
  }
{
  rb.is_terminal(base_request(rb.ReqCancelled))
}

fn test_is_terminal_expired() -> Bool
  examples {
    test_is_terminal_expired() => true
  }
{
  rb.is_terminal(base_request(rb.ReqExpired))
}

fn run_all() -> Bool {
  test_post_request_initial_state() and test_submit_bid_success() and test_submit_bid_request_not_open() and test_submit_bid_deadline_passed() and test_submit_bid_currency_mismatch() and test_submit_bid_over_budget() and test_withdraw_bid_success() and test_withdraw_bid_double_withdrawal_rejected() and test_award_success() and test_award_request_not_open() and test_award_invalid_bid() and test_award_bid_request_mismatch() and test_cancel_request_success() and test_cancel_request_not_open() and test_is_terminal_open() and test_is_terminal_awarded() and test_is_terminal_cancelled() and test_is_terminal_expired()
}

