# Plan — keep customers apart, then let a browser in

Database: **mfysxqhediepzohzhufp**, schema `guardops`. Not the old floor.

Cold-read by Code on 26 Nov (report: board 12114). Jobs 1–3 came back clean on
all six questions. Job 4 came back with a real hole, now written in below as its
own job. Order is not negotiable.

## Why

Only the master key reaches GuardOps today. Every "is this row yours" check
lives inside the doors; the database itself enforces nothing. Nothing outside
the database can call anything, so the sign-up screens have nothing to talk to —
and we cannot let them talk to it until separation is enforced by the database
rather than by our own care.

## The one design decision

A rule must never raise. If a rule called `current_account()` every query by a
signed-out caller would ERROR instead of quietly returning nothing, and an error
leaks the shape of what is behind it. So job 1 adds a companion that returns
NULL instead of raising, and every rule keys off that. NULL means no rows — the
safe default. `current_account()` itself is not touched: the doors must keep
refusing loudly.

## Job 1 — a way to ask "who is signed in?" that answers nobody

`guardops.current_account_or_null()`. Same verification as the live
`current_account()` — same `guardops.house` setting, same signature check
against the same checker secret — but returns NULL instead of raising when the
setting is absent, empty, malformed or fails the signature. STABLE, SECURITY
DEFINER, empty search_path, revoked from PUBLIC/anon/authenticated, granted to
service_role.

**Read the live `current_account()` body and mirror it. Do not write it from a
description.** Its own rolled-back proof: signed out returns NULL, a forged
setting returns NULL, a real `act_as_house` returns that account, and it raises
in none of the three.

## Job 2 — turn the wall on

One migration.

- The **17 tables carrying `account_id`** — claim, commit_drift, commit_object,
  commit_seen, connected_account, customer, customer_notice, job, plan_given,
  pull_commit, repo_link, repo_pull, shape_change, shape_object, shape_picture,
  watched_database, write_record: `ENABLE ROW LEVEL SECURITY`, then one policy
  each, `FOR ALL`, `USING (account_id = guardops.current_account_or_null())`
  `WITH CHECK (account_id = guardops.current_account_or_null())`.
- **`account`** carries no `account_id` — its own id *is* the tenant key:
  `USING (id = guardops.current_account_or_null())`, same for WITH CHECK.
- **`checker_key`** is left exactly as it is: row security already on, zero
  rules, which denies every non-bypass role.
- **No table grant is added anywhere.** A browser must never reach a table, only
  a door.

Confirmed by the cold read: every door is SECURITY DEFINER owned by postgres, so
the doors bypass these rules and keep working; the three `plan_given` triggers
fire before the row and are unaffected; one `FOR ALL` policy is right and no
table needs a SELECT/write split.

## Job 3 — the test that makes it real

The only reason to believe any of the above. One new function, one rolled-back
block, numbered rows with pass true/false in the same shape as `one_run_test`:

1. Sign in as customer A, write a job and a plan row.
2. Sign in as customer B.
3. `SET LOCAL ROLE authenticated` and try to read A's rows, table by table —
   every count must be **zero**.
4. Prove a direct `SELECT` as authenticated is refused outright for want of a
   grant.
5. Sign back in as A and prove A still sees A's own rows — the wall must not
   lock the owner out.

## Job 4 — bind a caller to their own customer

**Found by the cold read. This must land before any grant is given.**

`verdict_for_customer(p_customer, p_job_id)` calls `act_as_house(p_customer)`
with no check that the caller *is* that customer. `act_as_house` only checks the
customer exists and has an ACTIVE connected account. The door is SECURITY
DEFINER and bypasses the wall, so job 2 does not help. The moment
`authenticated` can execute it, any signed-in person could pass any customer id
and read that customer's jobs.

The fix: `act_as_house` must check the Supabase auth subject against the
customer before it sets the house — `auth.uid()` against the customer's
`external_id`. Its own test: a caller signed in as A asking for B is refused.

## Job 5 — open the way in

`GRANT EXECUTE` to `authenticated` on exactly three doors and nothing else:
`house_from_signin`, `job_verdict`, `verdict_for_customer`. Extend job 3's test
with a row proving a fourth door — `watched_database_add` — is still refused.

## Order

1 → 2 → 3 → 4 → 5. If 2 ran before 1 the policy creation fails, the function
does not exist yet. If 5 ran before 2, authenticated could read every row. If 5
ran before 4, any customer could read any other customer's verdict.

## Out of scope, flagged by the cold read

`shape_watch` calls `take_shape` with one argument; the live signature takes
two. It fails at runtime. Pre-existing, not introduced here.
