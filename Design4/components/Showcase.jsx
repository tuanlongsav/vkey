/* eslint-disable */
/* Onboarding + Icon library — vkey 3D */

function OnboardingScreen() {
  return (
    <div className="onb">
      <div className="onb-hero">
        <img src="assets/app-icon.svg" alt="vkey" width="128" height="128" className="onb-icon"/>
        <div className="onb-icon-halo"/>
      </div>

      <h1 className="onb-title">Chào mừng đến với vkey</h1>
      <p className="onb-sub">Bộ gõ tiếng Việt cá nhân, đơn giản, cho macOS — Telex, VNI, Smart Switch, Macro, Spell check.</p>

      <div className="onb-steps">
        <div className="onb-step done">
          <GlassTile color="green" size="md" style={{ borderRadius: 11 }}>
            <Icon name="check" size={18}/>
          </GlassTile>
          <div className="onb-step-text">
            <div className="onb-step-title">Cài đặt vkey</div>
            <div className="onb-step-sub">Đã hoàn tất</div>
          </div>
          <span className="onb-step-status done">✓</span>
        </div>

        <div className="onb-step active">
          <GlassTile color="red" size="md" style={{ borderRadius: 11 }}>
            <Icon name="lockOpen" size={18}/>
          </GlassTile>
          <div className="onb-step-text">
            <div className="onb-step-title">Cấp quyền Accessibility</div>
            <div className="onb-step-sub">System Settings → Privacy & Security → Accessibility</div>
          </div>
          <button className="btn btn--primary btn--sm">Mở cài đặt</button>
        </div>

        <div className="onb-step">
          <GlassTile color="blue" size="md" style={{ borderRadius: 11 }}>
            <Icon name="keyboard" size={18}/>
          </GlassTile>
          <div className="onb-step-text">
            <div className="onb-step-title">Chọn kiểu gõ</div>
            <div className="onb-step-sub">Telex hay VNI — đổi bất cứ lúc nào</div>
          </div>
          <span className="onb-step-status">3</span>
        </div>

        <div className="onb-step">
          <GlassTile color="purple" size="md" style={{ borderRadius: 11 }}>
            <Icon name="sparkles" size={18}/>
          </GlassTile>
          <div className="onb-step-text">
            <div className="onb-step-title">Thử gõ vài chữ</div>
            <div className="onb-step-sub">tieengs → tiếng · vietj → việt</div>
          </div>
          <span className="onb-step-status">4</span>
        </div>
      </div>

      <div className="onb-progress">
        <span className="pip done"/>
        <span className="pip active"/>
        <span className="pip"/>
        <span className="pip"/>
      </div>

      <div className="onb-actions">
        <button className="btn btn--glass">Bỏ qua</button>
        <button className="btn btn--primary">Tiếp theo</button>
      </div>
    </div>
  );
}

function IconLibrary() {
  const groups = [
    { color: 'red',    names: ['keyboard', 'globe', 'flagVn', 'paintbrush'] },
    { color: 'gold',   names: ['sparkles', 'lightbulb', 'rocket', 'chart'] },
    { color: 'blue',   names: ['switch', 'refresh', 'flagUs', 'download'] },
    { color: 'green',  names: ['check', 'shield', 'wand', 'upload'] },
    { color: 'purple', names: ['robot', 'wand', 'book', 'person'] },
    { color: 'gray',   names: ['gear', 'cmd', 'info', 'bell'] },
    { color: 'ink',    names: ['lock', 'lockOpen', 'trash', 'power'] },
  ];

  return (
    <div className="iconlib">
      <div className="iconlib-head">
        <h2>Bộ icon 3D · Liquid Glass</h2>
        <p>Mỗi icon là 1 glyph SF-Symbol-style đặt trên tile glass với gradient ball-lighting + specular gloss + drop shadow. Đồng nhất theo color preset.</p>
      </div>

      {groups.map(g => (
        <div className="iconlib-row" key={g.color}>
          <div className="iconlib-label">{g.color}</div>
          <div className="iconlib-tiles">
            {g.names.map((n, i) => (
              <div className="iconlib-cell" key={n+i}>
                <GlassTile color={g.color} size="lg" style={{ borderRadius: 16 }}>
                  <Icon name={n} size={28}/>
                </GlassTile>
                <span className="iconlib-name">{n}</span>
              </div>
            ))}
          </div>
        </div>
      ))}

      <div className="iconlib-row">
        <div className="iconlib-label">Sizes</div>
        <div className="iconlib-tiles">
          <div className="iconlib-cell">
            <GlassTile color="red" size="sm" style={{ borderRadius: 7 }}>
              <Icon name="gear" size={14}/>
            </GlassTile>
            <span className="iconlib-name">24px</span>
          </div>
          <div className="iconlib-cell">
            <GlassTile color="red" size="md" style={{ borderRadius: 11 }}>
              <Icon name="gear" size={20}/>
            </GlassTile>
            <span className="iconlib-name">40px</span>
          </div>
          <div className="iconlib-cell">
            <GlassTile color="red" size="lg" style={{ borderRadius: 16 }}>
              <Icon name="gear" size={28}/>
            </GlassTile>
            <span className="iconlib-name">56px</span>
          </div>
          <div className="iconlib-cell">
            <GlassTile color="red" style={{ width: 80, height: 80, borderRadius: 22 }}>
              <Icon name="gear" size={40}/>
            </GlassTile>
            <span className="iconlib-name">80px</span>
          </div>
        </div>
      </div>
    </div>
  );
}

function AppIconShowcase() {
  const sizes = [16, 32, 64, 128, 256];
  return (
    <div className="app-icon-show">
      <div className="ais-hero">
        <img src="assets/app-icon.svg" width="320" height="320" alt="vkey 3D" />
      </div>
      <div className="ais-grid">
        {sizes.map(s => (
          <div className="ais-cell" key={s}>
            <img src="assets/app-icon.svg" width={s} height={s} alt={`${s}px`}/>
            <div className="ais-label">{s}×{s}</div>
          </div>
        ))}
      </div>
      <div className="ais-context">
        <div className="ais-dock">
          {[64, 64, 64, 64, 64, 64].map((s, i) => (
            <div className="dock-icon" key={i}>
              {i === 2
                ? <img src="assets/app-icon.svg" width={s} height={s}/>
                : <div className="dock-placeholder" style={{
                    background: ['linear-gradient(160deg,#6fb5ff,#1f5fc0)',
                                 'linear-gradient(160deg,#7cdcaf,#114d31)',
                                 '',
                                 'linear-gradient(160deg,#ffe079,#6e4a0b)',
                                 'linear-gradient(160deg,#c79bff,#3b1c7a)',
                                 'linear-gradient(160deg,#fa8aab,#8a1f3f)'][i]
                  }}/>}
            </div>
          ))}
        </div>
        <div className="ais-dock-label">Dock context (Mac OS Tahoe)</div>
      </div>
    </div>
  );
}

window.OnboardingScreen = OnboardingScreen;
window.IconLibrary = IconLibrary;
window.AppIconShowcase = AppIconShowcase;
