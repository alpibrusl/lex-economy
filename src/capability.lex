import "lex-schema/json_value" as jv

import "std.list" as list

import "std.int" as int

type Constraint = { attr :: Str, op :: Str, value :: jv.Json }

type Query = { capability :: Str, constraints :: List[Constraint] }

type Offer = { capability :: Str, attrs :: jv.Json }

type Match = { company :: Str, capability :: Str, score :: Int }

type CompanyOffers = { company :: Str, offers :: List[Offer] }

fn exact_query(capability :: Str) -> Query
  examples {
    exact_query("compute") => { capability: "compute", constraints: [] }
  }
{
  { capability: capability, constraints: [] }
}

fn json_eq(a :: jv.Json, b :: jv.Json) -> Bool {
  match (a, b) {
    (JStr(sa), JStr(sb)) => sa == sb,
    (JBool(ba), JBool(bb)) => ba == bb,
    (JInt(na), JInt(nb)) => na == nb,
    (JFloat(xa), JFloat(xb)) => xa == xb,
    (JInt(na), JFloat(xb)) => int.to_float(na) == xb,
    (JFloat(xa), JInt(nb)) => xa == int.to_float(nb),
    _ => false,
  }
}

fn numeric_compare(field :: jv.Json, value :: jv.Json, cmp :: (Float, Float) -> Bool) -> Bool {
  match (jv.as_float(field), jv.as_float(value)) {
    (Some(x), Some(y)) => cmp(x, y),
    _ => false,
  }
}

fn eval_constraint(attrs :: jv.Json, c :: Constraint) -> Bool
  examples {
    eval_constraint(jv.JObj([("ready", jv.JBool(true))]), { attr: "ready", op: "eq", value: jv.JBool(true) }) => true,
    eval_constraint(jv.JObj([("ready", jv.JBool(false))]), { attr: "ready", op: "eq", value: jv.JBool(true) }) => false,
    eval_constraint(jv.JObj([("ready", jv.JBool(false))]), { attr: "ready", op: "ne", value: jv.JBool(true) }) => true,
    eval_constraint(jv.JObj([("ready", jv.JBool(true))]), { attr: "ready", op: "ne", value: jv.JBool(true) }) => false,
    eval_constraint(jv.JObj([("cores", jv.JInt(8))]), { attr: "cores", op: "gte", value: jv.JInt(4) }) => true,
    eval_constraint(jv.JObj([("cores", jv.JInt(2))]), { attr: "cores", op: "gte", value: jv.JInt(4) }) => false,
    eval_constraint(jv.JObj([("x", jv.JInt(5))]), { attr: "x", op: "eq", value: jv.JFloat(5.0) }) => true,
    eval_constraint(jv.JObj([("x", jv.JInt(5))]), { attr: "missing", op: "eq", value: jv.JInt(1) }) => false,
    eval_constraint(jv.JObj([("x", jv.JInt(5))]), { attr: "x", op: "unknown", value: jv.JInt(1) }) => false
  }
{
  match jv.get_field(attrs, c.attr) {
    None => false,
    Some(field) => match c.op {
      "eq" => json_eq(field, c.value),
      "ne" => if json_eq(field, c.value) {
        false
      } else {
        true
      },
      "lte" => numeric_compare(field, c.value, fn (x :: Float, y :: Float) -> Bool {
        x <= y
      }),
      "gte" => numeric_compare(field, c.value, fn (x :: Float, y :: Float) -> Bool {
        x >= y
      }),
      "lt" => numeric_compare(field, c.value, fn (x :: Float, y :: Float) -> Bool {
        x < y
      }),
      "gt" => numeric_compare(field, c.value, fn (x :: Float, y :: Float) -> Bool {
        x > y
      }),
      _ => false,
    },
  }
}

fn offer_satisfies(o :: Offer, q :: Query) -> Bool
  examples {
    offer_satisfies({ capability: "compute", attrs: jv.JObj([]) }, { capability: "compute", constraints: [] }) => true,
    offer_satisfies({ capability: "compute", attrs: jv.JObj([("ready", jv.JBool(true)), ("cores", jv.JInt(8))]) }, { capability: "compute", constraints: [{ attr: "ready", op: "eq", value: jv.JBool(true) }, { attr: "cores", op: "gte", value: jv.JInt(4) }] }) => true,
    offer_satisfies({ capability: "compute", attrs: jv.JObj([("ready", jv.JBool(true)), ("cores", jv.JInt(2))]) }, { capability: "compute", constraints: [{ attr: "ready", op: "eq", value: jv.JBool(true) }, { attr: "cores", op: "gte", value: jv.JInt(4) }] }) => false,
    offer_satisfies({ capability: "storage", attrs: jv.JObj([("ready", jv.JBool(true))]) }, { capability: "compute", constraints: [{ attr: "ready", op: "eq", value: jv.JBool(true) }] }) => false
  }
{
  if o.capability != q.capability {
    false
  } else {
    list.fold(q.constraints, true, fn (acc :: Bool, c :: Constraint) -> Bool {
      if acc {
        eval_constraint(o.attrs, c)
      } else {
        false
      }
    })
  }
}

fn attr_count(attrs :: jv.Json) -> Int
  examples {
    attr_count(jv.JObj([("a", jv.JInt(1)), ("b", jv.JBool(true))])) => 2,
    attr_count(jv.JObj([])) => 0,
    attr_count(jv.JInt(42)) => 0,
    attr_count(jv.JList([jv.JInt(1), jv.JInt(2)])) => 0
  }
{
  match attrs {
    JObj(entries) => list.len(entries),
    _ => 0,
  }
}

fn best_score(offers :: List[Offer], q :: Query) -> Option[Int] {
  list.fold(offers, None, fn (acc :: Option[Int], o :: Offer) -> Option[Int] {
    if offer_satisfies(o, q) {
      let score := attr_count(o.attrs)
      match acc {
        None => Some(score),
        Some(best) => if score > best {
          Some(score)
        } else {
          Some(best)
        },
      }
    } else {
      acc
    }
  })
}

fn company_matches(entry :: CompanyOffers, q :: Query) -> Option[Match] {
  match best_score(entry.offers, q) {
    None => None,
    Some(score) => Some({ company: entry.company, capability: q.capability, score: score }),
  }
}

fn match_score(m :: Match) -> Int {
  m.score
}

fn find(entries :: List[CompanyOffers], q :: Query) -> List[Match]
  examples {
    find([{ company: "Acme", offers: [{ capability: "compute", attrs: jv.JObj([("ready", jv.JBool(true)), ("cores", jv.JInt(8))]) }, { capability: "compute", attrs: jv.JObj([("ready", jv.JBool(true))]) }] }, { company: "Beta", offers: [{ capability: "compute", attrs: jv.JObj([("ready", jv.JBool(true)), ("cores", jv.JInt(4)), ("ssd", jv.JBool(true))]) }] }, { company: "Gamma", offers: [{ capability: "storage", attrs: jv.JObj([("ready", jv.JBool(true))]) }] }], { capability: "compute", constraints: [{ attr: "ready", op: "eq", value: jv.JBool(true) }] }) => [{ company: "Beta", capability: "compute", score: 3 }, { company: "Acme", capability: "compute", score: 2 }],
    find([], { capability: "compute", constraints: [] }) => []
  }
{
  let matches := list.fold(entries, [], fn (acc :: List[Match], entry :: CompanyOffers) -> List[Match] {
    match company_matches(entry, q) {
      None => acc,
      Some(m) => list.concat(acc, [m]),
    }
  })
  list.sort_by(matches, fn (m :: Match) -> Int {
    -m.score
  })
}

