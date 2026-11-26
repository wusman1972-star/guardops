# START HERE

Every window reads this file first. It lives in the repo, not in a database.

## Which database is which

- **mfysxqhediepzohzhufp — the product.** Schema `guardops`, 19 tables. This is
  GuardOps. Everything we build goes here.
- **lauttgnmksnxohigaqee — dead history.** The old floor, 71 gate-era tables.
  Nothing reads it and nothing writes to it. It is kept only in case something
  old is ever wanted. If a plan or a job does not name a project, it means the
  product one.

A whole cold read was wasted on 26 Nov because a plan did not name its database.
Name it on everything.

## Chain of command

1. Waqar decides what gets built and in what order.
2. The talk window plans it, writes the plan down, and has Code cold-read the
   plan before anything is built.
3. Code builds one problem at a time, from one board, and proves it with file
   proofs. Code cannot run git — a board that asks it for a git proof comes back
   done having done nothing.
4. CodeRabbit reviews. Critical and Major hold the merge; Minor and below are
   logged and the job moves.
5. The loop commits, reviews and pushes. A job is finished when GitHub's own
   answer shows it on master — never when a report says so.

## How anything is proved

Install from GitHub master into a **brand new empty Postgres 16**, every
migration in order, then both self-tests — and then a **second run in the same,
now non-empty, database**. Nothing counts unless it holds both times.

## Where we are — 26 Nov 2026

Master `c49f6d7`. Install 87 of 88. The one failure, `0035_pg_net.sql`, needs the
Supabase-only `pg_net` extension and is not a fault.

- `one_run_test` — 8 of 8, twice.
- `whole_run_test` — 12 of 12, twice.
- Both now prove themselves from pictures each run actually takes. They used to
  hand-write their own proof rows and read green on a database full of leftovers.

All three CodeRabbit findings of 26 Nov are closed, and so is the install fault.

## What is next

`floor/PLAN-wall-and-door.md` — five jobs, in order, one at a time. That plan is
everything standing between here and a pilot.
