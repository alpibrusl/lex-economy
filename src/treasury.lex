import "std.sql" as sql

import "std.str" as str

import "std.int" as int

import "std.json" as json

import "std.list" as list

import "lex-trail/log" as tlog

type Treasury = { company :: Str, currency :: Str, balance_cents :: Int, committed_cents :: Int }

type CommitmentState = Reserved | Released | Settled

type Commitment = { id :: Str, company :: Str, contract_id :: Str, amount_cents :: Int, currency :: Str, state :: CommitmentState }

fn available_cents(t :: Treasury) -> Int
  examples {
    available_cents({ company: "Acme", currency: "USD", balance_cents: 1000, committed_cents: 300 }) => 700,
    available_cents({ company: "Acme", currency: "USD", balance_cents: 500, committed_cents: 500 }) => 0,
    available_cents({ company: "Acme", currency: "USD", balance_cents: 0, committed_cents: 0 }) => 0
  }
{
  t.balance_cents - t.committed_cents
}

fn state_to_str(s :: CommitmentState) -> Str {
  match s {
    Reserved => "reserved",
    Released => "released",
    Settled => "settled",
  }
}

fn str_to_state(s :: Str) -> Option[CommitmentState] {
  if s == "reserved" {
    Some(Reserved)
  } else {
    if s == "released" {
      Some(Released)
    } else {
      if s == "settled" {
        Some(Settled)
      } else {
        None
      }
    }
  }
}

fn opt_str(o :: Option[Str]) -> Str {
  match o {
    Some(s) => s,
    None => "",
  }
}

fn opt_int(o :: Option[Int]) -> Int {
  match o {
    Some(n) => n,
    None => 0,
  }
}

fn init_schema(db :: Db) -> [sql] Result[Unit, Str] {
  let treasuries := "CREATE TABLE IF NOT EXISTS treasuries (company TEXT PRIMARY KEY, currency TEXT NOT NULL, balance_cents BIGINT NOT NULL, committed_cents BIGINT NOT NULL)"
  let commitments := "CREATE TABLE IF NOT EXISTS commitments (id TEXT PRIMARY KEY, company TEXT NOT NULL, contract_id TEXT NOT NULL, amount_cents BIGINT NOT NULL, currency TEXT NOT NULL, state TEXT NOT NULL)"
  match sql.exec(db, treasuries, []) {
    Err(e) => Err(e.message),
    Ok(_) => match sql.exec(db, commitments, []) {
      Err(e2) => Err(e2.message),
      Ok(_) => Ok(()),
    },
  }
}

fn open_treasury(db :: Db, company :: Str, currency :: Str, opening_balance_cents :: Int) -> [sql] Result[Unit, Str] {
  let stmt := "INSERT INTO treasuries (company, currency, balance_cents, committed_cents) VALUES (?, ?, ?, 0) ON CONFLICT (company) DO NOTHING"
  match sql.exec(db, stmt, [PStr(company), PStr(currency), PInt(opening_balance_cents)]) {
    Err(e) => Err(e.message),
    Ok(_) => Ok(()),
  }
}

fn get_treasury(db :: Db, company :: Str) -> [sql] Result[Option[Treasury], Str] {
  let stmt := "SELECT company, currency, balance_cents, committed_cents FROM treasuries WHERE company = ?"
  match sql.query(db, stmt, [PStr(company)]) {
    Err(e) => Err(e.message),
    Ok(rows) => match list.head(rows) {
      None => Ok(None),
      Some(r) => Ok(Some({ company: opt_str(sql.get_str(r, "company")), currency: opt_str(sql.get_str(r, "currency")), balance_cents: opt_int(sql.get_int(r, "balance_cents")), committed_cents: opt_int(sql.get_int(r, "committed_cents")) })),
    },
  }
}

fn get_commitment(db :: Db, commitment_id :: Str) -> [sql] Result[Option[Commitment], Str] {
  let stmt := "SELECT id, company, contract_id, amount_cents, currency, state FROM commitments WHERE id = ?"
  match sql.query(db, stmt, [PStr(commitment_id)]) {
    Err(e) => Err(e.message),
    Ok(rows) => match list.head(rows) {
      None => Ok(None),
      Some(r) => {
        let state_str := opt_str(sql.get_str(r, "state"))
        match str_to_state(state_str) {
          None => Err(str.concat("unknown commitment state: ", state_str)),
          Some(s) => Ok(Some({ id: opt_str(sql.get_str(r, "id")), company: opt_str(sql.get_str(r, "company")), contract_id: opt_str(sql.get_str(r, "contract_id")), amount_cents: opt_int(sql.get_int(r, "amount_cents")), currency: opt_str(sql.get_str(r, "currency")), state: s })),
        }
      },
    },
  }
}

