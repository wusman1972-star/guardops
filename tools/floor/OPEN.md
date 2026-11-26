# What is open

Short and honest. The old database holds hundreds of logged holes; most are
about gate-era machinery that no longer exists. They are not carried here.
Sorting the recent ones, one by one against the current code, is its own job and
has not been done yet.

## Known true today, in the product

- **No way in.** `anon` and `authenticated` can execute none of the 50 doors and
  hold no table grant. Nothing outside the database can reach anything. This is
  what the wall-and-door plan fixes.
- **Separation is not enforced by the database.** Row security is on for one
  table only (`checker_key`, with no rule, which denies everything). Every
  "is this row yours" check lives inside the doors. Job 2 of the plan fixes it.
- **`shape_watch` is a dead door.** It calls `take_shape` with one argument; the
  live signature takes two. It fails at runtime. Not yet fixed.
- **`verdict_for_customer` trusts its argument.** It signs in as whatever
  customer id it is handed, with no check that the caller is that customer.
  Harmless while only the master key can call it; a cross-tenant hole the moment
  a browser can. Closed by job 4 of the plan, before any grant is given.
- **An empty sha claim can make the witness confirm a lie.** `claim_vs_git`
  reads it as a prefix, matches every commit, and answers "found". Not yet fixed.
- **`commit_record` reads `commit_seen` without a row lock,** so two walks of the
  same commit can overwrite a patch and silence the drift bell. Not yet fixed.
- **The Desktop scripts are not the repo scripts.** `Code.bat` and
  `cr_review.bat` on the Desktop differ from the copies in `buildline/`. A fix to
  the repo copy changes nothing about what actually runs. `severity_gate.ps1` is
  the exception — `Code.bat` calls the repo copy of that one.

## Not a fault, so stop re-reporting it

- `0035_pg_net.sql` fails on plain Postgres. `pg_net` is Supabase-only and the
  file works on the real project. The install is green at 87 of 88.
