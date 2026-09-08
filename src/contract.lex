type Money = { cents :: Int, currency :: Str }

type Verdict = Fulfilled | PartiallyFulfilled(List[Str]) | Rejected(List[Str]) | Ambiguous(List[Str])

type ContractState = Awarded | InProgress | Delivered | Verified(Verdict) | Settled | Disputed | Cancelled

type ContractEvent = WasStarted | WasDelivered | WasVerified(Verdict) | WasSettled | WasDisputed | WasCancelled

type Contract = { id :: Str, buyer :: Str, supplier :: Str, price :: Money, state :: ContractState }

fn sample_contract(state :: ContractState) -> Contract
  examples {
    sample_contract(Awarded) => { id: "c-1", buyer: "buyer-a", supplier: "supplier-b", price: { cents: 10000, currency: "USD" }, state: Awarded }
  }
{
  { id: "c-1", buyer: "buyer-a", supplier: "supplier-b", price: { cents: 10000, currency: "USD" }, state: state }
}

fn with_state(c :: Contract, state :: ContractState) -> Contract
  examples {
    with_state(sample_contract(Awarded), InProgress) => { id: "c-1", buyer: "buyer-a", supplier: "supplier-b", price: { cents: 10000, currency: "USD" }, state: InProgress }
  }
{
  { id: c.id, buyer: c.buyer, supplier: c.supplier, price: c.price, state: state }
}

fn transition(c :: Contract, event :: ContractEvent) -> Result[Contract, Str]
  examples {
    transition(sample_contract(Awarded), WasStarted) => Ok({ id: "c-1", buyer: "buyer-a", supplier: "supplier-b", price: { cents: 10000, currency: "USD" }, state: InProgress }),
    transition({ id: "c-1", buyer: "buyer-a", supplier: "supplier-b", price: { cents: 10000, currency: "USD" }, state: InProgress }, WasDelivered) => Ok({ id: "c-1", buyer: "buyer-a", supplier: "supplier-b", price: { cents: 10000, currency: "USD" }, state: Delivered }),
    transition({ id: "c-1", buyer: "buyer-a", supplier: "supplier-b", price: { cents: 10000, currency: "USD" }, state: Delivered }, WasVerified(Fulfilled)) => Ok({ id: "c-1", buyer: "buyer-a", supplier: "supplier-b", price: { cents: 10000, currency: "USD" }, state: Verified(Fulfilled) }),
    transition({ id: "c-1", buyer: "buyer-a", supplier: "supplier-b", price: { cents: 10000, currency: "USD" }, state: Verified(Fulfilled) }, WasSettled) => Ok({ id: "c-1", buyer: "buyer-a", supplier: "supplier-b", price: { cents: 10000, currency: "USD" }, state: Settled }),
    transition({ id: "c-1", buyer: "buyer-a", supplier: "supplier-b", price: { cents: 10000, currency: "USD" }, state: Verified(Fulfilled) }, WasDisputed) => Ok({ id: "c-1", buyer: "buyer-a", supplier: "supplier-b", price: { cents: 10000, currency: "USD" }, state: Disputed }),
    transition({ id: "c-1", buyer: "buyer-a", supplier: "supplier-b", price: { cents: 10000, currency: "USD" }, state: Delivered }, WasDisputed) => Ok({ id: "c-1", buyer: "buyer-a", supplier: "supplier-b", price: { cents: 10000, currency: "USD" }, state: Disputed }),
    transition({ id: "c-1", buyer: "buyer-a", supplier: "supplier-b", price: { cents: 10000, currency: "USD" }, state: Awarded }, WasCancelled) => Ok({ id: "c-1", buyer: "buyer-a", supplier: "supplier-b", price: { cents: 10000, currency: "USD" }, state: Cancelled }),
    transition({ id: "c-1", buyer: "buyer-a", supplier: "supplier-b", price: { cents: 10000, currency: "USD" }, state: Awarded }, WasSettled) => Err("invalid event for Awarded state"),
    transition({ id: "c-1", buyer: "buyer-a", supplier: "supplier-b", price: { cents: 10000, currency: "USD" }, state: InProgress }, WasStarted) => Err("invalid event for InProgress state"),
    transition({ id: "c-1", buyer: "buyer-a", supplier: "supplier-b", price: { cents: 10000, currency: "USD" }, state: Cancelled }, WasStarted) => Err("cannot transition from terminal Cancelled state")
  }
{
  match c.state {
    Awarded => match event {
      WasStarted => Ok(with_state(c, InProgress)),
      WasCancelled => Ok(with_state(c, Cancelled)),
      _ => Err("invalid event for Awarded state"),
    },
    InProgress => match event {
      WasDelivered => Ok(with_state(c, Delivered)),
      WasCancelled => Ok(with_state(c, Cancelled)),
      _ => Err("invalid event for InProgress state"),
    },
    Delivered => match event {
      WasVerified(v) => Ok(with_state(c, Verified(v))),
      WasDisputed => Ok(with_state(c, Disputed)),
      WasCancelled => Ok(with_state(c, Cancelled)),
      _ => Err("invalid event for Delivered state"),
    },
    Verified(_) => match event {
      WasSettled => Ok(with_state(c, Settled)),
      WasDisputed => Ok(with_state(c, Disputed)),
      WasCancelled => Ok(with_state(c, Cancelled)),
      _ => Err("invalid event for Verified state"),
    },
    Settled => Err("cannot transition from terminal Settled state"),
    Disputed => Err("cannot transition from terminal Disputed state"),
    Cancelled => Err("cannot transition from terminal Cancelled state"),
  }
}

fn is_terminal(c :: Contract) -> Bool
  examples {
    is_terminal(sample_contract(Awarded)) => false,
    is_terminal(sample_contract(InProgress)) => false,
    is_terminal(sample_contract(Delivered)) => false,
    is_terminal({ id: "c-1", buyer: "buyer-a", supplier: "supplier-b", price: { cents: 10000, currency: "USD" }, state: Verified(Fulfilled) }) => false,
    is_terminal(sample_contract(Settled)) => true,
    is_terminal(sample_contract(Disputed)) => true,
    is_terminal(sample_contract(Cancelled)) => true
  }
{
  match c.state {
    Settled => true,
    Disputed => true,
    Cancelled => true,
    _ => false,
  }
}

