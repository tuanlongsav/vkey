// cdp.mjs — chạy một biểu thức JS trong trang Blink qua Chrome DevTools Protocol.
//
// Vì sao cần: đo đơn vị xoá của ô nhập nền Blink phải ĐỌC BẰNG JS trong chính
// trang, không đọc qua Accessibility. Hai lý do:
//   1. Chrome không phơi web content ra AX theo cách vkey đọc được.
//   2. Ngay cả khi đọc được, AX có thể chuẩn hoá chuỗi trên đường ra — nghĩa là
//      phép đo "đọc lại rồi so" sẽ NÓI DỐI về dạng lưu thật.
// JS trong trang đọc đúng cái DOM đang giữ, không qua tầng nào.
//
// Dùng Chrome RIÊNG (--user-data-dir tách rời) nên không đụng hồ sơ, không đụng
// thiết lập "Allow JavaScript from Apple Events" của người dùng.
//
// Chạy: node Tools/probe/cdp.mjs '<biểu thức JS>' [--port 9222] [--match probe.html]

const args = process.argv.slice(2);
const expr = args[0];
if (!expr) {
  console.error('cdp.mjs: thiếu biểu thức JS');
  process.exit(2);
}
const flag = (name, def) => {
  const i = args.indexOf(name);
  return i >= 0 && i + 1 < args.length ? args[i + 1] : def;
};
const port = flag('--port', '9222');
const match = flag('--match', 'probe.html');

const targets = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
const page = targets.find((t) => t.type === 'page' && t.url.includes(match));
if (!page) {
  console.error(`cdp.mjs: không thấy trang khớp "${match}". Các trang đang mở:`);
  for (const t of targets) console.error('  ', t.type, t.url.slice(0, 90));
  process.exit(3);
}

const ws = new WebSocket(page.webSocketDebuggerUrl);
const done = new Promise((resolve, reject) => {
  const timer = setTimeout(() => reject(new Error('CDP timeout 10s')), 10_000);
  ws.onopen = () => {
    ws.send(
      JSON.stringify({
        id: 1,
        method: 'Runtime.evaluate',
        params: { expression: expr, returnByValue: true, awaitPromise: true },
      })
    );
  };
  ws.onmessage = (ev) => {
    const msg = JSON.parse(ev.data);
    if (msg.id !== 1) return;
    clearTimeout(timer);
    if (msg.result?.exceptionDetails) {
      reject(new Error(msg.result.exceptionDetails.exception?.description ?? 'lỗi JS trong trang'));
    } else {
      resolve(msg.result?.result?.value);
    }
    ws.close();
  };
  ws.onerror = (e) => {
    clearTimeout(timer);
    reject(new Error('WebSocket lỗi: ' + (e.message ?? e)));
  };
});

try {
  const value = await done;
  console.log(typeof value === 'string' ? value : JSON.stringify(value, null, 2));
} catch (e) {
  console.error('cdp.mjs:', e.message);
  process.exit(4);
}
