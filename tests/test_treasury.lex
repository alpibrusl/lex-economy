import "std.sql" as sql

import "std.str" as str

import "std.int" as int

import "lex-trail/log" as tlog

import "../src/treasury" as tr

fn with_db() -> [sql, fs_write] Result[{ db :: Db, log :: tlog.Log }, Str] {
  match sql.open(":memory:") {
    Err(e) => Err(e.message),
    Ok(db) => match tlog.attach(db, tlog.DbSqlite(())) {
      Err(e) => Err(e),
      Ok(log) => match tr.init_schema(db) {
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

fn test_available_cents() -> Bool
  examples {
    test_available_cents() => true
  }
{
  tr.available_cents({ company: "A", currency: "USD", balance_cents: 1000, committed_cents: 300 }) == 700 and tr.available_cents({ company: "B", currency: "USD", balance_cents: 500, committed_cents: 500 }) == 0 and tr.available_cents({ company: "C", currency: "USD", balance_cents: 0, committed_cents: 0 }) == 0
}

fn test_open_idempotent(db :: Db, log :: tlog.Log) -> [sql, time] Result[Unit, Str] {
  match tr.open_treasury(db, "IdemCo", "USD", 1000) {
    Err(e) => Err(e),
    Ok(_) => match tr.open_treasury(db, "IdemCo", "EUR", 9999) {
      Err(e) => Err(e),
      Ok(_) => match tr.get_treasury(db, "IdemCo") {
        Err(e) => Err(e),
        Ok(None) => Err("treasury missing after open"),
        Ok(Some(t)) => if t.currency != "USD" {
          Err("currency changed on idempotent open")
        } else {
          match assert_eq("idempotent balance", t.balance_cents, 1000) {
            Err(e) => Err(e),
            Ok(_) => assert_eq("idempotent committed", t.committed_cents, 0),
          }
        },
      },
    },
  }
}

fn test_commit_release(db :: Db, log :: tlog.Log) -> [sql, time] Result[Unit, Str] {
  match tr.open_treasury(db, "ReleaseCo", "USD", 500) {
    Err(e) => Err(e),
    Ok(_) => match tr.commit_funds(db, log, "ReleaseCo", "c-r1", "cm-r1", 200, "USD") {
      Err(e) => Err(e),
      Ok(c) => if c.state != tr.CommitReserved {
        Err("cm-r1 not Reserved")
      } else {
        match tr.get_treasury(db, "ReleaseCo") {
          Err(e) => Err(e),
          Ok(None) => Err("treasury missing"),
          Ok(Some(t)) => match assert_eq("balance after commit", t.balance_cents, 500) {
            Err(e) => Err(e),
            Ok(_) => match assert_eq("committed after commit", t.committed_cents, 200) {
              Err(e) => Err(e),
              Ok(_) => match tr.release_commitment(db, log, "cm-r1") {
                Err(e) => Err(e),
                Ok(_) => match tr.get_treasury(db, "ReleaseCo") {
                  Err(e) => Err(e),
                  Ok(None) => Err("treasury missing after release"),
                  Ok(Some(t2)) => match assert_eq("committed after release", t2.committed_cents, 0) {
                    Err(e) => Err(e),
                    Ok(_) => match tr.get_commitment(db, "cm-r1") {
                      Err(e) => Err(e),
                      Ok(None) => Err("commitment missing after release"),
                      Ok(Some(c2)) => if c2.state != tr.CommitReleased {
                        Err("cm-r1 not Released")
                      } else {
                        match tr.release_commitment(db, log, "cm-r1") {
                          Ok(_) => Err("should not release twice"),
                          Err("not_reserved") => match tr.commit_funds(db, log, "ReleaseCo", "c-r2", "cm-r2", 500, "USD") {
                            Err(e) => Err(e),
                            Ok(_) => match tr.commit_funds(db, log, "ReleaseCo", "c-r3", "cm-r3", 1, "USD") {
                              Ok(_) => Err("should be insufficient funds"),
                              Err("insufficient_funds") => match tr.release_commitment(db, log, "cm-r2") {
                                Err(e) => Err(e),
                                Ok(_) => match tr.get_treasury(db, "ReleaseCo") {
                                  Err(e) => Err(e),
                                  Ok(None) => Err("treasury missing"),
                                  Ok(Some(t3)) => assert_eq("committed after full release", t3.committed_cents, 0),
                                },
                              },
                              Err(e) => Err(str.concat("unexpected insufficient_funds error: ", e)),
                            },
                          },
                          Err(e) => Err(str.concat("unexpected not_reserved error: ", e)),
                        }
                      },
                    },
                  },
                },
              },
            },
          },
        }
      },
    },
  }
}

fn test_settle_partial_and_overpay(db :: Db, log :: tlog.Log) -> [sql, time] Result[Unit, Str] {
  match tr.open_treasury(db, "SettleCo", "USD", 1000) {
    Err(e) => Err(e),
    Ok(_) => match tr.commit_funds(db, log, "SettleCo", "c-s1", "cm-s1", 400, "USD") {
      Err(e) => Err(e),
      Ok(_) => match tr.settle_commitment(db, log, "cm-s1", 250) {
        Err(e) => Err(e),
        Ok(_) => match tr.get_treasury(db, "SettleCo") {
          Err(e) => Err(e),
          Ok(None) => Err("treasury missing"),
          Ok(Some(t)) => match assert_eq("balance after partial settle", t.balance_cents, 750) {
            Err(e) => Err(e),
            Ok(_) => match assert_eq("committed after partial settle", t.committed_cents, 0) {
              Err(e) => Err(e),
              Ok(_) => match tr.get_commitment(db, "cm-s1") {
                Err(e) => Err(e),
                Ok(None) => Err("commitment missing"),
                Ok(Some(c)) => if c.state != tr.CommitSettled {
                  Err("cm-s1 not Settled")
                } else {
                  match tr.open_treasury(db, "OverpayCo", "USD", 1000) {
                    Err(e) => Err(e),
                    Ok(_) => match tr.commit_funds(db, log, "OverpayCo", "c-s2", "cm-s2", 300, "USD") {
                      Err(e) => Err(e),
                      Ok(_) => match tr.settle_commitment(db, log, "cm-s2", 301) {
                        Ok(_) => Err("should fail overpay"),
                        Err("overpay") => match tr.get_treasury(db, "OverpayCo") {
                          Err(e) => Err(e),
                          Ok(None) => Err("treasury missing"),
                          Ok(Some(t2)) => match assert_eq("balance after overpay fail", t2.balance_cents, 1000) {
                            Err(e) => Err(e),
                            Ok(_) => match assert_eq("committed after overpay fail", t2.committed_cents, 300) {
                              Err(e) => Err(e),
                              Ok(_) => match tr.get_commitment(db, "cm-s2") {
                                Err(e) => Err(e),
                                Ok(None) => Err("commitment missing"),
                                Ok(Some(c2)) => if c2.state != tr.CommitReserved {
                                  Err("cm-s2 changed state on overpay fail")
                                } else {
                                  match tr.settle_commitment(db, log, "cm-s2", -1) {
                                    Ok(_) => Err("should fail negative paid"),
                                    Err("invalid_amount") => match tr.get_treasury(db, "OverpayCo") {
                                      Err(e) => Err(e),
                                      Ok(None) => Err("treasury missing"),
                                      Ok(Some(t3)) => match assert_eq("balance after negative paid fail", t3.balance_cents, 1000) {
                                        Err(e) => Err(e),
                                        Ok(_) => assert_eq("committed after negative paid fail", t3.committed_cents, 300),
                                      },
                                    },
                                    Err(e) => Err(str.concat("unexpected negative paid error: ", e)),
                                  }
                                },
                              },
                            },
                          },
                        },
                        Err(e) => Err(str.concat("unexpected overpay error: ", e)),
                      },
                    },
                  }
                },
              },
            },
          },
        },
      },
    },
  }
}

fn test_error_paths(db :: Db, log :: tlog.Log) -> [sql, time] Result[Unit, Str] {
  match tr.open_treasury(db, "ErrorCo", "USD", 1000) {
    Err(e) => Err(e),
    Ok(_) => match tr.commit_funds(db, log, "MissingCo", "c-1", "cm-missing", 100, "USD") {
      Ok(_) => Err("should fail no_such_treasury"),
      Err("no_such_treasury") => match tr.commit_funds(db, log, "ErrorCo", "c-2", "cm-currency", 100, "EUR") {
        Ok(_) => Err("should fail currency_mismatch"),
        Err("currency_mismatch") => match tr.commit_funds(db, log, "ErrorCo", "c-3", "cm-zero", 0, "USD") {
          Ok(_) => Err("should fail invalid_amount"),
          Err("invalid_amount") => match tr.get_treasury(db, "GhostCo") {
            Err(e) => Err(e),
            Ok(Some(_)) => Err("ghost treasury found"),
            Ok(None) => match tr.get_commitment(db, "cm-ghost") {
              Err(e) => Err(e),
              Ok(Some(_)) => Err("ghost commitment found"),
              Ok(None) => match tr.release_commitment(db, log, "cm-ghost") {
                Ok(_) => Err("should fail no_such_commitment on release"),
                Err("no_such_commitment") => match tr.settle_commitment(db, log, "cm-ghost", 100) {
                  Ok(_) => Err("should fail no_such_commitment on settle"),
                  Err("no_such_commitment") => match tr.get_treasury(db, "ErrorCo") {
                    Err(e) => Err(e),
                    Ok(None) => Err("treasury missing"),
                    Ok(Some(t)) => match assert_eq("error path balance", t.balance_cents, 1000) {
                      Err(e) => Err(e),
                      Ok(_) => assert_eq("error path committed", t.committed_cents, 0),
                    },
                  },
                  Err(e) => Err(str.concat("unexpected settle missing error: ", e)),
                },
                Err(e) => Err(str.concat("unexpected release missing error: ", e)),
              },
            },
          },
          Err(e) => Err(str.concat("unexpected invalid_amount error: ", e)),
        },
        Err(e) => Err(str.concat("unexpected currency_mismatch error: ", e)),
      },
      Err(e) => Err(str.concat("unexpected no_such_treasury error: ", e)),
    },
  }
}

fn run_all() -> [sql, fs_write, time] Result[Unit, Str] {
  if not test_available_cents() {
    Err("test_available_cents failed")
  } else {
    match with_db() {
      Err(e) => Err(e),
      Ok(ctx) => {
        let db := ctx.db
        let log := ctx.log
        match test_open_idempotent(db, log) {
          Err(e) => Err(e),
          Ok(_) => match test_commit_release(db, log) {
            Err(e) => Err(e),
            Ok(_) => match test_settle_partial_and_overpay(db, log) {
              Err(e) => Err(e),
              Ok(_) => test_error_paths(db, log),
            },
          },
        }
      },
    }
  }
}

