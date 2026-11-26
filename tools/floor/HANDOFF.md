# Current handoff — 26 Nov 2026, evening

## What this window did

Nine jobs landed on GitHub and all of them are on master `c49f6d7`.

1. The witness went silent after an upgrade — a picture taken before the schema
   column existed could never be a comparison baseline. One line.
2. Three migrations died on install because their self-checks called a door with
   nobody signed in. Copied the pattern from the one file that did it right.
3. A self-check handed a door a watched-database id where a repo-link id belongs.
4. A file proved itself by calling a function that a *later* file creates.
5. `one_run_test` did the same, and was also creating its repo link after the job
   that needed it.
6. **The witness could not prove a function at all.** The comparison wrote the
   name with its argument list; a claim never carries one; so they never matched
   and every added or deleted function read "no proof". This was the big one.
7. `one_run_test` was marking its own homework: it photographed a schema called
   "BEFORE" that does not exist, never compared the two pictures, and
   hand-inserted the proof rows it then checked for. Now it runs the real doors.
8. `whole_run_test` had the same disease, plus it photographed the watched schema
   one step before creating it.
9. Re-judging a picture erased the comparison a finished job cites as its proof.
   Now refused.

Plus a new door, `job_repo_link_set`, so a job opened without a code link can be
given one — previously impossible, which left its DELIVERED lines unprovable
forever.

## The standing order that came out of today

Waqar's words: an empty database, a full database, all kinds of database.
Nothing passes unless it runs in a brand new empty database *and* in one that
already has rows, and the proof it prints comes from that run, not from anything
lying around. Both tests were passing on his own database for weeks while being
broken, because leftovers covered the holes.

## What the next window does

`floor/PLAN-wall-and-door.md`, job 1. The plan is cold-read and clean. One job at
a time, each proved in an empty database before it is handed to Code.

## Two traps that cost time today

- Code **cannot run git**. A floor hook refuses it and it reports success
  anyway. Ask it for file proofs only.
- Do not write into the working tree while a builder job is alive. Two unrelated
  changes landed in one commit that way.
