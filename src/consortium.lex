import "./contract" as contract

type PortfolioView = {
  objective_met :: Bool,
  total_spent_cents :: Int,
  open_contracts :: Int,
  remaining_capital_cents :: Int,
  now_ms :: Int,
}

type TerminationRule = {
  max_spend_cents :: Int,
  deadline_ms :: Int,
}

type Consortium = {
  id :: Str,
  objective :: Str,
  companies :: List[Str],
  max_spend :: contract.Money,
}

fn should_terminate(view :: PortfolioView, rule :: TerminationRule) -> Bool
  examples {
    # None of the four conditions hold
    should_terminate(
      { objective_met: false, total_spent_cents: 5000, open_contracts: 2, remaining_capital_cents: 1000, now_ms: 1000 },
      { max_spend_cents: 10000, deadline_ms: 2000 }
    ) => false,

    # Condition 1 alone: objective_met is true
    should_terminate(
      { objective_met: true, total_spent_cents: 5000, open_contracts: 2, remaining_capital_cents: 1000, now_ms: 1000 },
      { max_spend_cents: 10000, deadline_ms: 2000 }
    ) => true,

    # Condition 2 alone: spend exactly at ceiling
    should_terminate(
      { objective_met: false, total_spent_cents: 10000, open_contracts: 2, remaining_capital_cents: 1000, now_ms: 1000 },
      { max_spend_cents: 10000, deadline_ms: 2000 }
    ) => true,

    # Condition 2 alone: spend over ceiling
    should_terminate(
      { objective_met: false, total_spent_cents: 10500, open_contracts: 2, remaining_capital_cents: 1000, now_ms: 1000 },
      { max_spend_cents: 10000, deadline_ms: 2000 }
    ) => true,

    # Condition 3 alone: past deadline
    should_terminate(
      { objective_met: false, total_spent_cents: 5000, open_contracts: 2, remaining_capital_cents: 1000, now_ms: 2500 },
      { max_spend_cents: 10000, deadline_ms: 2000 }
    ) => true,

    # Condition 4: zero open contracts and zero remaining capital
    should_terminate(
      { objective_met: false, total_spent_cents: 5000, open_contracts: 0, remaining_capital_cents: 0, now_ms: 1000 },
      { max_spend_cents: 10000, deadline_ms: 2000 }
    ) => true,

    # Condition 4: zero open contracts and negative remaining capital
    should_terminate(
      { objective_met: false, total_spent_cents: 5000, open_contracts: 0, remaining_capital_cents: -100, now_ms: 1000 },
      { max_spend_cents: 10000, deadline_ms: 2000 }
    ) => true,

    # Near miss: zero open contracts but capital still positive
    should_terminate(
      { objective_met: false, total_spent_cents: 5000, open_contracts: 0, remaining_capital_cents: 1000, now_ms: 1000 },
      { max_spend_cents: 10000, deadline_ms: 2000 }
    ) => false,

    # Near miss: capital exhausted but open contracts remain
    should_terminate(
      { objective_met: false, total_spent_cents: 5000, open_contracts: 1, remaining_capital_cents: 0, now_ms: 1000 },
      { max_spend_cents: 10000, deadline_ms: 2000 }
    ) => false,
  }
{
  view.objective_met or
  view.total_spent_cents >= rule.max_spend_cents or
  view.now_ms > rule.deadline_ms or
  (view.open_contracts == 0 and view.remaining_capital_cents <= 0)
}

fn new_consortium(id :: Str, objective :: Str, companies :: List[Str], max_spend :: contract.Money) -> Consortium
  examples {
    new_consortium(
      "consortium-1",
      "deliver widgets",
      ["company-a", "company-b"],
      { cents: 500000, currency: "USD" }
    ) => {
      id: "consortium-1",
      objective: "deliver widgets",
      companies: ["company-a", "company-b"],
      max_spend: { cents: 500000, currency: "USD" },
    }
  }
{
  { id: id, objective: objective, companies: companies, max_spend: max_spend }
}
