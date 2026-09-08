import "../src/contract" as c

import "std.io" as io

fn base_contract(state :: c.ContractState) -> c.Contract {
  { id: "c-1", buyer: "buyer-a", supplier: "supplier-b", price: { cents: 10000, currency: "USD" }, state: state }
}

fn check(name :: Str, got :: Bool, want :: Bool) -> [io] Bool {
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

fn result_state_matches(contract :: c.Contract, event :: c.ContractEvent, want :: c.ContractState) -> Bool {
  match c.transition(contract, event) {
    Ok(updated) => updated.state == want,
    Err(_) => false,
  }
}

fn result_is_err(contract :: c.Contract, event :: c.ContractEvent) -> Bool {
  match c.transition(contract, event) {
    Ok(_) => false,
    Err(_) => true,
  }
}

fn verify_valid_transitions() -> [io] Bool {
  let v := c.PartiallyFulfilled(["missing widget"])
  let r1 := check("Awarded+WasStarted->InProgress", result_state_matches(base_contract(c.Awarded), c.WasStarted, c.InProgress), true)
  let r2 := check("InProgress+WasDelivered->Delivered", result_state_matches(base_contract(c.InProgress), c.WasDelivered, c.Delivered), true)
  let r3 := check("Delivered+WasVerified(Fulfilled)->Verified(Fulfilled)", result_state_matches(base_contract(c.Delivered), c.WasVerified(c.Fulfilled), c.Verified(c.Fulfilled)), true)
  let r4 := check("Delivered+WasVerified(PartiallyFulfilled)->Verified(PartiallyFulfilled)", result_state_matches(base_contract(c.Delivered), c.WasVerified(v), c.Verified(v)), true)
  let r5 := check("Verified(Fulfilled)+WasSettled->Settled", result_state_matches(base_contract(c.Verified(c.Fulfilled)), c.WasSettled, c.Settled), true)
  let r6 := check("Verified(Fulfilled)+WasDisputed->Disputed", result_state_matches(base_contract(c.Verified(c.Fulfilled)), c.WasDisputed, c.Disputed), true)
  let r7 := check("Delivered+WasDisputed->Disputed", result_state_matches(base_contract(c.Delivered), c.WasDisputed, c.Disputed), true)
  let r8 := check("Awarded+WasCancelled->Cancelled", result_state_matches(base_contract(c.Awarded), c.WasCancelled, c.Cancelled), true)
  let r9 := check("InProgress+WasCancelled->Cancelled", result_state_matches(base_contract(c.InProgress), c.WasCancelled, c.Cancelled), true)
  let r10 := check("Delivered+WasCancelled->Cancelled", result_state_matches(base_contract(c.Delivered), c.WasCancelled, c.Cancelled), true)
  let r11 := check("Verified(Fulfilled)+WasCancelled->Cancelled", result_state_matches(base_contract(c.Verified(c.Fulfilled)), c.WasCancelled, c.Cancelled), true)
  r1 and r2 and r3 and r4 and r5 and r6 and r7 and r8 and r9 and r10 and r11
}

fn verify_invalid_transitions() -> [io] Bool {
  let r1 := check("Awarded+WasSettled is Err", result_is_err(base_contract(c.Awarded), c.WasSettled), true)
  let r2 := check("InProgress+WasStarted is Err", result_is_err(base_contract(c.InProgress), c.WasStarted), true)
  let r3 := check("Delivered+WasSettled is Err", result_is_err(base_contract(c.Delivered), c.WasSettled), true)
  let r4 := check("Awarded+WasDelivered is Err", result_is_err(base_contract(c.Awarded), c.WasDelivered), true)
  let r5 := check("Awarded+WasVerified is Err", result_is_err(base_contract(c.Awarded), c.WasVerified(c.Fulfilled)), true)
  let r6 := check("InProgress+WasSettled is Err", result_is_err(base_contract(c.InProgress), c.WasSettled), true)
  let r7 := check("InProgress+WasDisputed is Err", result_is_err(base_contract(c.InProgress), c.WasDisputed), true)
  let r8 := check("Verified+WasDelivered is Err", result_is_err(base_contract(c.Verified(c.Fulfilled)), c.WasDelivered), true)
  let r9 := check("Verified+WasVerified is Err", result_is_err(base_contract(c.Verified(c.Fulfilled)), c.WasVerified(c.Fulfilled)), true)
  let r10 := check("Settled+WasStarted is Err", result_is_err(base_contract(c.Settled), c.WasStarted), true)
  let r11 := check("Disputed+WasSettled is Err", result_is_err(base_contract(c.Disputed), c.WasSettled), true)
  let r12 := check("Cancelled+WasCancelled is Err", result_is_err(base_contract(c.Cancelled), c.WasCancelled), true)
  r1 and r2 and r3 and r4 and r5 and r6 and r7 and r8 and r9 and r10 and r11 and r12
}

fn verify_totality_state(state :: c.ContractState) -> [io] Bool {
  let e1 := check("totality Awarded WasStarted", true, true)
  let r1 := match c.transition(base_contract(state), c.WasStarted) {
    Ok(_) => true,
    Err(_) => true,
  }
  let e2 := check("totality", r1, true)
  let r2 := match c.transition(base_contract(state), c.WasDelivered) {
    Ok(_) => true,
    Err(_) => true,
  }
  let e3 := check("totality", r2, true)
  let r3 := match c.transition(base_contract(state), c.WasVerified(c.Fulfilled)) {
    Ok(_) => true,
    Err(_) => true,
  }
  let e4 := check("totality", r3, true)
  let r4 := match c.transition(base_contract(state), c.WasSettled) {
    Ok(_) => true,
    Err(_) => true,
  }
  let e5 := check("totality", r4, true)
  let r5 := match c.transition(base_contract(state), c.WasDisputed) {
    Ok(_) => true,
    Err(_) => true,
  }
  let e6 := check("totality", r5, true)
  let r6 := match c.transition(base_contract(state), c.WasCancelled) {
    Ok(_) => true,
    Err(_) => true,
  }
  let e7 := check("totality", r6, true)
  e1 and e2 and e3 and e4 and e5 and e6 and e7
}

fn verify_totality() -> [io] Bool {
  let a := verify_totality_state(c.Awarded)
  let b := verify_totality_state(c.InProgress)
  let d := verify_totality_state(c.Delivered)
  let v := verify_totality_state(c.Verified(c.Fulfilled))
  let s := verify_totality_state(c.Settled)
  let p := verify_totality_state(c.Disputed)
  let x := verify_totality_state(c.Cancelled)
  a and b and d and v and s and p and x
}

fn verify_is_terminal() -> [io] Bool {
  let r1 := check("is_terminal(Awarded)=false", c.is_terminal(base_contract(c.Awarded)), false)
  let r2 := check("is_terminal(InProgress)=false", c.is_terminal(base_contract(c.InProgress)), false)
  let r3 := check("is_terminal(Delivered)=false", c.is_terminal(base_contract(c.Delivered)), false)
  let r4 := check("is_terminal(Verified(Fulfilled))=false", c.is_terminal(base_contract(c.Verified(c.Fulfilled))), false)
  let r5 := check("is_terminal(Verified(PartiallyFulfilled))=false", c.is_terminal(base_contract(c.Verified(c.PartiallyFulfilled(["x"])))), false)
  let r6 := check("is_terminal(Settled)=true", c.is_terminal(base_contract(c.Settled)), true)
  let r7 := check("is_terminal(Disputed)=true", c.is_terminal(base_contract(c.Disputed)), true)
  let r8 := check("is_terminal(Cancelled)=true", c.is_terminal(base_contract(c.Cancelled)), true)
  r1 and r2 and r3 and r4 and r5 and r6 and r7 and r8
}

fn verify_fields_preserved() -> [io] Bool {
  let contract := { id: "special-id", buyer: "b", supplier: "s", price: { cents: 50, currency: "EUR" }, state: c.Awarded }
  match c.transition(contract, c.WasStarted) {
    Ok(updated) => {
      let r1 := check("preserved id", updated.id == "special-id", true)
      let r2 := check("preserved buyer", updated.buyer == "b", true)
      let r3 := check("preserved supplier", updated.supplier == "s", true)
      let r4 := check("preserved price.cents", updated.price.cents == 50, true)
      let r5 := check("preserved price.currency", updated.price.currency == "EUR", true)
      let r6 := check("updated state", updated.state == c.InProgress, true)
      r1 and r2 and r3 and r4 and r5 and r6
    },
    Err(msg) => {
      io.print("FAIL fields preserved unexpected Err")
      false
    },
  }
}

fn main() -> [io] Unit {
  let r1 := verify_valid_transitions()
  let r2 := verify_invalid_transitions()
  let r3 := verify_totality()
  let r4 := verify_is_terminal()
  let r5 := verify_fields_preserved()
  if r1 and r2 and r3 and r4 and r5 {
    io.print("ALL CHECKS PASSED")
  } else {
    io.print("SOME CHECKS FAILED")
  }
}

