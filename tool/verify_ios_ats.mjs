/**
 * Prove that the RUNNING iOS app can reach the dev backend over cleartext
 * http:// — i.e. that the NSAppTransportSecurity exception in Info.plist works.
 *
 * Why not just curl the backend: curl runs on the Mac, OUTSIDE the app sandbox,
 * so it proves nothing about ATS. ATS is enforced by iOS per-process on the app
 * itself. So we attach to the app's Dart VM Service and make the request from
 * inside the app's own isolate, through Dio — the exact client it uses at
 * runtime.
 *
 * How we read the result: `evaluate` returns the Future OBJECT, not its value,
 * and the VM service has no "await this" call. Rather than guess, the request
 * carries a unique marker in its path and we then ask the SERVER whether a
 * request with that marker arrived. Server-side evidence, no false green: if
 * ATS had blocked the app, the marker would simply never show up.
 *
 * Usage: node tool/verify_ios_ats.mjs <vm-service-http-uri>
 *   e.g. node tool/verify_ios_ats.mjs http://127.0.0.1:61345/IlbcYmpmxhg=/
 * (Copy the URI from the `flutter run` output.)
 */

import WebSocket from 'ws';

const httpUri = process.argv[2];
if (!httpUri) {
  console.error('usage: node tool/verify_ios_ats.mjs <vm-service-http-uri>');
  process.exit(2);
}

const wsUri = httpUri.replace(/^http/, 'ws') + 'ws';
const BACKEND = process.env.API_BASE_URL ?? 'http://127.0.0.1:3001';
const MARKER = `atsprobe${Date.now()}`;

let nextId = 1;
const pending = new Map();
const ws = new WebSocket(wsUri);

const call = (method, params = {}) =>
  new Promise((resolve, reject) => {
    const id = nextId++;
    pending.set(id, { resolve, reject });
    ws.send(JSON.stringify({ jsonrpc: '2.0', id, method, params }));
    setTimeout(() => {
      if (pending.has(id)) {
        pending.delete(id);
        reject(new Error(`${method} timed out`));
      }
    }, 20000);
  });

ws.on('message', (raw) => {
  const msg = JSON.parse(raw.toString());
  const entry = pending.get(msg.id);
  if (!entry) return;
  pending.delete(msg.id);
  msg.error
    ? entry.reject(new Error(JSON.stringify(msg.error)))
    : entry.resolve(msg.result);
});

ws.on('error', (e) => {
  console.error('VM service connection failed:', e.message);
  process.exit(1);
});

ws.on('open', async () => {
  let pass = 0;
  let fail = 0;
  const ok = (m) => { console.log('  PASS  ' + m); pass++; };
  const bad = (m) => { console.log('  FAIL  ' + m); fail++; };

  try {
    const vm = await call('getVM');
    console.log(`\n== Running INSIDE the iOS app (${vm.operatingSystem}/${vm.targetCPU}) ==`);
    if (vm.operatingSystem !== 'ios') {
      console.log(`  FAIL  expected iOS, got ${vm.operatingSystem}`);
      process.exit(1);
    }
    ok(`attached to Dart VM on ${vm.operatingSystem}`);

    const isolateId = vm.isolates[0].id;

    // The expression is compiled in the scope of ONE library, so it can only
    // use what that library imports. No app library imports dart:io, so
    // HttpClient is never in scope — dio_provider.dart imports Dio, which is
    // also the stack the app genuinely uses.
    const scripts = await call('getScripts', { isolateId });
    const candidates = (scripts.scripts ?? [])
      .map((s) => s.uri)
      .filter((u) => u.startsWith('package:shivesh_app/'));

    const libUri =
      candidates.find((u) => u.includes('dio_provider')) ??
      candidates.find((u) => u.includes('dio_client')) ??
      candidates[0];

    if (!libUri) {
      bad('could not find an app library to evaluate in');
    } else {
      console.log(`  info  evaluating in ${libUri}`);
      // `evaluate` needs a library *id*, not a uri — look it up on the isolate.
      const iso = await call('getIsolate', { isolateId });
      const libRef = iso.libraries.find((l) => l.uri === libUri);
      if (!libRef) throw new Error(`library ref not found for ${libUri}`);

      // Sanity: the backend must be up, or "marker never arrived" would be
      // ambiguous. We do NOT use this call as the proof — it comes from the
      // Mac, not from the sandboxed app.
      const health = await fetch(`${BACKEND}/health`).catch(() => null);
      if (!health?.ok) {
        bad('backend unreachable from the host — start the server first');
        console.log(`\n${pass} passed, ${fail} failed\n`);
        ws.close();
        process.exit(1);
      }

      // Fire a cleartext http:// GET from inside the sandboxed iOS app.
      // A 404 from the backend is a perfectly good result: what matters is
      // that the bytes left the app and reached the server at all.
      const expr =
        `Dio().get('${BACKEND}/__ats/${MARKER}', ` +
        `options: Options(validateStatus: (_) => true))`;

      const result = await call('evaluate', {
        isolateId,
        targetId: libRef.id,
        expression: expr,
      });

      const cls = result?.class?.name ?? result?.valueAsString ?? 'unknown';
      console.log(`  info  request dispatched from the app (${cls})`);

      // The real check: did the SERVER log a request carrying that marker?
      // The backend already logs every request through morgan, so we read its
      // output rather than adding a debug endpoint to production code. Only
      // the iOS app ever requests this URL, so a hit is unambiguous.
      //
      // NOTE: in development the server logs to STDOUT — logs/application-*.log
      // stays 0 bytes. Run the backend as `node server.js | tee /tmp/be_ios.log`
      // and point BACKEND_LOG at that file, or this reports a false failure.
      const logFile = process.env.BACKEND_LOG ?? '/tmp/be_ios.log';

      const { readFile } = await import('node:fs/promises');
      let seen = false;
      for (let i = 0; i < 20 && !seen; i++) {
        await new Promise((r) => setTimeout(r, 300));
        const text = await readFile(logFile, 'utf8').catch(() => '');
        if (text.includes(MARKER)) seen = true;
      }

      if (seen) {
        ok(`backend logged ${MARKER} — the iOS app's cleartext http:// got through`);
      } else {
        bad(
          `backend never logged ${MARKER} — ATS appears to be blocking the app ` +
            `(checked ${logFile})`,
        );
      }
    }

    console.log(`\n${pass} passed, ${fail} failed\n`);
    ws.close();
    process.exit(fail ? 1 : 0);
  } catch (e) {
    console.error('failed:', e.message);
    ws.close();
    process.exit(1);
  }
});
