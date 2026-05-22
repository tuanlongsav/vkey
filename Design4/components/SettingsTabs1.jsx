/* eslint-disable */
/* Settings tab content — vkey 3D */

function GeneralTab({ s, setS }) {
  return (
    <div className="tab-body">
      <SettingsHeader />

      <div className="set-group">
        <Row icon="keyboard" color="red" label="Bật / Tắt gõ Tiếng Việt"
             sub="Toggle tổng — bật/tắt toàn bộ engine"
             control={<Toggle on={s.vi} onClick={() => setS({ ...s, vi: !s.vi })} />} />
        <Row icon="rocket" color="gold" label="Tự khởi động cùng hệ thống"
             control={<Toggle on={s.autostart} onClick={() => setS({ ...s, autostart: !s.autostart })} />} />
        <Row icon="abc" color="blue" label="Kiểu gõ"
             control={
               <Segmented
                 value={s.layout}
                 options={[{ value: 'telex', label: 'Telex' }, { value: 'vni', label: 'VNI' }]}
                 onChange={v => setS({ ...s, layout: v })}
               />
             } />
        <Row icon="book" color="purple" label="Phụ âm z, w, j, f"
             sub="Coi z, w, j, f là phụ âm hợp lệ"
             control={<Toggle on={s.zwjf} onClick={() => setS({ ...s, zwjf: !s.zwjf })} />} />
        <Row icon="sparkles" color="gold" label="Tự động sửa lỗi gõ nhầm"
             sub="thfi → thì, dinhjd → định, veeitj → việt"
             control={<Toggle on={s.autotypo} onClick={() => setS({ ...s, autotypo: !s.autotypo })} />} />
        <Row icon="bell" color="green" label="Hiển thị HUD khi chuyển VI/EN"
             control={<Toggle on={s.hud} onClick={() => setS({ ...s, hud: !s.hud })} />} />
        <Row icon="globe" color="red" label="Kiểu đặt dấu"
             sub={s.modern ? 'oà, uý, khoẻ, thuỷ' : 'òa, úy, khỏe, thủy'}
             control={
               <Segmented
                 value={s.modern ? 'modern' : 'classic'}
                 options={[{ value: 'classic', label: 'Cũ' }, { value: 'modern', label: 'Mới' }]}
                 onChange={v => setS({ ...s, modern: v === 'modern' })}
               />
             } />
        <Row icon="cmd" color="ink" label="Phím tắt"
             control={
               <div className="key-combo">
                 <span className="keycap">⌃</span>
                 <span className="keycap">⇧</span>
                 <span className="key-combo-sub">(chỉ modifier)</span>
                 <button className="btn btn--glass btn--ic"><Icon name="trash" size={13} color="rgba(255,255,255,0.7)"/></button>
               </div>
             } divider={false}/>
      </div>

      <div className="set-group">
        <Row icon="wand" color="purple" label="Đoán từ tiếp theo"
             sub="HUD nhỏ cạnh caret · Tab để chấp nhận"
             control={<Toggle on={s.predict} onClick={() => setS({ ...s, predict: !s.predict })} />} divider={false}/>
      </div>

      <div className="set-footer">v2.2.0 · "Theme Library" · Liquid Glass</div>
    </div>
  );
}

function SmartSwitchTab() {
  const apps = [
    { name: 'Claude', bundle: 'com.anthropic.claudefordesktop', state: 'vi', src: 'user', color: '#D97757', letter: 'C' },
    { name: 'Visual Studio Code', bundle: 'com.microsoft.VSCode', state: 'en', src: 'auto', color: '#007ACC', letter: 'V' },
    { name: 'Safari', bundle: 'com.apple.Safari', state: 'auto', src: 'auto', color: '#1B88FF', letter: 'S' },
    { name: 'Raycast', bundle: 'com.raycast.macos', state: 'en', src: 'user', color: '#FF6363', letter: 'R' },
    { name: 'Zalo', bundle: 'com.vng.zalo', state: 'vi', src: 'auto', color: '#0068FF', letter: 'Z' },
    { name: 'Notion', bundle: 'notion.id', state: 'auto', src: 'auto', color: '#000000', letter: 'N' },
    { name: 'Slack', bundle: 'com.tinyspeck.slackmacgap', state: 'en', src: 'auto', color: '#611F69', letter: 'S' },
    { name: 'Discord', bundle: 'com.hnc.Discord', state: 'en', src: 'auto', color: '#5865F2', letter: 'D' },
  ];

  const StatePill = ({ state, src }) => {
    if (state === 'vi') return (
      <div className="state-pill state-vi"><Icon name="flagVn" size={16}/>{src === 'user' && <span className="src">👤</span>}</div>
    );
    if (state === 'en') return (
      <div className="state-pill state-en"><Icon name="flagUs" size={16}/>{src === 'user' && <span className="src">👤</span>}</div>
    );
    return (
      <div className="state-pill state-auto"><Icon name="robot" size={14}/></div>
    );
  };

  return (
    <div className="tab-body">
      <div className="ss-banner">
        <GlassTile color="blue" size="lg" style={{ borderRadius: 14 }}>
          <Icon name="switch" size={28} />
        </GlassTile>
        <div className="ss-banner-text">
          <div className="ss-banner-title">Smart Switch</div>
          <div className="ss-banner-sub">Tự chọn chế độ gõ cho từng app · Tiếng Việt 🇻🇳 · Tiếng Anh 🇺🇸 · Tắt 🚫</div>
        </div>
        <Toggle on={true} />
      </div>

      <div className="ss-legend">
        <span className="legend-item"><span className="dot user">👤</span> Người dùng đặt</span>
        <span className="legend-item"><span className="dot auto">🤖</span> Tự động học</span>
        <button className="btn btn--glass"><Icon name="wand" size={14} color="rgba(255,255,255,0.85)"/> Tự học từ Thống kê</button>
      </div>

      <div className="set-group ss-list">
        {apps.map(a => (
          <div className="app-row" key={a.bundle}>
            <div className="app-avatar" style={{ background: `linear-gradient(160deg, ${a.color}, color-mix(in srgb, ${a.color} 40%, #000))` }}>
              <span>{a.letter}</span>
              <div className="app-avatar-gloss" />
            </div>
            <div className="app-meta">
              <div className="app-name">{a.name}</div>
              <div className="app-bundle">{a.bundle}</div>
            </div>
            <StatePill state={a.state} src={a.src} />
            <button className="icon-btn"><Icon name="trash" size={14} color="rgba(255,150,140,0.85)"/></button>
          </div>
        ))}
      </div>

      <div className="ss-footer">
        <input className="bundle-input" placeholder="com.example.app" defaultValue="com.example.app"/>
        <button className="btn btn--primary"><Icon name="plus" size={14}/> Thêm</button>
      </div>
      <button className="btn btn--glass btn--wide"><Icon name="keyboard" size={14}/> Chọn từ ứng dụng đang chạy</button>
    </div>
  );
}

window.GeneralTab = GeneralTab;
window.SmartSwitchTab = SmartSwitchTab;
