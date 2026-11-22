#!/usr/bin/env node
// check_all_clean.mjs  (board 4075, relocated board 4225)
//
// Lives OUTSIDE the repository so branch changes cannot remove it.
// Repo and door paths are hardcoded; no relative __dirname resolution.
//
// Checks that every migration file changed on this branch has a clean verdict
// (critical_count=0, major_count=0) in guardops.migration_review at the file's
// CURRENT blob SHA (from git hash-object).
//
// A file is clean when:
//   - At least one migration_review row exists for it at the current blob SHA, AND
//   - That row has critical_count=0 AND major_count=0.
//
// A file is dirty when it has a row at the current blob SHA but with findings.
// A file is unreviewed when no row at the current blob SHA exists at all.
//
// Exit 0 = all files clean.  Exit 1 = any file dirty or unreviewed.
// Stdout names the dirty/unreviewed files so Code.bat can include them in the
// board report.

import { readFileSync } from 'node:fs';
import { execFileSync, spawnSync } from 'node:child_process';
import { join } from 'node:path';

const repo = 'C:\\Users\\T480\\Desktop\\flowops-guardops-sql';
const door = 'C:\\Users\\T480\\Desktop\\gops_tools\\door.mjs';

process.stdout.write(`check_all_clean: running from ${new URL(import.meta.url).pathname}\n`);

function runDoor(sql, params) {
  const args = params !== undefined
    ? [door, sql, JSON.stringify(params)]
    : [door, sql];
  const r = spawnSync(process.execPath, args, { stdio: ['ignore', 'pipe', 'pipe'], cwd: repo });
  if (r.error) throw new Error(`door spawn: ${r.error.message}`);
  const out = r.stdout.toString().trim();
  const err = r.stderr.toString().trim();
  if (r.status !== 0) throw new Error(`door exit ${r.status}: ${err || out}`);
  const reply = JSON.parse(out);
  if (!reply.ok) throw new Error(`door refused: ${reply.error}`);
  return reply.rows;
}

// ── find base commit: previous "job commit" before current board's work ──
// The most recent "job commit" = current board's start commit.
// The one before it = where the previous board ended = our diff base.
// This scopes the gate to only the files the current job changed
// (law 205 REVIEW_COVERS_THE_CHANGE_NOT_THE_COMMIT — board 4205).
let baseRef = null;
let baseFallback = 'origin/board-3684-local-cli-run-gate';
try {
  const lines = readFileSync(join(repo, 'tools', 'cr_last.txt'), 'utf8').split('\n');
  for (const line of lines) {
    try {
      const obj = JSON.parse(line);
      if (obj.type === 'review_context' && obj.baseBranch) {
        baseFallback = obj.baseBranch;
        break;
      }
    } catch {}
  }
} catch {}

try {
  const jobCommits = execFileSync(
    'git', ['log', '--format=%H', '--grep', 'job commit', 'HEAD'],
    { cwd: repo }
  ).toString().trim().split('\n').filter(Boolean);
  if (jobCommits.length >= 2) {
    baseRef = jobCommits[1]; // previous board's job commit
  } else if (jobCommits.length === 1) {
    baseRef = jobCommits[0] + '^'; // parent of the only job commit
  }
} catch (e) {
  process.stderr.write(`check_all_clean: could not find previous job commit: ${e.message}\n`);
}

const diffBase = baseRef ?? baseFallback;

// ── get all migration files that need a clean verdict ─────────────────────
// 1. Committed changes in this job (since previous job commit)
let diffOut = '';
try {
  diffOut = execFileSync(
    'git', ['diff', `${diffBase}...HEAD`, '--name-only', '--', 'migrations/*.sql'],
    { cwd: repo }
  ).toString().trim();
} catch (e) {
  process.stderr.write(`check_all_clean: git diff failed: ${e.message}\n`);
  process.exit(1);
}

const changedSet = new Set(diffOut ? diffOut.split('\n').filter(Boolean) : []);

// 2. Staged changes (index vs HEAD)
try {
  const staged = execFileSync(
    'git', ['diff', '--cached', '--name-only', '--', 'migrations/*.sql'],
    { cwd: repo }
  ).toString().trim();
  if (staged) staged.split('\n').filter(Boolean).forEach(f => changedSet.add(f));
} catch {}

// 3. Unstaged changes (working tree vs index)
try {
  const unstaged = execFileSync(
    'git', ['diff', '--name-only', '--', 'migrations/*.sql'],
    { cwd: repo }
  ).toString().trim();
  if (unstaged) unstaged.split('\n').filter(Boolean).forEach(f => changedSet.add(f));
} catch {}

// 4. Untracked migration files
try {
  const untracked = execFileSync(
    'git', ['ls-files', '--others', '--exclude-standard', '--', 'migrations/'],
    { cwd: repo }
  ).toString().trim();
  if (untracked) {
    untracked.split('\n')
      .filter(f => f && /^migrations\/\d+_[A-Za-z0-9_-]+\.sql$/.test(f))
      .forEach(f => changedSet.add(f));
  }
} catch {}

const changedFiles = [...changedSet];

if (changedFiles.length === 0) {
  process.stdout.write('check_all_clean: no migration files changed in this job\n');
  process.exit(0);
}

process.stdout.write(
  `check_all_clean: judging ${changedFiles.length} file(s) changed in this job:\n` +
  changedFiles.map(f => `  ${f}`).join('\n') + '\n'
);

// ── check each file ───────────────────────────────────────────────────────
const clean      = [];
const dirty      = [];
const unreviewed = [];

for (const rawFile of changedFiles) {
  const fileName = rawFile.replace(/^migrations\//, '');
  if (!/^\d+_[A-Za-z0-9_-]+\.sql$/.test(fileName)) {
    unreviewed.push(fileName + ' [unsupported name format]');
    continue;
  }

  // Current blob SHA (working-tree content).
  let fileSha;
  try {
    fileSha = execFileSync('git', ['hash-object', rawFile], { cwd: repo })
      .toString().trim();
  } catch {
    unreviewed.push(fileName + ' [file missing]');
    continue;
  }

  const sql = `
    SELECT
      MAX(CASE WHEN critical_count = 0 AND major_count = 0 THEN 1 ELSE 0 END) AS has_clean,
      COUNT(*)                                                                   AS review_count
    FROM guardops.migration_review
    WHERE migration_file = $1
      AND file_sha       = $2
      AND account_id     = guardops.current_account()`;
  let rows;
  try {
    rows = runDoor(sql, [fileName, fileSha]);
  } catch (e) {
    process.stderr.write(`check_all_clean: query error for ${fileName}: ${e.message}\n`);
    unreviewed.push(fileName + ' [query error]');
    continue;
  }

  const row   = rows?.[0] ?? {};
  const count = Number(row.review_count ?? 0);
  const hasClean = Number(row.has_clean ?? 0);

  if (count === 0)       unreviewed.push(fileName);
  else if (hasClean > 0) clean.push(fileName);
  else                   dirty.push(fileName);
}

const total = changedFiles.filter(f =>
  /^\d+_[A-Za-z0-9_-]+\.sql$/.test(f.replace(/^migrations\//, ''))
).length;

process.stdout.write(`check_all_clean: ${clean.length}/${total} files clean\n`);
if (dirty.length > 0)
  process.stdout.write(`DIRTY (fix critical/major findings): ${dirty.join(', ')}\n`);
if (unreviewed.length > 0)
  process.stdout.write(`NOT YET REVIEWED at current content: ${unreviewed.join(', ')}\n`);

process.exit((dirty.length > 0 || unreviewed.length > 0) ? 1 : 0);
