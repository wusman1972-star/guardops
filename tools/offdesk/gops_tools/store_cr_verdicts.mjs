#!/usr/bin/env node
// store_cr_verdicts.mjs  (board 4075, relocated board 4225)
//
// Lives OUTSIDE the repository so branch changes cannot remove it.
// Repo and door paths are hardcoded; no relative __dirname resolution.
//
// Reads cr_last.txt and records a per-file verdict in guardops.migration_review
// for every migration file the reviewer actually reached this run.
// Files listed in unreviewedFiles are skipped — the reviewer did not reach them.
//
// Uses git hash-object to capture the exact file content that was reviewed so the
// content gate can answer "has this file been reviewed clean at THIS content" and
// avoid re-reviewing files whose bytes have not changed since a clean verdict.
//
// Calls migration_review_record() through door.mjs (builder auth).
// Exit 0 = all verdicts recorded.  Exit 1 = at least one error.

import { readFileSync } from 'node:fs';
import { execFileSync, spawnSync } from 'node:child_process';
import { join } from 'node:path';

const repo = 'C:\\Users\\T480\\Desktop\\flowops-guardops-sql';
const door = 'C:\\Users\\T480\\Desktop\\gops_tools\\door.mjs';

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
  return reply;
}

// ── parse cr_last.txt ──────────────────────────────────────────────────────
const crPath = join(repo, 'tools', 'cr_last.txt');
const lines  = readFileSync(crPath, 'utf8').trim().split('\n');

const findingsPerFile = {};   // "migrations/0307_..." → { major, minor }
let complete   = null;

for (const line of lines) {
  let obj;
  try { obj = JSON.parse(line); } catch { continue; }
  if (obj.type === 'finding') {
    const key = obj.fileName;   // e.g. "migrations/0307_open_work_cap.sql"
    if (!findingsPerFile[key]) findingsPerFile[key] = { critical: 0, major: 0, minor: 0 };
    if      (obj.severity === 'critical') findingsPerFile[key].critical++;
    else if (obj.severity === 'major')    findingsPerFile[key].major++;
    else if (obj.severity === 'minor')    findingsPerFile[key].minor++;
  }
  if (obj.type === 'complete') { complete = obj; break; }
}

if (!complete) {
  process.stderr.write('store_cr_verdicts: no "complete" line in cr_last.txt\n');
  process.exit(1);
}

// ── build the reviewed file list from the first complete line ─────────────
const unreviewed = new Set((complete.unreviewedFiles || []).map(u => u.filename ?? u));
const allChanged = (complete.reviewedFiles || []).filter(f => !unreviewed.has(f));

// ── get HEAD SHA (used as the commit-level identifier) ─────────────────────
const headSha = execFileSync('git', ['rev-parse', 'HEAD'], { cwd: repo })
  .toString().trim();

// ── get reviewed-HEAD SHA (written by cr_review.bat before it ran the CLI) ─
// Guards against a commit made after the review — without this, findings from
// an earlier review would appear to cover new content.
let reviewedHeadSha = null;
const reviewedHeadPath = join(repo, 'tools', 'cr_reviewed_head.txt');
try {
  reviewedHeadSha = readFileSync(reviewedHeadPath, 'utf8').trim() || null;
} catch {
  process.stderr.write(
    'store_cr_verdicts: warning: cr_reviewed_head.txt missing — cannot verify reviewed revision\n'
  );
}

// ── record each reviewed file ──────────────────────────────────────────────
let recorded = 0;
let skipped  = 0;
let errors   = 0;

for (const rawFile of allChanged) {
  if (unreviewed.has(rawFile)) { skipped++; continue; }
  if (!rawFile.startsWith('migrations/')) continue;

  const fileName = rawFile.replace(/^migrations\//, '');
  if (!/^\d+_[A-Za-z0-9_]+\.sql$/.test(fileName)) continue;

  // Compute the git blob SHA of the current working-tree content.
  let workingTreeSha;
  try {
    workingTreeSha = execFileSync('git', ['hash-object', rawFile], { cwd: repo })
      .toString().trim();
  } catch {
    process.stderr.write(`store_cr_verdicts: cannot hash ${rawFile} (missing?)\n`);
    skipped++;
    continue;
  }

  // Guard: reject if the file has uncommitted edits since the review ran.
  // The reviewer hashes committed content; storing a verdict against a modified
  // working-tree hash would let check_all_clean accept unreviewed changes.
  let headFileSha;
  try {
    headFileSha = execFileSync('git', ['rev-parse', `HEAD:${rawFile}`], { cwd: repo })
      .toString().trim();
  } catch {
    headFileSha = null;
  }
  if (headFileSha && workingTreeSha !== headFileSha) {
    process.stderr.write(
      `store_cr_verdicts: ${rawFile} has uncommitted changes — commit before running the review and verdict store\n`
    );
    errors++;
    continue;
  }

  // Guard: reject if the file was committed after the review ran.
  if (reviewedHeadSha) {
    let reviewedFileSha;
    try {
      reviewedFileSha = execFileSync(
        'git', ['rev-parse', `${reviewedHeadSha}:${rawFile}`], { cwd: repo }
      ).toString().trim();
    } catch {
      reviewedFileSha = null;
    }
    if (!reviewedFileSha || (headFileSha && reviewedFileSha !== headFileSha)) {
      process.stderr.write(
        `store_cr_verdicts: ${rawFile} not found at the review commit or changed since — re-run the reviewer before storing verdicts\n`
      );
      errors++;
      continue;
    }
  }

  const fileSha = workingTreeSha;

  const fc  = findingsPerFile[rawFile] || { critical: 0, major: 0, minor: 0 };
  const sql = `SELECT guardops.migration_review_record(
    $1::text, $2::text, $3::integer, $4::text,
    $5::integer, $6::integer, $7::integer, $8::integer,
    $9::text, $10::text, $11::text, $12::text
  ) AS id`;
  const params = [
    fileName, 'CLI', null, headSha,
    fc.critical, fc.major, fc.minor, 0,
    null, null, 'CODE', fileSha,
  ];

  try {
    runDoor(sql, params);
    recorded++;
  } catch (e) {
    process.stderr.write(`store_cr_verdicts: error for ${fileName}: ${e.message}\n`);
    errors++;
  }
}

process.stdout.write(
  `store_cr_verdicts: ${recorded} recorded, ${skipped} skipped (unreviewed/missing), ${errors} errors\n`
);
process.exit(errors > 0 ? 1 : 0);
