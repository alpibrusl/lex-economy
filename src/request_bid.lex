import "./contract" as contract

import "std.list" as list

type Criterion = { attr :: Str, description :: Str }

type RequestState = ReqOpen | ReqAwarded | ReqCancelled | ReqExpired

type WorkRequest = { id :: Str, buyer :: Str, capability :: Str, description :: Str, budget_ceiling :: contract.Money, criteria :: List[Criterion], deadline_ms :: Int, state :: RequestState }

type BidState = BidSubmitted | BidWithdrawn | BidAccepted | BidRejected

type Bid = { id :: Str, request_id :: Str, supplier :: Str, price :: contract.Money, message :: Str, state :: BidState }

fn post_request(id :: Str, buyer :: Str, capability :: Str, description :: Str, budget_ceiling :: contract.Money, criteria :: List[Criterion], deadline_ms :: Int) -> WorkRequest
  examples {
    post_request("req-1", "buyer-a", "plumbing", "fix leaky sink", { cents: 50000, currency: "USD" }, [{ attr: "license", description: "must be licensed" }], 1000) => { id: "req-1", buyer: "buyer-a", capability: "plumbing", description: "fix leaky sink", budget_ceiling: { cents: 50000, currency: "USD" }, criteria: [{ attr: "license", description: "must be licensed" }], deadline_ms: 1000, state: ReqOpen }
  }
{
  { id: id, buyer: buyer, capability: capability, description: description, budget_ceiling: budget_ceiling, criteria: criteria, deadline_ms: deadline_ms, state: ReqOpen }
}

fn submit_bid(request :: WorkRequest, bid_id :: Str, supplier :: Str, price :: contract.Money, message :: Str, now_ms :: Int) -> Result[Bid, Str]
  examples {
    submit_bid(post_request("req-1", "buyer-a", "plumbing", "fix leaky sink", { cents: 50000, currency: "USD" }, [], 1000), "bid-1", "supplier-b", { cents: 40000, currency: "USD" }, "we can do this", 500) => Ok({ id: "bid-1", request_id: "req-1", supplier: "supplier-b", price: { cents: 40000, currency: "USD" }, message: "we can do this", state: BidSubmitted }),
    submit_bid({ id: "req-1", buyer: "buyer-a", capability: "plumbing", description: "fix leaky sink", budget_ceiling: { cents: 50000, currency: "USD" }, criteria: [], deadline_ms: 1000, state: ReqAwarded }, "bid-1", "supplier-b", { cents: 40000, currency: "USD" }, "we can do this", 500) => Err("request_not_open"),
    submit_bid(post_request("req-1", "buyer-a", "plumbing", "fix leaky sink", { cents: 50000, currency: "USD" }, [], 1000), "bid-1", "supplier-b", { cents: 40000, currency: "USD" }, "we can do this", 1001) => Err("deadline_passed"),
    submit_bid(post_request("req-1", "buyer-a", "plumbing", "fix leaky sink", { cents: 50000, currency: "USD" }, [], 1000), "bid-1", "supplier-b", { cents: 40000, currency: "EUR" }, "we can do this", 500) => Err("currency_mismatch"),
    submit_bid(post_request("req-1", "buyer-a", "plumbing", "fix leaky sink", { cents: 50000, currency: "USD" }, [], 1000), "bid-1", "supplier-b", { cents: 50001, currency: "USD" }, "we can do this", 500) => Err("over_budget")
  }
{
  match request.state {
    ReqOpen => if now_ms > request.deadline_ms {
      Err("deadline_passed")
    } else {
      if price.currency != request.budget_ceiling.currency {
        Err("currency_mismatch")
      } else {
        if price.cents > request.budget_ceiling.cents {
          Err("over_budget")
        } else {
          Ok({ id: bid_id, request_id: request.id, supplier: supplier, price: price, message: message, state: BidSubmitted })
        }
      }
    },
    _ => Err("request_not_open"),
  }
}

fn withdraw_bid(bid :: Bid) -> Result[Bid, Str]
  examples {
    withdraw_bid({ id: "bid-1", request_id: "req-1", supplier: "supplier-b", price: { cents: 40000, currency: "USD" }, message: "we can do this", state: BidSubmitted }) => Ok({ id: "bid-1", request_id: "req-1", supplier: "supplier-b", price: { cents: 40000, currency: "USD" }, message: "we can do this", state: BidWithdrawn }),
    withdraw_bid({ id: "bid-1", request_id: "req-1", supplier: "supplier-b", price: { cents: 40000, currency: "USD" }, message: "we can do this", state: BidWithdrawn }) => Err("not_submitted")
  }
{
  match bid.state {
    BidSubmitted => Ok({ id: bid.id, request_id: bid.request_id, supplier: bid.supplier, price: bid.price, message: bid.message, state: BidWithdrawn }),
    _ => Err("not_submitted"),
  }
}

