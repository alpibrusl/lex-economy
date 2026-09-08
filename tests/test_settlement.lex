import "std.sql" as sql

import "std.str" as str

import "std.int" as int

import "lex-trail/log" as tlog

import "../src/treasury" as treasury

import "../src/contract" as contract

import "../src/request_bid" as request_bid

import "../src/settlement" as settlement

fn with_db() -> [sql, fs_write] Result[{ db :: Db, log :: tlog.Log }, Str] {
  match sql.open(":memory:") {
    Err(e) => Err(e.message),
    Ok(db) => match tlog.attach(db, tlog.DbSqlite(())) {
      Err(e) => Err(e),
      Ok(log) => match treasury.init_schema(db) {
        Err(e) => Err(e),
        Ok(_) => Ok({ db: db, log: log }),
      },
    },
  }
}

fn assert_eq(label :: Str, got :: Int, want :: Int) -> Result[Unit, Str] {
  if got == want {
    Ok(())
  } else {
    Err(str.concat(label, str.concat(": got ", str.concat(int.to_str(got), str.concat(" want ", int.to_str(want))))))
  }
}

fn sample_request(id :: Str, buyer :: Str) -> request_bid.WorkRequest {
  { id: id, buyer: buyer, capability: "plumbing", description: "fix leak", budget_ceiling: { cents: 100000, currency: "USD" }, criteria: [], deadline_ms: 999999, state: request_bid.ReqOpen }
}

fn sample_bid(id :: Str, request_id :: Str, supplier :: Str, cents :: Int, state :: request_bid.BidState) -> request_bid.Bid {
  { id: id, request_id: request_id, supplier: supplier, price: { cents: cents, currency: "USD" }, message: "", state: state }
}

fn sample_contract(id :: Str, buyer :: Str, supplier :: Str, cents :: Int, state :: contract.ContractState) -> contract.Contract {
  { id: id, buyer: buyer, supplier: supplier, price: { cents: cents, currency: "USD" }, state: state }
}

fn test_open_contract_success(db :: Db, log :: tlog.Log) -> [sql, time] Result[Unit, Str] {
  match treasury.open_treasury(db, "Buyer1", "USD", 100000) {
    Err(e) => Err(e),
    Ok(_) => {
      let request := sample_request("req-1", "Buyer1")
      let bid := sample_bid("bid-1", "req-1", "Supplier1", 40000, request_bid.BidAccepted)
      match settlement.open_contract(db, log, request, bid, "contract-1", "commit-1") {
        Err(e) => Err(e),
        Ok(c) => if c.buyer != "Buyer1" {
          Err("wrong buyer")
        } else {
          if c.supplier != "Supplier1" {
            Err("wrong supplier")
          } else {
            if c.state != contract.Awarded {
              Err("contract not Awarded")
            } else {
              match treasury.get_treasury(db, "Buyer1") {
                Err(e) => Err(e),
                Ok(None) => Err("treasury missing"),
                Ok(Some(t)) => assert_eq("committed after open_contract", t.committed_cents, 40000),
              }
            }
          }
        },
      }
    },
  }
}

fn test_open_contract_bid_not_accepted(db :: Db, log :: tlog.Log) -> [sql, time] Result[Unit, Str] {
  match treasury.open_treasury(db, "Buyer2", "USD", 100000) {
    Err(e) => Err(e),
    Ok(_) => {
      let request := sample_request("req-2", "Buyer2")
      let bid := sample_bid("bid-2", "req-2", "Supplier2", 10000, request_bid.BidSubmitted)
      match settlement.open_contract(db, log, request, bid, "contract-2", "commit-2") {
        Ok(_) => Err("should fail bid_not_accepted"),
        Err("bid_not_accepted") => match treasury.get_treasury(db, "Buyer2") {
          Err(e) => Err(e),
          Ok(None) => Err("treasury missing"),
          Ok(Some(t)) => assert_eq("committed unchanged on bid_not_accepted", t.committed_cents, 0),
        },
        Err(e) => Err(str.concat("unexpected bid_not_accepted error: ", e)),
      }
    },
  }
}

fn test_open_contract_request_mismatch(db :: Db, log :: tlog.Log) -> [sql, time] Result[Unit, Str] {
  match treasury.open_treasury(db, "Buyer3", "USD", 100000) {
    Err(e) => Err(e),
    Ok(_) => {
      let request := sample_request("req-3", "Buyer3")
      let bid := sample_bid("bid-3", "other-req", "Supplier3", 10000, request_bid.BidAccepted)
      match settlement.open_contract(db, log, request, bid, "contract-3", "commit-3") {
        Ok(_) => Err("should fail bid_request_mismatch"),
        Err("bid_request_mismatch") => match treasury.get_treasury(db, "Buyer3") {
          Err(e) => Err(e),
          Ok(None) => Err("treasury missing"),
          Ok(Some(t)) => assert_eq("committed unchanged on bid_request_mismatch", t.committed_cents, 0),
        },
        Err(e) => Err(str.concat("unexpected bid_request_mismatch error: ", e)),
      }
    },
  }
}

