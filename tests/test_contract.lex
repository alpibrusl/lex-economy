import "../src/contract" as contract

fn base_contract(state :: contract.ContractState) -> contract.Contract {
  { id: "c-1", buyer: "buyer-a", supplier: "supplier-b", price: { cents: 10000, currency: "USD" }, state: state }
}

fn test_awarded_to_in_progress() -> Bool
  examples {
    test_awarded_to_in_progress() => true
  }
{
  match contract.transition(base_contract(contract.Awarded), contract.WasStarted) {
    Ok(c) => c.state == contract.InProgress,
    Err(_) => false,
  }
}

fn test_in_progress_to_delivered() -> Bool
  examples {
    test_in_progress_to_delivered() => true
  }
{
  match contract.transition(base_contract(contract.InProgress), contract.WasDelivered) {
    Ok(c) => c.state == contract.Delivered,
    Err(_) => false,
  }
}

fn test_delivered_to_verified() -> Bool
  examples {
    test_delivered_to_verified() => true
  }
{
  match contract.transition(base_contract(contract.Delivered), contract.WasVerified(contract.Fulfilled)) {
    Ok(c) => c.state == contract.Verified(contract.Fulfilled),
    Err(_) => false,
  }
}

fn test_verified_to_settled() -> Bool
  examples {
    test_verified_to_settled() => true
  }
{
  match contract.transition(base_contract(contract.Verified(contract.Fulfilled)), contract.WasSettled) {
    Ok(c) => c.state == contract.Settled,
    Err(_) => false,
  }
}

fn test_verified_to_disputed() -> Bool
  examples {
    test_verified_to_disputed() => true
  }
{
  match contract.transition(base_contract(contract.Verified(contract.Fulfilled)), contract.WasDisputed) {
    Ok(c) => c.state == contract.Disputed,
    Err(_) => false,
  }
}

fn test_delivered_to_disputed() -> Bool
  examples {
    test_delivered_to_disputed() => true
  }
{
  match contract.transition(base_contract(contract.Delivered), contract.WasDisputed) {
    Ok(c) => c.state == contract.Disputed,
    Err(_) => false,
  }
}

fn test_cancelled_from_awarded() -> Bool
  examples {
    test_cancelled_from_awarded() => true
  }
{
  match contract.transition(base_contract(contract.Awarded), contract.WasCancelled) {
    Ok(c) => c.state == contract.Cancelled,
    Err(_) => false,
  }
}

fn test_cancelled_from_in_progress() -> Bool
  examples {
    test_cancelled_from_in_progress() => true
  }
{
  match contract.transition(base_contract(contract.InProgress), contract.WasCancelled) {
    Ok(c) => c.state == contract.Cancelled,
    Err(_) => false,
  }
}

fn test_cancelled_from_delivered() -> Bool
  examples {
    test_cancelled_from_delivered() => true
  }
{
  match contract.transition(base_contract(contract.Delivered), contract.WasCancelled) {
    Ok(c) => c.state == contract.Cancelled,
    Err(_) => false,
  }
}

fn test_cancelled_from_verified() -> Bool
  examples {
    test_cancelled_from_verified() => true
  }
{
  match contract.transition(base_contract(contract.Verified(contract.Fulfilled)), contract.WasCancelled) {
    Ok(c) => c.state == contract.Cancelled,
    Err(_) => false,
  }
}

fn test_reject_awarded_settled() -> Bool
  examples {
    test_reject_awarded_settled() => true
  }
{
  match contract.transition(base_contract(contract.Awarded), contract.WasSettled) {
    Ok(_) => false,
    Err(_) => true,
  }
}

fn test_reject_started_twice() -> Bool
  examples {
    test_reject_started_twice() => true
  }
{
  match contract.transition(base_contract(contract.InProgress), contract.WasStarted) {
    Ok(_) => false,
    Err(_) => true,
  }
}

fn test_reject_delivered_settled_without_verification() -> Bool
  examples {
    test_reject_delivered_settled_without_verification() => true
  }
{
  match contract.transition(base_contract(contract.Delivered), contract.WasSettled) {
    Ok(_) => false,
    Err(_) => true,
  }
}

fn test_reject_terminal_settled() -> Bool
  examples {
    test_reject_terminal_settled() => true
  }
{
  match contract.transition(base_contract(contract.Settled), contract.WasDisputed) {
    Ok(_) => false,
    Err(_) => true,
  }
}

fn test_reject_terminal_disputed() -> Bool
  examples {
    test_reject_terminal_disputed() => true
  }
{
  match contract.transition(base_contract(contract.Disputed), contract.WasSettled) {
    Ok(_) => false,
    Err(_) => true,
  }
}

fn test_reject_terminal_cancelled() -> Bool
  examples {
    test_reject_terminal_cancelled() => true
  }
{
  match contract.transition(base_contract(contract.Cancelled), contract.WasStarted) {
    Ok(_) => false,
    Err(_) => true,
  }
}

fn test_partially_fulfilled_verdict() -> Bool
  examples {
    test_partially_fulfilled_verdict() => true
  }
{
  let verdict := contract.PartiallyFulfilled(["missing widget"])
  match contract.transition(base_contract(contract.Delivered), contract.WasVerified(verdict)) {
    Ok(c) => c.state == contract.Verified(verdict),
    Err(_) => false,
  }
}

fn test_is_terminal_true() -> Bool
  examples {
    test_is_terminal_true() => true
  }
{
  contract.is_terminal(base_contract(contract.Settled)) and contract.is_terminal(base_contract(contract.Disputed)) and contract.is_terminal(base_contract(contract.Cancelled))
}

fn test_is_terminal_false() -> Bool
  examples {
    test_is_terminal_false() => true
  }
{
  not contract.is_terminal(base_contract(contract.Awarded)) and not contract.is_terminal(base_contract(contract.InProgress)) and not contract.is_terminal(base_contract(contract.Delivered)) and not contract.is_terminal(base_contract(contract.Verified(contract.Fulfilled)))
}

fn test_id_preserved_on_transition() -> Bool
  examples {
    test_id_preserved_on_transition() => true
  }
{
  let c := contract.sample_contract(contract.Awarded)
  let c2 := { id: "special-id", buyer: "b", supplier: c.supplier, price: { cents: 50, currency: "EUR" }, state: contract.Awarded }
  match contract.transition(c2, contract.WasStarted) {
    Ok(next) => next.id == "special-id" and next.buyer == "b" and next.price.cents == 50 and next.price.currency == "EUR",
    Err(_) => false,
  }
}

fn run_all() -> Bool {
  test_awarded_to_in_progress() and test_in_progress_to_delivered() and test_delivered_to_verified() and test_verified_to_settled() and test_verified_to_disputed() and test_delivered_to_disputed() and test_cancelled_from_awarded() and test_cancelled_from_in_progress() and test_cancelled_from_delivered() and test_cancelled_from_verified() and test_reject_awarded_settled() and test_reject_started_twice() and test_reject_delivered_settled_without_verification() and test_reject_terminal_settled() and test_reject_terminal_disputed() and test_reject_terminal_cancelled() and test_partially_fulfilled_verdict() and test_is_terminal_true() and test_is_terminal_false() and test_id_preserved_on_transition()
}

