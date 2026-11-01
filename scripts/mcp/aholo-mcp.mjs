#!/usr/bin/env node
/**
 * Aholo Lux3D MCP Server 启动器（stdio 传输）。
 *
 * 为什么需要这个脚本而不是直接在 .mcp.json 里写 npx：
 *  - API Key 只存在项目根的 .env（已被 .gitignore 排除），配置文件本身不含密钥，
 *    这样 .mcp.json 可以安全地提交，团队/多 Agent 每个人用自己的 .env。
 *  - 区域固定 cn，走国内网关 api.aholo3d.cn，直连即可、无需代理；
 *    仅当本机到该域名网络不通时，才在 .env 配 AHOLO_PROXY_URL 兜底（一处配置，各客户端共用）。
 *
 * 用法：
 *   node scripts/mcp/aholo-mcp.mjs            # 以 stdio 启动 MCP Server（正常用法）
 *   node scripts/mcp/aholo-mcp.mjs --doctor   # 自检：握手并列出可用工具
 */

import { spawn } from 'node:child_process';
import { readFileSync, existsSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const PACKAGE = '@manycore/aholo-sdk-mcp@1.9.0';
const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(HERE, '..', '..');

/** 极简 .env 解析：忽略注释与空行，只认 KEY=VALUE。 */
function parseEnvFile(file) {
  const out = {};
  if (!existsSync(file)) return out;
  for (const raw of readFileSync(file, 'utf8').split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || line.startsWith('#')) continue;
    const m = /^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$/.exec(line);
    if (!m) continue;
    let v = m[2].trim();
    if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) {
      v = v.slice(1, -1);
    }
    out[m[1]] = v;
  }
  return out;
}

// 真实环境变量优先于 .env：方便临时换 Key 或临时关代理。
const env = { ...parseEnvFile(join(ROOT, '.env')), ...process.env };

if (!env.AHOLO_API_KEY) {
  console.error('[aholo-mcp] 未找到 AHOLO_API_KEY。');
  console.error('[aholo-mcp] 请在 ' + join(ROOT, '.env') + ' 里写入（可参考 .env.example），');
  console.error('[aholo-mcp] 或先导出同名环境变量后重试。');
  process.exit(1);
}
env.AHOLO_REGION = env.AHOLO_REGION || 'cn';

// 代理为可选兜底：cn 区域直连 api.aholo3d.cn，仅当 .env 显式配置 AHOLO_PROXY_URL 时才注入。
const proxy = env.AHOLO_PROXY_URL || '';
if (proxy) {
  env.HTTP_PROXY = proxy;
  env.HTTPS_PROXY = proxy;
  env.http_proxy = proxy;
  env.https_proxy = proxy;
  env.NO_PROXY = env.NO_PROXY || 'localhost,127.0.0.1';
  env.no_proxy = env.NO_PROXY;
}

const isWin = process.platform === 'win32';
// 固定版本号：避免 cmd.exe 把 semver 里的 ^ 当转义符，也保证团队拿到的行为一致。
// 整条命令行是静态常量、不含任何外部输入，因此用单字符串形式传给 shell:true，
// 既能正确解析 Windows 上的 npx.cmd，也不会触发 Node 的 DEP0190 警告。
const cmdLine = 'npx -y ' + PACKAGE;
const doctor = process.argv.includes('--doctor');

function fail(msg) {
  console.error('[aholo-mcp] ' + msg);
  process.exit(1);
}

if (!doctor) {
  const child = spawn(cmdLine, { env, stdio: 'inherit', shell: isWin });
  child.on('error', (e) => fail('启动 npx 失败: ' + e.message));
  child.on('exit', (code, signal) => process.exit(signal ? 1 : (code ?? 0)));
  for (const sig of ['SIGINT', 'SIGTERM']) {
    process.on(sig, () => { try { child.kill(sig); } catch { /* ignore */ } });
  }
} else {
  // 自检：MCP stdio 传输是「按行分隔的 JSON-RPC」，直接发 initialize + tools/list。
  const child = spawn(cmdLine, { env, stdio: ['pipe', 'pipe', 'inherit'], shell: isWin });
  const pending = new Map();
  let buffer = '';

  child.stdout.setEncoding('utf8');
  child.stdout.on('data', (chunk) => {
    buffer += chunk;
    let nl;
    while ((nl = buffer.indexOf('\n')) >= 0) {
      const line = buffer.slice(0, nl).trim();
      buffer = buffer.slice(nl + 1);
      if (!line) continue;
      let msg;
      try { msg = JSON.parse(line); } catch { continue; }
      if (msg.id !== undefined && pending.has(msg.id)) {
        pending.get(msg.id)(msg);
        pending.delete(msg.id);
      }
    }
  });
  child.on('error', (e) => fail('启动 npx 失败: ' + e.message));

  const send = (obj) => child.stdin.write(JSON.stringify(obj) + '\n');
  const request = (id, method, params, timeoutMs = 180000) =>
    new Promise((res, rej) => {
      const timer = setTimeout(() => { pending.delete(id); rej(new Error('请求超时: ' + method)); }, timeoutMs);
      pending.set(id, (msg) => { clearTimeout(timer); res(msg); });
      send({ jsonrpc: '2.0', id, method, params });
    });

  try {
    console.log('[aholo-mcp] 正在启动 ' + PACKAGE + '（首次运行需要下载依赖，可能较慢）...');
    const init = await request(1, 'initialize', {
      protocolVersion: '2024-11-05',
      capabilities: {},
      clientInfo: { name: 'aholo-mcp-doctor', version: '1.0.0' },
    });
    if (init.error) throw new Error('initialize 失败: ' + JSON.stringify(init.error));
    send({ jsonrpc: '2.0', method: 'notifications/initialized' });

    const listed = await request(2, 'tools/list', {});
    if (listed.error) throw new Error('tools/list 失败: ' + JSON.stringify(listed.error));
    const tools = listed.result?.tools ?? [];
    const names = tools.map((t) => t.name);

    console.log('');
    console.log('[aholo-mcp] 握手成功，region=' + env.AHOLO_REGION + '，proxy=' + (proxy || '未启用（直连 api.aholo3d.cn）'));
    console.log('[aholo-mcp] 工具总数: ' + tools.length);
    console.log('[aholo-mcp] Lux3D 工具: ' + names.filter((n) => n.startsWith('lux3d')).join(', '));
    console.log('[aholo-mcp] World 工具: ' + names.filter((n) => n.startsWith('world')).join(', '));
    console.log('[aholo-mcp] 其他工具: ' + names.filter((n) => !n.startsWith('lux3d') && !n.startsWith('world')).join(', '));
    child.kill();
    process.exit(0);
  } catch (err) {
    child.kill();
    fail(String(err.message || err));
  }
}
