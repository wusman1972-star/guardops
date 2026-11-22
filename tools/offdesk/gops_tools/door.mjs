#!/usr/bin/env node
// ============================================================================
// gops_tools/door.mjs — the cloud builder's web door to the GuardOps floor.
//
// Lives OUTSIDE the repository so branch changes cannot remove it.
// Copied from tools/door.mjs and kept identical in function.
//
// POSTs ONE SQL statement (plus optional params) to the builder-door edge
// function and prints the JSON reply. The door runs it as code_builder.
//
// NO KEY HANDLING: the key header is added outside this machine by the
// environment's API credential. This tool never reads, asks for, or sends one.
//
// USAGE
//   node gops_tools/door.mjs "select session_user::text"
//   node gops_tools/door.mjs "select $1::int + $2::int" '[1, 2]'
//   echo "select 1" | node gops_tools/door.mjs
//   echo "select $1::text" | node gops_tools/door.mjs - '["hi"]'
//
// Exit 0 when the reply is ok:true; exit 1 on ok:false, a bad reply, or a
// transport failure.
//
// PROXY (board 249 P2, board 252): Node's built-in fetch ignores HTTPS_PROXY, so
// in the cloud environment the request skipped the proxy that adds the key and
// the door answered "x-builder-key missing". When a proxy is set and Node was not
// started with NODE_USE_ENV_PROXY=1, this script re-runs itself once with it, so
// plain `node gops_tools/door.mjs ...` works (Node >= 22.21). stdin is passed through.
// ============================================================================

import { spawnSync } from 'node:child_process';

if ((process.env.HTTPS_PROXY || process.env.https_proxy) && process.env.NODE_USE_ENV_PROXY !== '1') {
  const child = spawnSync(process.execPath, [...process.execArgv, ...process.argv.slice(1)], {
    stdio: 'inherit',
    env: { ...process.env, NODE_USE_ENV_PROXY: '1', NODE_NO_WARNINGS: '1' },
  });
  if (child.error) {
    console.error(`door: could not re-run through the proxy: ${child.error.message}`);
    process.exit(1);
  }
  process.exit(child.status ?? 1);
}

const DOOR = 'https://lauttgnmksnxohigaqee.supabase.co/functions/v1/builder-door';

async function readStdin() {
  const chunks = [];
  for await (const chunk of process.stdin) chunks.push(chunk);
  return Buffer.concat(chunks).toString('utf8');
}

function fail(msg) {
  console.error(`door: ${msg}`);
  process.exit(1);
}

const [sqlArg, paramsArg] = process.argv.slice(2);

let sql = sqlArg;
if (sql === undefined || sql === '-') {
  if (process.stdin.isTTY) fail('no SQL given (pass it as an argument or on stdin)');
  sql = await readStdin();
}
sql = sql.trim();
if (!sql) fail('empty SQL');

const body = { sql };
if (paramsArg !== undefined) {
  let params;
  try {
    params = JSON.parse(paramsArg);
  } catch (e) {
    fail(`params are not valid JSON: ${e.message}`);
  }
  if (!Array.isArray(params)) fail('params must be a JSON array');
  body.params = params;
}

let res;
try {
  res = await fetch(DOOR, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
} catch (e) {
  fail(`request failed: ${e.message}`);
}

const text = await res.text();
let reply;
try {
  reply = JSON.parse(text);
} catch {
  console.log(text);
  fail(`HTTP ${res.status}: reply is not JSON`);
}

console.log(JSON.stringify(reply, null, 2));
if (reply?.ok !== true) process.exit(1);