fn test_open_contract_insufficient_funds(db :: Db, log :: tlog.Log) -> [sql, time] Result[Unit, Str] {
  match treasury.open_treasury(db, "Buyer4", "USD", 1000) {
    Err(e) => Err(e),
    Ok(_) => {
      let request := sample_request("req-4", "Buyer4")
      let bid := sample_bid("bid-4", "req-4", "Supplier4", 999999, request_bid.BidAccepted)
      match settlement.open_contract(db, log, request, bid, "contract-4", "commit-4") {
        Ok(_) => Err("should fail insufficient_funds"),
        Err("insufficient_funds") => match treasury.get_treasury(db, "Buyer4") {
          Err(e) => Err(e),
          Ok(None) => Err("treasury missing"),
          Ok(Some(t)) => assert_eq("committed unchanged on insufficient_funds", t.committed_cents, 0),
        },
        Err(e) => Err(str.concat("unexpected insufficient_funds error: ", e)),
      }
    },
  }
}

fn test_settle_fulfilled(db :: Db, log :: tlog.Log) -> [sql, time] Result[Unit, Str] {
  match treasury.open_treasury(db, "Buyer5", "USD", 100000) {
    Err(e) => Err(e),
    Ok(_) => match treasury.commit_funds(db, log, "Buyer5", "contract-5", "commit-5", 30000, "USD") {
      Err(e) => Err(e),
      Ok(_) => {
        let c := sample_contract("contract-5", "Buyer5", "Supplier5", 30000, contract.Verified(contract.Fulfilled))
        match settlement.settle_contract(db, log, c, "commit-5", 30000) {
          Err(e) => Err(e),
          Ok(settled) => if settled.state != contract.Settled {
            Err("contract not Settled")
          } else {
            match treasury.get_treasury(db, "Buyer5") {
              Err(e) => Err(e),
              Ok(None) => Err("treasury missing"),
              Ok(Some(t)) => match assert_eq("balance after fulfilled settle", t.balance_cents, 70000) {
                Err(e) => Err(e),
                Ok(_) => assert_eq("committed after fulfilled settle", t.committed_cents, 0),
              },
            }
          },
        }
      },
    },
  }
}

fn test_settle_partially_fulfilled(db :: Db, log :: tlog.Log) -> [sql, time] Result[Unit, Str] {
  match treasury.open_treasury(db, "Buyer6", "USD", 100000) {
    Err(e) => Err(e),
    Ok(_) => match treasury.commit_funds(db, log, "Buyer6", "contract-6", "commit-6", 20000, "USD") {
      Err(e) => Err(e),
      Ok(_) => {
        let c := sample_contract("contract-6", "Buyer6", "Supplier6", 20000, contract.Verified(contract.PartiallyFulfilled(["license"])))
        match settlement.settle_contract(db, log, c, "commit-6", 12000) {
          Err(e) => Err(e),
          Ok(settled) => if settled.state != contract.Settled {
            Err("contract not Settled")
          } else {
            match treasury.get_treasury(db, "Buyer6") {
              Err(e) => Err(e),
              Ok(None) => Err("treasury missing"),
              Ok(Some(t)) => match assert_eq("balance after partial settle", t.balance_cents, 88000) {
                Err(e) => Err(e),
                Ok(_) => assert_eq("committed after partial settle", t.committed_cents, 0),
              },
            }
          },
        }
      },
    },
  }
}

fn test_settle_rejected(db :: Db, log :: tlog.Log) -> [sql, time] Result[Unit, Str] {
  match treasury.open_treasury(db, "Buyer7", "USD", 100000) {
    Err(e) => Err(e),
    Ok(_) => match treasury.commit_funds(db, log, "Buyer7", "contract-7", "commit-7", 15000, "USD") {
      Err(e) => Err(e),
      Ok(_) => {
        let c := sample_contract("contract-7", "Buyer7", "Supplier7", 15000, contract.Verified(contract.Rejected(["quality"])))
        match settlement.settle_contract(db, log, c, "commit-7", 0) {
          Err(e) => Err(e),
          Ok(disputed) => if disputed.state != contract.Disputed {
            Err("contract not Disputed")
          } else {
            match treasury.get_treasury(db, "Buyer7") {
              Err(e) => Err(e),
              Ok(None) => Err("treasury missing"),
              Ok(Some(t)) => match assert_eq("balance unchanged on rejected settle", t.balance_cents, 100000) {
                Err(e) => Err(e),
                Ok(_) => assert_eq("committed released on rejected settle", t.committed_cents, 0),
              },
            }
          },
        }
      },
    },
  }
}

