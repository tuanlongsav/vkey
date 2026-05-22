/* ============================================================
   Onboarding + theme contrast — vanilla render
   ============================================================ */
(function () {
  const ICON = (name, size = 16) => `<img src="../../assets/icons/${name}.svg" width="${size}" height="${size}" alt="">`;

  const onboardingCard = () => `
    <div class="mini-stage" data-screen-label="04a Onboarding · welcome + permission">
      <span class="mini-caption">Welcome · permission flow</span>
      <div class="mac-window window-dark" style="width: 480px;">
        <div class="mac-titlebar">
          <div class="mac-traffic"><span class="r"></span><span class="y"></span><span class="g"></span></div>
          <div class="mac-title">Chào mừng đến với vkey</div>
        </div>
        <div style="padding: 28px 28px 24px; display:flex; flex-direction:column; align-items:center; gap:16px; text-align:center;">
          <img src="../../assets/logo/vkey-app-icon.svg" width="84" height="84" style="border-radius:20px; box-shadow: var(--shadow-md);">
          <div>
            <div style="font: 800 26px/1.15 var(--font-display); letter-spacing:-0.015em;">Gõ tiếng Việt, không vướng bận.</div>
            <div style="font: var(--t-body); color: var(--fg-2); margin-top:8px; max-width: 360px;">vkey cần quyền <b>Accessibility</b> để nghe và gửi sự kiện bàn phím. Mọi xử lý đều diễn ra local — không telemetry, không tracking.</div>
          </div>
          <div style="width:100%; padding: 14px 16px; border: 1px solid rgba(245, 198, 69, 0.30); background: rgba(245, 198, 69, 0.08); border-radius: 12px; display:flex; gap:12px; align-items:flex-start; text-align:left;">
            ${ICON('alert-triangle', 18)}
            <div style="flex:1;">
              <div style="font: 600 13px var(--font-sans); color: var(--gold-300);">Cấp quyền Accessibility</div>
              <div style="font: var(--t-small); color: var(--fg-2); margin-top:4px;">System Settings → Privacy &amp; Security → Accessibility → bật toggle cho <b>vkey</b>.</div>
            </div>
          </div>
          <div style="display:flex; gap:10px; width:100%; margin-top:4px;">
            <button class="btn btn--secondary" style="flex:1;">${ICON('info-circle')}Tài liệu</button>
            <button class="btn btn--primary" style="flex:2;">Mở System Settings ${ICON('arrow-right', 14)}</button>
          </div>
        </div>
      </div>
    </div>`;

  const lightCard = () => `
    <div class="mini-stage mini-stage--light" data-screen-label="04b Light theme · setting card">
      <span class="mini-caption">Light theme · setting card</span>
      <div class="mac-window" style="width: 460px; background: var(--paper-0);">
        <div class="mac-titlebar" style="background: var(--paper-50); border-color: var(--paper-200);">
          <div class="mac-traffic"><span class="r"></span><span class="y"></span><span class="g"></span></div>
          <div class="mac-title" style="color: var(--ink-200);">Chung</div>
        </div>
        <div style="padding: 18px 20px 22px; display:flex; flex-direction:column; gap: 14px;">
          <div style="font: 600 11px/1 var(--font-sans); letter-spacing: .08em; text-transform: uppercase; color: var(--paper-500);">Nhập liệu</div>
          <div class="row-group" style="background: var(--paper-0); border: 1px solid var(--paper-200); border-radius: 14px; overflow: hidden;">
            <div class="row" style="background: transparent;">
              <div class="row__icon icon-tile--brand" style="background: color-mix(in srgb, var(--vkey-red-500) 14%, transparent); color: var(--vkey-red-600);">${ICON('keycap')}</div>
              <div class="row__body">
                <div class="row__label">Bật / Tắt gõ Tiếng Việt</div>
              </div>
              <input type="checkbox" class="toggle" checked>
            </div>
            <div class="row" style="background: transparent;">
              <div class="row__icon" style="background: var(--paper-100); color: var(--vkey-red-600);">${ICON('abc')}</div>
              <div class="row__body">
                <div class="row__label">Kiểu gõ</div>
              </div>
              <div class="segmented"><button class="is-active">Telex</button><button>VNI</button></div>
            </div>
            <div class="row" style="background: transparent;">
              <div class="row__icon" style="background: var(--paper-100); color: var(--vkey-red-600);">${ICON('sparkles')}</div>
              <div class="row__body">
                <div class="row__label">Tự động sửa lỗi gõ nhầm</div>
                <div class="row__hint" style="color: var(--paper-500);"><span class="mono" style="background:var(--paper-100);color:var(--ink-200)">veeitj</span> → việt</div>
              </div>
              <input type="checkbox" class="toggle" checked>
            </div>
          </div>
          <button class="btn btn--primary" style="align-self: flex-start;">${ICON('download')}<span style="color:#fff">Tải DMG · v2.0.2</span></button>
        </div>
      </div>
    </div>`;

  const mount = document.getElementById('onboarding-mount');
  if (mount) {
    mount.innerHTML = onboardingCard() + lightCard();
  }
})();
