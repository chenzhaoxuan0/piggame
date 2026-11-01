#!/usr/bin/env node
// Small JSON-RPC client for the repository's pinned MCP launcher. No credentials here.
import { spawn } from 'node:child_process';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const child = spawn(process.execPath, [resolve(root, 'scripts/mcp/aholo-mcp.mjs')], {
  cwd: root, stdio: ['pipe', 'pipe', 'pipe'], windowsHide: true,
});
const pending = new Map();
let sequence = 0;
let buffer = '';
child.stderr.on('data', data => process.stderr.write(data));
child.stdout.on('data', data => {
  buffer += data;
  let newline;
  while ((newline = buffer.indexOf('\n')) >= 0) {
    const line = buffer.slice(0, newline).trim();
    buffer = buffer.slice(newline + 1);
    let message;
    try { message = JSON.parse(line); } catch { continue; }
    const request = pending.get(message.id);
    if (!request) continue;
    pending.delete(message.id);
    clearTimeout(request.timer);
    if (message.error) request.reject(new Error(JSON.stringify(message.error)));
    else request.resolve(message.result);
  }
});
function request(method, params) {
  return new Promise((resolveRequest, reject) => {
    const id = ++sequence;
    const timer = setTimeout(() => { pending.delete(id); reject(new Error(`MCP timeout: ${method}`)); }, 180000);
    pending.set(id, { resolve: resolveRequest, reject, timer });
    child.stdin.write(JSON.stringify({ jsonrpc: '2.0', id, method, params }) + '\n');
  });
}
child.on('error', error => { for (const p of pending.values()) { clearTimeout(p.timer); p.reject(error); } pending.clear(); });
child.on('exit', code => { for (const p of pending.values()) { clearTimeout(p.timer); p.reject(new Error(`MCP exited: ${code}`)); } pending.clear(); });
try {
  await request('initialize', { protocolVersion: '2024-11-05', capabilities: {}, clientInfo: { name: 'piggame-assets', version: '1.0' } });
  child.stdin.write(JSON.stringify({ jsonrpc: '2.0', method: 'notifications/initialized' }) + '\n');
  const [operation, inputFile, outputFile] = process.argv.slice(2);
  const result = operation === 'list'
    ? await request('tools/list', {})
    : await request('tools/call', { name: operation, arguments: inputFile ? JSON.parse(readFileSync(inputFile, 'utf8').replace(/^\uFEFF/, '')) : {} });
  const json = JSON.stringify(result, null, 2);
  if (outputFile) {
    const target = resolve(root, outputFile);
    mkdirSync(dirname(target), { recursive: true });
    writeFileSync(target, json + '\n');
    console.log(`Saved MCP response: ${outputFile}`);
  } else console.log(json);
  if (result.isError) process.exitCode = 1;
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
} finally {
  child.stdin.end();
  child.kill();
  for (const p of pending.values()) clearTimeout(p.timer);
}
