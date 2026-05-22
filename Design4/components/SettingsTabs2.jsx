/* eslint-disable */
/* Settings tab content (part 2): Macro / Spell / Stats */

function MacroTab() {
  const macros = [
    { short: 'vn',    long: 'Việt Nam' },
    { short: 'tv',    long: 'Tiếng Việt' },
    { short: 'kg',    long: 'Kính gửi' },
    { short: 'bcao',  long: 'báo cáo' },
    { short: 'cty',   long: 'công ty' },
    { short: 'gd',    long: 'giám đốc' },
    { short: 'sdt',   long: 'số điện thoại' },
    { short: 'cv',    long: 'công việc' },
    { short: 'tphcm', long: 'TP. Hồ Chí Minh' },
  ];

  return (
    <div className="tab-body">
      <div className="set-banner-row">
        <GlassTile color="purple" size="lg" style={{ borderRadius: 14 }}>
          <Icon name="wand" size={28}/>
        </GlassTile>
        <div className="ss-banner-text">
          <div className="ss-banner-title">Macro</div>
          <div className="ss-banner-sub">Viết tắt → cụm dài · gõ "vn " → "Việt Nam "</div>
        </div>
        <Toggle on={true}/>
      </div>

      <div className="set-group macro-table-wrap">
        <div className="macro-head">
          <div className="mh short">Viết tắt</div>
          <div className="mh long">Cụm dài</div>
          <div className="mh act"></div>
        </div>
        {macros.map((m, i) => (
          <div className={`macro-row ${i === 1 ? 'selected' : ''}`} key={m.short}>
            <div className="m-short"><span className="keycap mono">{m.short}</span></div>
            <div className="m-arrow"><Icon name="switch" size={14} color="rgba(255,255,255,0.4)"/></div>
            <div className="m-long">{m.long}</div>
            <button className="icon-btn"><Icon name="trash" size={13} color="rgba(255,150,140,0.7)"/></button>
          </div>
        ))}
      </div>

      <div className="macro-toolbar">
        <button className="btn btn--primary"><Icon name="plus" size={14}/> Thêm</button>
        <button className="btn btn--glass"><Icon name="upload" size={13}/> Xuất</button>
        <button className="btn btn--glass"><Icon name="download" size={13}/> Nhập</button>
        <div style={{flex: 1}}/>
        <div className="macro-count">9 macro</div>
      </div>

      <div className="set-suggest">
        <GlassTile color="gold" size="sm" style={{ borderRadius: 8 }}>
          <Icon name="lightbulb" size={14}/>
        </GlassTile>
        <div className="set-suggest-text">
          <strong>3 đề xuất mới</strong> từ Thống kê — "công ty của tôi", "kính gửi anh chị", "trân trọng cảm ơn"
        </div>
        <button className="btn btn--glass btn--sm">Xem</button>
      </div>
    </div>
  );
}

function SpellTab({ s, setS }) {
  return (
    <div className="tab-body">
      <div className="set-banner-row">
        <GlassTile color="green" size="lg" style={{ borderRadius: 14 }}>
          <Icon name="check" size={28}/>
        </GlassTile>
        <div className="ss-banner-text">
          <div className="ss-banner-title">Chính tả</div>
          <div className="ss-banner-sub">Kiểm tra chính tả 6 bước · Vowel Inclusion · Space Restore</div>
        </div>
        <Toggle on={s.spellMaster} onClick={() => setS({...s, spellMaster: !s.spellMaster})}/>
      </div>

      <div className="set-group">
        <div className="group-title">Cấu hình kiểm tra chính tả</div>
        <Row icon="shield" color="green" label="Kiểm tra chính tả"
             sub="Engine 6-step · chặn gõ dấu sai cấu trúc âm tiết"
             control={<Toggle on={s.spell} onClick={() => setS({...s, spell: !s.spell})}/>}/>
        <Row icon="lightbulb" color="gold" label="Gợi ý sửa lỗi chính tả"
             sub="Levenshtein + heuristic"
             control={<Toggle on={s.suggest} onClick={() => setS({...s, suggest: !s.suggest})}/>}/>
        <Row icon="wand" color="purple" label="Tự động sửa khi tin cậy cao"
             sub="Áp dụng nếu confidence ≥ 88%"
             control={<Toggle on={s.autocorrect} onClick={() => setS({...s, autocorrect: !s.autocorrect})}/>}/>
        <Row icon="person" color="blue" label="Sử dụng từ điển cá nhân"
             sub="3 lists: Allow / Keep / Deny"
             control={
               <div className="row-btns">
                 <button className="btn btn--glass btn--sm">Sửa</button>
                 <button className="btn btn--glass btn--sm">Gửi tác giả</button>
               </div>
             } divider={false}/>
      </div>

      <div className="set-group">
        <div className="group-title">Khôi phục tiếng Anh (Space Restore)</div>
        <Row icon="refresh" color="blue" label="Tự động khôi phục"
             sub="ò → of, ì → if, sê → see, tê → tee"
             control={<Toggle on={s.spaceRestore} onClick={() => setS({...s, spaceRestore: !s.spaceRestore})}/>}/>
        <Row icon="switch" color="gold" label="Chính sách"
             control={
               <Segmented
                 value={s.policy}
                 options={[
                   { value: 'vi', label: 'Tiếng Việt' },
                   { value: 'balanced', label: 'Cân bằng' },
                   { value: 'en', label: 'Tiếng Anh' },
                 ]}
                 onChange={v => setS({...s, policy: v})}
               /> } divider={false}/>
      </div>

      <div className="set-group">
        <div className="group-title">Từ điển từ GitHub</div>
        <div className="dict-status">
          <div className="ds-row">
            <Icon name="flagVn" size={16}/>
            <span>Tiếng Việt:</span>
            <span className="mono">v9</span>
            <span className="ds-count">8,960 từ</span>
          </div>
          <div className="ds-row">
            <Icon name="flagUs" size={16}/>
            <span>Tiếng Anh:</span>
            <span className="mono">v9</span>
            <span className="ds-count">9,826 từ</span>
          </div>
          <button className="btn btn--primary btn--sm">
            <Icon name="refresh" size={13}/> Cập nhật từ điển ngay
          </button>
        </div>
      </div>
    </div>
  );
}

