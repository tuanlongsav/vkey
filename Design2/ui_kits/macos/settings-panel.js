/* ============================================================
   Settings window — vanilla JS render
   Renders the full macOS-style Settings window with 5 tabs.
   ============================================================ */
(function () {
  const ICON = (name, size = 16, white = false) =>
    `<img src="../../assets/icons/${name}.svg" width="${size}" height="${size}"${white ? ' style="filter:invert(1)"' : ''} alt="">`;

  const FLAG = (lang) =>
    `<img src="../../assets/icons/flag-${lang}.svg" width="24" height="18" alt="">`;

  // ---------- Reusable row ----------
  const row = ({ ic, label, hint, control, tone = 'neutral' }) => `
    <div class="row">
      <div class="row__icon ${tone === 'brand' ? 'icon-tile--brand' : ''}">${ICON(ic, 16)}</div>
      <div class="row__body">
        <div class="row__label">${label}</div>
        ${hint ? `<div class="row__hint">${hint}</div>` : ''}
      </div>
      <div class="row__control">${control}</div>
    </div>
  `;

  const toggle = (checked) => `<input type="checkbox" class="toggle"${checked ? ' checked' : ''}>`;

  const segmented = (options, activeIdx) =>
    `<div class="segmented">${options.map((o, i) => `<button${i === activeIdx ? ' class="is-active"' : ''}>${o}</button>`).join('')}</div>`;

  // ---------- Panel: General ----------
  const generalPanel = () => `
    <div class="panel is-active settings-body" data-panel="general">
      <div class="surface-dark" style="padding:14px 16px; display:flex; align-items:center; gap:14px; background: linear-gradient(135deg, color-mix(in srgb, var(--vkey-red-500) 16%, transparent), transparent); border:1px solid color-mix(in srgb, var(--vkey-red-500) 24%, transparent); border-radius: 14px;">
        <img src="../../assets/logo/vkey-app-icon.svg" width="56" height="56" style="border-radius:14px;">
        <div style="flex:1">
          <div style="font: 700 17px/1.2 var(--font-sans); display:flex;align-items:center;gap:8px;">
            vkey <span class="badge badge--brand">v2.0.2 · Bug Hunt</span>
          </div>
          <div style="font:var(--t-small); color:var(--fg-2); margin-top:3px;">Bộ gõ tiếng Việt cho macOS · Telex &amp; VNI · 8,960 syllables · 9,826 từ EN</div>
        </div>
        <button class="btn btn--ghost btn--sm">${ICON('refresh')}Kiểm tra cập nhật</button>
      </div>

      <div class="section-title">Nhập liệu</div>
      <div class="row-group">
        ${row({ ic: 'keycap', tone: 'brand', label: 'Bật / Tắt gõ Tiếng Việt', hint: 'Toggle tổng — tắt để gõ thẳng English', control: toggle(true) })}
        ${row({ ic: 'abc', label: 'Kiểu gõ', control: segmented(['Telex', 'VNI'], 0) })}
        ${row({ ic: 'tone-mark', label: 'Kiểu đặt dấu', hint: 'Kiểu mới: oà, uý, khoẻ, thuỷ', control: segmented(['Kiểu cũ', 'Kiểu mới'], 1) })}
        ${row({ ic: 'sparkles', label: 'Tự động sửa lỗi gõ nhầm', hint: '<span class="mono">thfi</span> → thì &nbsp;·&nbsp; <span class="mono">veeitj</span> → việt &nbsp;·&nbsp; <span class="mono">phuowgn</span> → phương', control: toggle(true) })}
        ${row({ ic: 'dictionary', label: 'Phụ âm z, w, j, f', hint: 'Coi z, w, j, f là phụ âm hợp lệ khi parse', control: toggle(true) })}
      </div>

      <div class="section-title">Phím tắt</div>
      <div class="row-group">
        ${row({
          ic: 'command',
          label: 'Chuyển Tiếng Việt ↔ English',
          hint: 'Nhấn + nhả phím tắt để toggle. Hỗ trợ modifier-only.',
          control: `<div style="display:flex;gap:6px;align-items:center;">
            <span class="keycap">${ICON('command', 12)}</span>
            <span class="keycap">${ICON('shift-key', 12)}</span>
            <button class="btn btn--ghost btn--sm" style="margin-left:6px;color:var(--fg-muted)">${ICON('edit')}Thay đổi</button>
          </div>`
        })}
        ${row({
          ic: 'magic-wand',
          label: 'Đoán từ tiếp theo',
          hint: `HUD cạnh caret — <span class="keycap" style="font-size:10px;height:18px;min-width:20px">Tab</span> để chấp nhận`,
          control: toggle(true)
        })}
      </div>

      <div class="section-title">Hệ thống</div>
      <div class="row-group">
        ${row({ ic: 'upload', label: 'Tự khởi động cùng macOS', control: toggle(true) })}
        ${row({ ic: 'info-circle', label: 'Hiển thị thông báo khi chuyển VI/EN', hint: 'Glassmorphic HUD ở giữa màn hình', control: toggle(true) })}
      </div>
    </div>`;

  // ---------- Panel: Smart Switch ----------
  const appAvatar = (a) =>
    `<div class="avatar" style="background:${a.color}">${a.letter}</div>`;

  const smartPanel = () => {
    const apps = JSON.parse(document.getElementById('apps-data').textContent);
    return `
      <div class="panel settings-body" data-panel="smart">
        <div class="surface-dark" style="background: linear-gradient(135deg, color-mix(in srgb, var(--vkey-red-500) 14%, transparent), transparent); border: 1px solid color-mix(in srgb, var(--vkey-red-500) 22%, transparent); border-radius:14px; padding:16px; display:flex; align-items:center; gap:14px;">
          <div class="row__icon icon-tile--brand" style="width:44px;height:44px;border-radius:11px;">${ICON('shuffle', 22)}</div>
          <div style="flex:1">
            <div style="font:600 15px var(--font-sans); display:flex; align-items:center; gap:8px;">Smart Switch <span class="badge badge--brand">v2.0+</span></div>
            <div style="font:var(--t-small); color:var(--fg-2); margin-top:2px;">Tự chọn chế độ gõ cho từng app: Tiếng Việt · English · Tắt vkey. Auto-learn từ thống kê hàng ngày.</div>
          </div>
          ${toggle(true)}
        </div>

        <div style="display:flex; gap:12px; align-items:center; padding: 0 4px;">
          <div style="display:flex; gap:8px; align-items:center;">
            <span class="src-chip">${ICON('user', 12)}Người dùng đặt</span>
            <span class="src-chip">${ICON('robot', 12)}vkey tự học</span>
          </div>
          <button class="btn btn--secondary btn--sm" style="margin-left:auto;">${ICON('magic-wand', 14)}Tự học từ Thống kê</button>
        </div>

        <div class="surface-dark" style="border-radius: 14px; overflow: hidden;">
          ${apps.map(a => `
            <div class="appitem">
              ${appAvatar(a)}
              <div class="meta">
                <div class="name">${a.name}</div>
                <div class="bundle">${a.bundle}</div>
              </div>
              <div class="actions">
                <span class="src-chip">${ICON(a.src === 'user' ? 'user' : 'robot', 12)}${a.src === 'user' ? 'User' : 'Auto'}</span>
                <span class="lang-pill">${FLAG(a.lang)}</span>
                <button class="btn btn--ghost btn--sm" title="Xoá" aria-label="Xoá">${ICON('trash', 14)}</button>
              </div>
            </div>
          `).join('')}
        </div>

        <div style="display:flex; gap:8px; align-items:center;">
          <input class="input" placeholder="com.example.app" style="flex:1">
          <button class="btn btn--primary">${ICON('plus', 14, true)}Thêm</button>
          <button class="btn btn--secondary">${ICON('search', 14)}Từ app đang chạy</button>
        </div>
      </div>`;
  };

  // ---------- Panel: Macro ----------
  const MACROS = [
    ['vn', 'Việt Nam'], ['hn', 'Hà Nội'], ['tphcm', 'Thành phố Hồ Chí Minh'],
    ['kga', 'Kính gửi anh'], ['kgc', 'Kính gửi chị'], ['cty', 'Công ty'],
    ['sdt', 'Số điện thoại'], ['qdinh', 'Quyết định'], ['bcao', 'Báo cáo'],
    ['gdoc', 'Giám đốc'], ['ptgd', 'Phó Tổng giám đốc'], ['ttg', 'Thủ tướng'],
  ];

  const macroPanel = () => `
    <div class="panel settings-body" data-panel="macro">
      <div class="surface-dark" style="background: linear-gradient(135deg, color-mix(in srgb, var(--gold-400) 12%, transparent), transparent); border: 1px solid color-mix(in srgb, var(--gold-400) 22%, transparent); border-radius:14px; padding:16px; display:flex; align-items:center; gap:14px;">
        <div class="row__icon" style="width:44px;height:44px;border-radius:11px; background: color-mix(in srgb, var(--gold-400) 22%, transparent); color: var(--gold-500);">${ICON('sparkles', 22)}</div>
        <div style="flex:1">
          <div style="font:600 15px var(--font-sans);">Macro · Viết tắt → Cụm dài</div>
          <div style="font:var(--t-small); color:var(--fg-2); margin-top:2px;">Gõ <span class="mono">vn </span>→ ra <span class="mono">Việt Nam </span>. Kích hoạt bằng Space hoặc dấu câu.</div>
        </div>
        ${toggle(true)}
      </div>

      <div class="surface-dark" style="border-radius:14px; overflow:hidden;">
        <table class="macro-table">
          <thead><tr>
            <th style="width:32%">Viết tắt</th>
            <th>Cụm dài</th>
            <th style="width:60px"></th>
          </tr></thead>
          <tbody>
            ${MACROS.map(([s, l]) => `
              <tr>
                <td class="short">${s}</td>
                <td>${l}</td>
                <td style="text-align:right;"><button class="btn btn--ghost btn--sm" style="opacity:.5;padding:4px;">${ICON('ellipsis', 14)}</button></td>
              </tr>`).join('')}
          </tbody>
        </table>
      </div>

      <div style="display:flex; gap:10px; align-items:center; flex-wrap: wrap;">
        <button class="btn btn--primary">${ICON('plus', 14, true)}Thêm macro</button>
        <button class="btn btn--secondary">${ICON('upload', 14)}Xuất</button>
        <button class="btn btn--secondary">${ICON('download', 14)}Nhập</button>
        <span style="margin-left:auto; color:var(--fg-muted); font: var(--t-mono-sm);">${MACROS.length} macros</span>
      </div>

      <div style="display:flex; align-items:flex-start; gap:10px; padding:14px 16px; background: rgba(245, 198, 69, 0.10); border:1px solid rgba(245, 198, 69, 0.25); border-radius:12px;">
        ${ICON('lightbulb', 18)}
        <div style="flex:1; color:var(--gold-300); font:var(--t-body)">
          <b>5 cụm</b> bạn đã gõ ≥10 lần có thể trở thành macro: <i>kính gửi chị, công ty của tôi, theo quyết định, báo cáo tuần, trân trọng cảm ơn</i>.
        </div>
        <button class="btn btn--ghost btn--sm" style="color: var(--gold-300);">Xem &amp; thêm ${ICON('chevron-right', 14)}</button>
      </div>
    </div>`;

  // ---------- Panel: Spellcheck ----------
  const spellPanel = () => `
    <div class="panel settings-body" data-panel="spell">
      <div class="section-title">Cấu hình kiểm tra chính tả</div>
      <div class="row-group">
        ${row({ ic: 'check-circle', tone: 'brand', label: 'Kiểm tra chính tả 6 bước', hint: 'Vowel Inclusion Pairs · kiểm tra trong câu', control: toggle(true) })}
        ${row({ ic: 'lightbulb', label: 'Gợi ý sửa lỗi · auto-fix khi confidence ≥ 88%', control: toggle(true) })}
        ${row({
          ic: 'user',
          label: 'Từ điển cá nhân',
          hint: 'Allow / Keep / Deny — định nghĩa cách vkey xử lý từng từ',
          control: `<div style="display:flex; gap:6px; align-items:center;">
            <button class="btn btn--ghost btn--sm">${ICON('edit')}Sửa</button>
            <button class="btn btn--ghost btn--sm">${ICON('upload')}Gửi tác giả</button>
            ${toggle(true)}
          </div>`
        })}
      </div>

      <div class="section-title">Tự động khôi phục tiếng Anh</div>
      <div class="row-group">
        ${row({
          ic: 'return-key',
          label: 'Space Restore',
          hint: '<span class="mono">ò</span> → of &nbsp;·&nbsp; <span class="mono">ì</span> → if &nbsp;·&nbsp; <span class="mono">sê</span> → see &nbsp;·&nbsp; <span class="mono">tê</span> → tee',
          control: toggle(true)
        })}
        ${row({
          ic: 'sliders',
          label: 'Chính sách khôi phục',
          control: segmented(['Ưu tiên VI', 'Cân bằng', 'Ưu tiên EN'], 1)
        })}
      </div>

      <div class="section-title">Từ điển từ GitHub</div>
      <div class="surface-dark" style="padding:14px 18px; display:flex; align-items:center; gap:16px; border-radius:14px;">
        <div class="row__icon">${ICON('dictionary', 18)}</div>
        <div style="flex:1; display:flex; flex-direction:column; gap:6px;">
          <div style="display:flex; align-items:center; gap:10px; font:var(--t-body);">
            ${FLAG('vn')}<span>Tiếng Việt</span> <span class="badge badge--brand">v9</span> <span style="color:var(--fg-muted)">· 8,960 từ</span>
          </div>
          <div style="display:flex; align-items:center; gap:10px; font:var(--t-body);">
            ${FLAG('us')}<span>English</span> <span class="badge badge--brand">v9</span> <span style="color:var(--fg-muted)">· 9,826 từ</span>
          </div>
        </div>
        <div style="text-align:right;">
          <button class="btn btn--secondary">${ICON('refresh', 14)}Cập nhật ngay</button>
          <div style="font:var(--t-mono-sm); color:var(--fg-muted); margin-top:6px;">Auto-check 24h · lần cuối: 02:14 hôm nay</div>
        </div>
      </div>
    </div>`;

  // ---------- Panel: Statistics ----------
  const STATS_TOP = [
    ['của', 482, 100], ['không', 391, 81], ['được', 354, 73],
    ['việt nam', 298, 62], ['cảm ơn', 211, 44], ['báo cáo', 167, 35],
    ['kính gửi', 142, 30], ['công ty', 128, 27],
  ];
  const KPIS = [
    { label: 'Từ đã gõ', value: '12,847', sub: '+18% so tuần trước' },
    { label: 'Tiếng Việt', value: '78%', sub: 'mode dominant' },
    { label: 'Macro hit', value: '142', sub: 'expansions' },
    { label: 'Predictions', value: '89', sub: 'Tab-accepted' },
  ];

  const statsPanel = () => `
    <div class="panel settings-body" data-panel="stats">
      <div style="display:flex; align-items:flex-end; gap:14px; padding: 0 4px;">
        <div>
          <div style="font:600 17px var(--font-sans);">Tuần 21 năm 2026</div>
          <div style="font:var(--t-small); color:var(--fg-muted); margin-top:2px;">từ 18/05 đến 24/05/2026 · tracked locally · zero telemetry</div>
        </div>
        <div style="margin-left:auto; display:flex; gap:8px;">
          <button class="btn btn--secondary btn--sm">${ICON('upload', 14)}Xuất sao lưu</button>
          <button class="btn btn--secondary btn--sm">${ICON('download', 14)}Nhập</button>
        </div>
      </div>

      <div class="kpi-grid">
        ${KPIS.map(k => `
          <div class="kpi">
            <div class="label">${k.label}</div>
            <div class="value">${k.value}</div>
            <div class="sub">${k.sub}</div>
          </div>`).join('')}
      </div>

      <div class="surface-dark" style="border-radius: 14px; overflow: hidden;">
        <div style="padding:12px 16px; display:flex; align-items:center; gap:10px; border-bottom:1px solid var(--border-1);">
          ${ICON('chart-bar', 18)}
          <div style="font:600 13px var(--font-sans);">Top từ tiếng Việt · tuần này</div>
          <span class="badge badge--brand" style="margin-left:auto">Top 10%</span>
        </div>
        ${STATS_TOP.map(([w, c, bar], i) => `
          <div class="stat-row">
            <div class="rank">${String(i + 1).padStart(2, '0')}</div>
            <div>
              <div class="word">${w}</div>
              <div class="bar"><i style="width:${bar}%"></i></div>
            </div>
            <div class="count">${c}</div>
          </div>`).join('')}
      </div>
    </div>`;

  // ---------- Window shell ----------
  const TITLE_BY_TAB = {
    general: 'Chung', smart: 'Smart Switch', macro: 'Macro',
    spell: 'Chính tả', stats: 'Thống kê & Sao lưu',
  };

  const settingsWindow = () => `
    <div class="mac-window window-dark" style="max-width: 900px; margin: 0 auto;" data-screen-label="03 Settings · vkey Cài đặt">
      <div class="mac-titlebar">
        <div class="mac-traffic"><span class="r"></span><span class="y"></span><span class="g"></span></div>
        <div class="mac-title" id="settings-title">Chung</div>
      </div>
      <div class="tabbar">
        <button class="tab" data-tab="general" aria-selected="true">${ICON('gear')}Chung</button>
        <button class="tab" data-tab="smart">${ICON('shuffle')}Smart Switch</button>
        <button class="tab" data-tab="macro">${ICON('sparkles')}Macro</button>
        <button class="tab" data-tab="spell">${ICON('check-circle')}Chính tả</button>
        <button class="tab" data-tab="stats">${ICON('chart-bar')}Thống kê</button>
      </div>
      ${generalPanel()}
      ${smartPanel()}
      ${macroPanel()}
      ${spellPanel()}
      ${statsPanel()}
    </div>`;

  // mount
  const mount = document.getElementById('settings-mount');
  if (mount) {
    mount.innerHTML = settingsWindow();

    // wire up tabs
    const tabs = mount.querySelectorAll('[data-tab]');
    const panels = mount.querySelectorAll('[data-panel]');
    const title = mount.querySelector('#settings-title');
    tabs.forEach(tab => {
      tab.addEventListener('click', () => {
        tabs.forEach(t => t.setAttribute('aria-selected', 'false'));
        panels.forEach(p => p.classList.remove('is-active'));
        tab.setAttribute('aria-selected', 'true');
        const key = tab.dataset.tab;
        mount.querySelector(`[data-panel="${key}"]`).classList.add('is-active');
        title.textContent = TITLE_BY_TAB[key];
      });
    });
  }
})();