fn commit_funds(db :: Db, log :: tlog.Log, company :: Str, contract_id :: Str, commitment_id :: Str, amount_cents :: Int, currency :: Str) -> [sql, time] Result[Commitment, Str] {
  if amount_cents <= 0 {
    Err("invalid_amount")
  } else {
    match get_treasury(db, company) {
      Err(e) => Err(e),
      Ok(None) => Err("no_such_treasury"),
      Ok(Some(t)) => {
        if t.currency != currency {
          Err("currency_mismatch")
        } else {
          if available_cents(t) < amount_cents {
            Err("insufficient_funds")
          } else {
            let new_committed := t.committed_cents + amount_cents
            let commitment := { id: commitment_id, company: company, contract_id: contract_id, amount_cents: amount_cents, currency: currency, state: Reserved }
            let payload := str.join(["{", json.stringify("company"), ":", json.stringify(company), ",", json.stringify("contract_id"), ":", json.stringify(contract_id), ",", json.stringify("commitment_id"), ":", json.stringify(commitment_id), ",", json.stringify("amount_cents"), ":", int.to_str(amount_cents), ",", json.stringify("currency"), ":", json.stringify(currency), "}"], "")
            in_transaction(db, fn (tx :: Db) -> [sql, time] Result[Commitment, Str] {
              match sql.exec(tx, "UPDATE treasuries SET committed_cents = ? WHERE company = ?", [PInt(new_committed), PStr(company)]) {
                Err(e) => Err(e.message),
                Ok(_) => match sql.exec(tx, "INSERT INTO commitments (id, company, contract_id, amount_cents, currency, state) VALUES (?, ?, ?, ?, ?, ?)", [PStr(commitment_id), PStr(company), PStr(contract_id), PInt(amount_cents), PStr(currency), PStr(state_to_str(Reserved))]) {
                  Err(e2) => Err(e2.message),
                  Ok(_) => match tlog.append(log, "treasury.committed", None, payload) {
                    Err(e3) => Err(e3),
                    Ok(_) => Ok(commitment),
                  },
                },
              }
            })
          }
        }
      },
    }
  }
}

fn release_commitment(db :: Db, log :: tlog.Log, commitment_id :: Str) -> [sql, time] Result[Unit, Str] {
  match get_commitment(db, commitment_id) {
    Err(e) => Err(e),
    Ok(None) => Err("no_such_commitment"),
    Ok(Some(c)) => {
      match c.state {
        Released => Err("not_reserved"),
        Settled => Err("not_reserved"),
        Reserved => {
          match get_treasury(db, c.company) {
            Err(e) => Err(e),
            Ok(None) => Err("no_such_treasury"),
            Ok(Some(t)) => {
              let new_committed := t.committed_cents - c.amount_cents
              let payload := str.join(["{", json.stringify("company"), ":", json.stringify(c.company), ",", json.stringify("contract_id"), ":", json.stringify(c.contract_id), ",", json.stringify("commitment_id"), ":", json.stringify(commitment_id), ",", json.stringify("amount_cents"), ":", int.to_str(c.amount_cents), ",", json.stringify("currency"), ":", json.stringify(c.currency), "}"], "")
              in_transaction(db, fn (tx :: Db) -> [sql, time] Result[Unit, Str] {
                match sql.exec(tx, "UPDATE treasuries SET committed_cents = ? WHERE company = ?", [PInt(new_committed), PStr(c.company)]) {
                  Err(e) => Err(e.message),
                  Ok(_) => match sql.exec(tx, "UPDATE commitments SET state = ? WHERE id = ?", [PStr(state_to_str(Released)), PStr(commitment_id)]) {
                    Err(e2) => Err(e2.message),
                    Ok(_) => match tlog.append(log, "treasury.released", None, payload) {
                      Err(e3) => Err(e3),
                      Ok(_) => Ok(()),
                    },
                  },
                }
              })
            },
          }
        },
      }
    },
  }
}

fn settle_commitment(db :: Db, log :: tlog.Log, commitment_id :: Str, paid_cents :: Int) -> [sql, time] Result[Unit, Str] {
  if paid_cents < 0 {
    Err("invalid_amount")
  } else {
    match get_commitment(db, commitment_id) {
      Err(e) => Err(e),
      Ok(None) => Err("no_such_commitment"),
      Ok(Some(c)) => {
        match c.state {
          Released => Err("not_reserved"),
          Settled => Err("not_reserved"),
          Reserved => {
            if paid_cents > c.amount_cents {
              Err("overpay")
            } else {
              match get_treasury(db, c.company) {
                Err(e) => Err(e),
                Ok(None) => Err("no_such_treasury"),
                Ok(Some(t)) => {
                  let new_balance := t.balance_cents - paid_cents
                  let new_committed := t.committed_cents - c.amount_cents
                  let payload := str.join(["{", json.stringify("company"), ":", json.stringify(c.company), ",", json.stringify("contract_id"), ":", json.stringify(c.contract_id), ",", json.stringify("commitment_id"), ":", json.stringify(commitment_id), ",", json.stringify("amount_cents"), ":", int.to_str(c.amount_cents), ",", json.stringify("paid_cents"), ":", int.to_str(paid_cents), ",", json.stringify("currency"), ":", json.stringify(c.currency), "}"], "")
                  in_transaction(db, fn (tx :: Db) -> [sql, time] Result[Unit, Str] {
                    match sql.exec(tx, "UPDATE treasuries SET balance_cents = ?, committed_cents = ? WHERE company = ?", [PInt(new_balance), PInt(new_committed), PStr(c.company)]) {
                      Err(e) => Err(e.message),
                      Ok(_) => match sql.exec(tx, "UPDATE commitments SET state = ? WHERE id = ?", [PStr(state_to_str(Settled)), PStr(commitment_id)]) {
                        Err(e2) => Err(e2.message),
                        Ok(_) => match tlog.append(log, "treasury.settled", None, payload) {
                          Err(e3) => Err(e3),
                          Ok(_) => Ok(()),
                        },
                      },
                    }
                  })
                },
              }
            }
          },
        }
      },
    }
  }
}

fn in_transaction[A](db :: Db, body :: (Db) -> [sql, time] Result[A, Str]) -> [sql, time] Result[A, Str] {
  match sql.exec(db, "BEGIN", []) {
    Err(e) => Err(e.message),
    Ok(_) => match body(db) {
      Err(e) => {
        let __lex_discard_1 := sql.exec(db, "ROLLBACK", [])
        Err(e)
      },
      Ok(v) => match sql.exec(db, "COMMIT", []) {
        Err(e) => Err(e.message),
        Ok(_) => Ok(v),
      },
    },
  }
}