function StatsTab() {
  const topWords = [
    { word: 'không', count: 247, pct: 100 },
    { word: 'được', count: 198, pct: 80 },
    { word: 'người', count: 156, pct: 63 },
    { word: 'những', count: 142, pct: 57 },
    { word: 'việc', count: 128, pct: 52 },
    { word: 'thế', count: 96, pct: 39 },
    { word: 'cũng', count: 84, pct: 34 },
  ];
  const topApps = [
    { name: 'Claude', count: 1240, color: '#D97757', letter: 'C' },
    { name: 'VS Code', count: 892, color: '#007ACC', letter: 'V' },
    { name: 'Safari', count: 564, color: '#1B88FF', letter: 'S' },
    { name: 'Notion', count: 314, color: '#000', letter: 'N' },
  ];

  return (
    <div className="tab-body">
      <div className="set-banner-row">
        <GlassTile color="gold" size="lg" style={{ borderRadius: 14 }}>
          <Icon name="chart" size={28}/>
        </GlassTile>
        <div className="ss-banner-text">
          <div className="ss-banner-title">Thống kê & Sao lưu</div>
          <div className="ss-banner-sub">Tuần 21 năm 2026 · 18/05 → 24/05/2026 · Chỉ lưu cục bộ</div>
        </div>
      </div>

      <div className="kpi-grid">
        <div className="kpi"><div className="kpi-label">Tổng từ</div><div className="kpi-value">3,184</div><div className="kpi-sub">+12% so với tuần trước</div></div>
        <div className="kpi"><div className="kpi-label">Tiếng Việt</div><div className="kpi-value">2,471</div><div className="kpi-sub">77.6%</div></div>
        <div className="kpi"><div className="kpi-label">Macro dùng</div><div className="kpi-value">142</div><div className="kpi-sub">19 macro active</div></div>
        <div className="kpi"><div className="kpi-label">Sửa lỗi</div><div className="kpi-value">63</div><div className="kpi-sub">2% tổng từ</div></div>
      </div>

      <div className="stats-cols">
        <div className="set-group stats-col">
          <div className="group-title">Top từ tiếng Việt</div>
          {topWords.map((w, i) => (
            <div className="stat-row" key={w.word}>
              <span className="stat-rank">{i + 1}</span>
              <div className="stat-meat">
                <div className="stat-word">{w.word}</div>
                <div className="stat-bar"><i style={{ width: `${w.pct}%` }}/></div>
              </div>
              <span className="stat-count">{w.count}</span>
            </div>
          ))}
        </div>

        <div className="set-group stats-col">
          <div className="group-title">Top ứng dụng</div>
          {topApps.map((a, i) => (
            <div className="app-row stat-app" key={a.name}>
              <div className="app-avatar" style={{ background: `linear-gradient(160deg, ${a.color}, color-mix(in srgb, ${a.color} 40%, #000))`, width: 32, height: 32 }}>
                <span style={{ fontSize: 13 }}>{a.letter}</span>
                <div className="app-avatar-gloss"/>
              </div>
              <div className="app-meta">
                <div className="app-name">{a.name}</div>
                <div className="stat-bar"><i style={{ width: `${(a.count / 1240) * 100}%` }}/></div>
              </div>
              <span className="stat-count">{a.count}</span>
            </div>
          ))}
        </div>
      </div>

      <div className="stats-actions">
        <button className="btn btn--glass"><Icon name="upload" size={13}/> Xuất dữ liệu</button>
        <button className="btn btn--glass"><Icon name="download" size={13}/> Nhập từ tệp</button>
        <button className="btn btn--glass"><Icon name="refresh" size={13}/> Chạy compute đề xuất</button>
        <div style={{flex:1}}/>
        <button className="btn btn--glass danger"><Icon name="trash" size={13}/> Xoá thống kê</button>
      </div>
    </div>
  );
}

window.MacroTab = MacroTab;
window.SpellTab = SpellTab;
window.StatsTab = StatsTab;