fn award(request :: WorkRequest, bids :: List[Bid], winning_bid_id :: Str) -> Result[(WorkRequest, List[Bid]), Str]
  examples {
    award(post_request("req-1", "buyer-a", "plumbing", "fix leaky sink", { cents: 50000, currency: "USD" }, [], 1000), [{ id: "bid-1", request_id: "req-1", supplier: "supplier-b", price: { cents: 40000, currency: "USD" }, message: "we can do this", state: BidSubmitted }, { id: "bid-2", request_id: "req-1", supplier: "supplier-c", price: { cents: 45000, currency: "USD" }, message: "we can too", state: BidSubmitted }, { id: "bid-3", request_id: "req-2", supplier: "supplier-d", price: { cents: 30000, currency: "USD" }, message: "other request", state: BidSubmitted }, { id: "bid-4", request_id: "req-1", supplier: "supplier-e", price: { cents: 42000, currency: "USD" }, message: "withdrew", state: BidWithdrawn }], "bid-1") => Ok(({ id: "req-1", buyer: "buyer-a", capability: "plumbing", description: "fix leaky sink", budget_ceiling: { cents: 50000, currency: "USD" }, criteria: [], deadline_ms: 1000, state: ReqAwarded }, [{ id: "bid-1", request_id: "req-1", supplier: "supplier-b", price: { cents: 40000, currency: "USD" }, message: "we can do this", state: BidAccepted }, { id: "bid-2", request_id: "req-1", supplier: "supplier-c", price: { cents: 45000, currency: "USD" }, message: "we can too", state: BidRejected }, { id: "bid-3", request_id: "req-2", supplier: "supplier-d", price: { cents: 30000, currency: "USD" }, message: "other request", state: BidSubmitted }, { id: "bid-4", request_id: "req-1", supplier: "supplier-e", price: { cents: 42000, currency: "USD" }, message: "withdrew", state: BidWithdrawn }])),
    award({ id: "req-1", buyer: "buyer-a", capability: "plumbing", description: "fix leaky sink", budget_ceiling: { cents: 50000, currency: "USD" }, criteria: [], deadline_ms: 1000, state: ReqAwarded }, [{ id: "bid-1", request_id: "req-1", supplier: "supplier-b", price: { cents: 40000, currency: "USD" }, message: "we can do this", state: BidSubmitted }], "bid-1") => Err("request_not_open"),
    award(post_request("req-1", "buyer-a", "plumbing", "fix leaky sink", { cents: 50000, currency: "USD" }, [], 1000), [{ id: "bid-1", request_id: "req-1", supplier: "supplier-b", price: { cents: 40000, currency: "USD" }, message: "we can do this", state: BidSubmitted }], "bid-missing") => Err("invalid_bid"),
    award(post_request("req-1", "buyer-a", "plumbing", "fix leaky sink", { cents: 50000, currency: "USD" }, [], 1000), [{ id: "bid-1", request_id: "req-2", supplier: "supplier-b", price: { cents: 40000, currency: "USD" }, message: "we can do this", state: BidSubmitted }], "bid-1") => Err("bid_request_mismatch")
  }
{
  match request.state {
    ReqOpen => {
      let submitted_bids := list.filter(bids, fn (b :: Bid) -> Bool {
        b.id == winning_bid_id and b.state == BidSubmitted
      })
      match list.head(submitted_bids) {
        None => Err("invalid_bid"),
        Some(winner) => if winner.request_id != request.id {
          Err("bid_request_mismatch")
        } else {
          let updated_bids := list.map(bids, fn (b :: Bid) -> Bid {
            if b.id == winning_bid_id {
              { id: b.id, request_id: b.request_id, supplier: b.supplier, price: b.price, message: b.message, state: BidAccepted }
            } else {
              if b.request_id == request.id and b.state == BidSubmitted {
                { id: b.id, request_id: b.request_id, supplier: b.supplier, price: b.price, message: b.message, state: BidRejected }
              } else {
                b
              }
            }
          })
          Ok(({ id: request.id, buyer: request.buyer, capability: request.capability, description: request.description, budget_ceiling: request.budget_ceiling, criteria: request.criteria, deadline_ms: request.deadline_ms, state: ReqAwarded }, updated_bids))
        },
      }
    },
    _ => Err("request_not_open"),
  }
}

fn cancel_request(request :: WorkRequest) -> Result[WorkRequest, Str]
  examples {
    cancel_request(post_request("req-1", "buyer-a", "plumbing", "fix leaky sink", { cents: 50000, currency: "USD" }, [], 1000)) => Ok({ id: "req-1", buyer: "buyer-a", capability: "plumbing", description: "fix leaky sink", budget_ceiling: { cents: 50000, currency: "USD" }, criteria: [], deadline_ms: 1000, state: ReqCancelled }),
    cancel_request({ id: "req-1", buyer: "buyer-a", capability: "plumbing", description: "fix leaky sink", budget_ceiling: { cents: 50000, currency: "USD" }, criteria: [], deadline_ms: 1000, state: ReqAwarded }) => Err("request_not_open")
  }
{
  match request.state {
    ReqOpen => Ok({ id: request.id, buyer: request.buyer, capability: request.capability, description: request.description, budget_ceiling: request.budget_ceiling, criteria: request.criteria, deadline_ms: request.deadline_ms, state: ReqCancelled }),
    _ => Err("request_not_open"),
  }
}

fn is_terminal(request :: WorkRequest) -> Bool
  examples {
    is_terminal(post_request("req-1", "buyer-a", "plumbing", "fix leaky sink", { cents: 50000, currency: "USD" }, [], 1000)) => false,
    is_terminal({ id: "req-1", buyer: "buyer-a", capability: "plumbing", description: "fix leaky sink", budget_ceiling: { cents: 50000, currency: "USD" }, criteria: [], deadline_ms: 1000, state: ReqAwarded }) => true,
    is_terminal({ id: "req-1", buyer: "buyer-a", capability: "plumbing", description: "fix leaky sink", budget_ceiling: { cents: 50000, currency: "USD" }, criteria: [], deadline_ms: 1000, state: ReqCancelled }) => true,
    is_terminal({ id: "req-1", buyer: "buyer-a", capability: "plumbing", description: "fix leaky sink", budget_ceiling: { cents: 50000, currency: "USD" }, criteria: [], deadline_ms: 1000, state: ReqExpired }) => true
  }
{
  match request.state {
    ReqAwarded => true,
    ReqCancelled => true,
    ReqExpired => true,
    ReqOpen => false,
  }
}