fn test_settle_rejected_nonzero_pay_fails(db :: Db, log :: tlog.Log) -> [sql, time] Result[Unit, Str] {
  match treasury.open_treasury(db, "Buyer8", "USD", 100000) {
    Err(e) => Err(e),
    Ok(_) => match treasury.commit_funds(db, log, "Buyer8", "contract-8", "commit-8", 15000, "USD") {
      Err(e) => Err(e),
      Ok(_) => {
        let c := sample_contract("contract-8", "Buyer8", "Supplier8", 15000, contract.Verified(contract.Rejected(["quality"])))
        match settlement.settle_contract(db, log, c, "commit-8", 1) {
          Ok(_) => Err("should fail rejected_verdict_cannot_pay"),
          Err("rejected_verdict_cannot_pay") => match treasury.get_treasury(db, "Buyer8") {
            Err(e) => Err(e),
            Ok(None) => Err("treasury missing"),
            Ok(Some(t)) => match assert_eq("balance unchanged on rejected nonzero pay", t.balance_cents, 100000) {
              Err(e) => Err(e),
              Ok(_) => assert_eq("committed unchanged on rejected nonzero pay", t.committed_cents, 15000),
            },
          },
          Err(e) => Err(str.concat("unexpected rejected_verdict_cannot_pay error: ", e)),
        }
      },
    },
  }
}

fn test_settle_ambiguous_refuses(db :: Db, log :: tlog.Log) -> [sql, time] Result[Unit, Str] {
  match treasury.open_treasury(db, "Buyer9", "USD", 100000) {
    Err(e) => Err(e),
    Ok(_) => match treasury.commit_funds(db, log, "Buyer9", "contract-9", "commit-9", 15000, "USD") {
      Err(e) => Err(e),
      Ok(_) => {
        let c := sample_contract("contract-9", "Buyer9", "Supplier9", 15000, contract.Verified(contract.Ambiguous(["scope"])))
        match settlement.settle_contract(db, log, c, "commit-9", 0) {
          Ok(_) => Err("should fail ambiguous_verdict_needs_arbitration"),
          Err("ambiguous_verdict_needs_arbitration") => match treasury.get_treasury(db, "Buyer9") {
            Err(e) => Err(e),
            Ok(None) => Err("treasury missing"),
            Ok(Some(t)) => match assert_eq("balance untouched on ambiguous", t.balance_cents, 100000) {
              Err(e) => Err(e),
              Ok(_) => match assert_eq("committed untouched on ambiguous", t.committed_cents, 15000) {
                Err(e) => Err(e),
                Ok(_) => match treasury.get_commitment(db, "commit-9") {
                  Err(e) => Err(e),
                  Ok(None) => Err("commitment missing"),
                  Ok(Some(cm)) => if cm.state != treasury.CommitReserved {
                    Err("commitment state changed on ambiguous")
                  } else {
                    Ok(())
                  },
                },
              },
            },
          },
          Err(e) => Err(str.concat("unexpected ambiguous error: ", e)),
        }
      },
    },
  }
}

fn test_settle_not_verified(db :: Db, log :: tlog.Log) -> [sql, time] Result[Unit, Str] {
  match treasury.open_treasury(db, "Buyer10", "USD", 100000) {
    Err(e) => Err(e),
    Ok(_) => match treasury.commit_funds(db, log, "Buyer10", "contract-10", "commit-10", 5000, "USD") {
      Err(e) => Err(e),
      Ok(_) => {
        let c := sample_contract("contract-10", "Buyer10", "Supplier10", 5000, contract.Awarded)
        match settlement.settle_contract(db, log, c, "commit-10", 5000) {
          Ok(_) => Err("should fail not_verified"),
          Err("not_verified") => match treasury.get_treasury(db, "Buyer10") {
            Err(e) => Err(e),
            Ok(None) => Err("treasury missing"),
            Ok(Some(t)) => assert_eq("committed unchanged on not_verified", t.committed_cents, 5000),
          },
          Err(e) => Err(str.concat("unexpected not_verified error: ", e)),
        }
      },
    },
  }
}

fn run_all() -> [sql, fs_write, time] Result[Unit, Str] {
  match with_db() {
    Err(e) => Err(e),
    Ok(ctx) => {
      let db := ctx.db
      let log := ctx.log
      match test_open_contract_success(db, log) {
        Err(e) => Err(e),
        Ok(_) => match test_open_contract_bid_not_accepted(db, log) {
          Err(e) => Err(e),
          Ok(_) => match test_open_contract_request_mismatch(db, log) {
            Err(e) => Err(e),
            Ok(_) => match test_open_contract_insufficient_funds(db, log) {
              Err(e) => Err(e),
              Ok(_) => match test_settle_fulfilled(db, log) {
                Err(e) => Err(e),
                Ok(_) => match test_settle_partially_fulfilled(db, log) {
                  Err(e) => Err(e),
                  Ok(_) => match test_settle_rejected(db, log) {
                    Err(e) => Err(e),
                    Ok(_) => match test_settle_rejected_nonzero_pay_fails(db, log) {
                      Err(e) => Err(e),
                      Ok(_) => match test_settle_ambiguous_refuses(db, log) {
                        Err(e) => Err(e),
                        Ok(_) => test_settle_not_verified(db, log),
                      },
                    },
                  },
                },
              },
            },
          },
        },
      }
    },
  }
}

