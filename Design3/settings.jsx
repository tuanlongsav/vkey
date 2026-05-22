// vkey · settings.jsx — settings window shells for all 5 tabs
// Window chrome mimics macOS Sonoma/Tahoe — title bar + tab bar + content

function WindowChrome({ title = "Cài đặt vkey", children, width = 580, height = 720 }) {
  return (
    <div style={{
      width, height,
      background: 'var(--paper-50)',
      borderRadius: 14,
      boxShadow: 'var(--shadow-window)',
      overflow: 'hidden',
      display: 'flex', flexDirection: 'column',
      border: '0.5px solid rgba(0,0,0,0.18)',
    }}>
      {/* title bar */}
      <div style={{
        height: 38,
        background: 'linear-gradient(180deg, var(--paper-50), var(--paper-100))',
        borderBottom: '0.5px solid var(--border-1)',
        display: 'flex', alignItems: 'center',
        padding: '0 14px',
        position: 'relative',
      }}>
        <div style={{display:'flex', gap: 8}}>
          <div style={{width:12, height:12, borderRadius:'50%', background:'#ff5f56', border:'0.5px solid rgba(0,0,0,0.1)'}} />
          <div style={{width:12, height:12, borderRadius:'50%', background:'#ffbd2e', border:'0.5px solid rgba(0,0,0,0.1)'}} />
          <div style={{width:12, height:12, borderRadius:'50%', background:'#27c93f', border:'0.5px solid rgba(0,0,0,0.1)'}} />
        </div>
        <div style={{
          position:'absolute', left:0, right:0, textAlign:'center',
          fontSize: 13, fontWeight: 600, color: 'var(--fg-2)',
          fontFamily: '-apple-system, "SF Pro Text", sans-serif',
          letterSpacing: '-0.01em',
          pointerEvents: 'none',
        }}>
          <span style={{color:'var(--red-600)', fontFamily:'var(--font-display)', fontWeight:700, fontStyle:'italic'}}>vkey</span>
          <span style={{margin:'0 6px', opacity:0.4}}>·</span>
          <span>{title}</span>
        </div>
      </div>
      {children}
    </div>
  );
}

function TabBar({ active }) {
  const tabs = [
    {id:'chung',   label:'Chung',        icon:'gear'},
    {id:'smart',   label:'Smart Switch', icon:'switch'},
    {id:'macro',   label:'Macro',        icon:'macro'},
    {id:'chinh',   label:'Chính tả',     icon:'spellcheck'},
    {id:'thong',   label:'Thống kê',     icon:'chart'},
  ];
  return (
    <div style={{
      padding: '12px 16px 6px',
      background: 'var(--paper-50)',
      borderBottom: '0.5px solid var(--border-1)',
    }}>
      <div className="tabbar">
        {tabs.map(t => (
          <button key={t.id} className={"tab" + (active === t.id ? " is-active" : "")}>
            <Icon name={t.icon} size={13} color={active === t.id ? 'var(--red-600)' : 'currentColor'} />
            <span>{t.label}</span>
          </button>
        ))}
      </div>
    </div>
  );
}

// ──────────────────────────────────────────────────────────
// Row primitives
// ──────────────────────────────────────────────────────────
function Row({ icon, label, hint, children, dense, accent }) {
  return (
    <div className="row" style={dense ? {padding:'8px 14px'} : undefined}>
      {icon && <div className="row__icon" style={accent ? {background:'color-mix(in srgb, var(--red-500) 14%, transparent)', color:'var(--red-600)'} : undefined}><Icon name={icon} size={15} /></div>}
      <div className="row__body">
        <div className="row__label">{label}</div>
        {hint && <div className="row__hint">{hint}</div>}
      </div>
      {children && <div style={{flex:'none', display:'flex', gap:8, alignItems:'center'}}>{children}</div>}
    </div>
  );
}

function Section({ title, children, style }) {
  return (
    <div style={style}>
      {title && <div className="section-title">{title}</div>}
      <div className="row-group">{children}</div>
    </div>
  );
}

function Toggle({ checked = true }) {
  return <input type="checkbox" className="toggle" defaultChecked={checked} readOnly />;
}

function Segmented({ options, active }) {
  return (
    <div className="segmented">
      {options.map(o => (
        <button key={o} className={active === o ? "is-active" : ""}>{o}</button>
      ))}
    </div>
  );
}

function ShortcutBadge({ keys }) {
  return (
    <div style={{display:'flex', gap:4, alignItems:'center'}}>
      {keys.map((k,i) => <span key={i} className="kbd">{k}</span>)}
    </div>
  );
}

// ══════════════════════════════════════════════════════════
// TAB 1 · Chung (General)
// ══════════════════════════════════════════════════════════
function TabChung() {
  return (
    <div style={{padding:'12px 16px 24px', overflowY:'auto', flex:1}}>
      <Section title="Bộ gõ">
        <Row icon="flag-vn" accent label="Bật / Tắt gõ Tiếng Việt" hint="Tắt để gõ thẳng tiếng Anh"><Toggle /></Row>
        <Row icon="telex" label="Kiểu gõ" hint="Telex phổ biến hơn, VNI dùng phím số">
          <Segmented options={['Telex','VNI']} active="Telex" />
        </Row>
        <Row icon="diacritic" label="Kiểu đặt dấu" hint="thuỷ / khoẻ / hoà vs thủy / khỏe / hòa">
          <Segmented options={['Kiểu mới','Kiểu cũ']} active="Kiểu mới" />
        </Row>
        <Row icon="magic-wand" label="Tự động sửa lỗi gõ nhầm" hint="thfi → thì, veeitj → việt, phuowgn → phương"><Toggle /></Row>
        <Row icon="keyboard" label="Cho phép z, w, j, f là phụ âm hợp lệ"><Toggle checked={false} /></Row>
      </Section>

      <Section title="Phím tắt">
        <Row icon="command" label="Toggle VI / EN" hint="Nhấn-thả modifier hoặc tổ hợp phím">
          <ShortcutBadge keys={['⌃','⇧']} />
        </Row>
        <Row icon="sparkle" label="Text Tools" hint="UPPERCASE, lowercase, Title, bỏ dấu">
          <ShortcutBadge keys={['⌃','⇧','T']} />
        </Row>
      </Section>

      <Section title="Hiển thị">
        <Row icon="info" label="Hiển thị HUD khi chuyển VI / EN"><Toggle /></Row>
        <Row icon="lightbulb" label="Cỡ chữ HUD đoán từ" hint="10 – 20pt, hiện tại 14pt">
          <div style={{display:'flex', alignItems:'center', gap:6}}>
            <button className="btn btn--icon"><Icon name="minus" size={12}/></button>
            <span style={{minWidth:32, textAlign:'center', fontFamily:'var(--font-mono)', fontSize:13}}>14</span>
            <button className="btn btn--icon"><Icon name="plus" size={12}/></button>
          </div>
        </Row>
        <Row icon="globe" label="Độ đậm HUD" hint="50 – 100%">
          <div style={{display:'flex', alignItems:'center', gap:6}}>
            <button className="btn btn--icon"><Icon name="minus" size={12}/></button>
            <span style={{minWidth:32, textAlign:'center', fontFamily:'var(--font-mono)', fontSize:13}}>85%</span>
            <button className="btn btn--icon"><Icon name="plus" size={12}/></button>
          </div>
        </Row>
      </Section>

      <Section title="Hệ thống">
        <Row icon="gear" label="Tự khởi động cùng macOS"><Toggle /></Row>
        <Row icon="shield" label="Tự bypass khi bật secure input" hint="Tự động dừng khi gõ password"><Toggle /></Row>
      </Section>
    </div>
  );
}

// ══════════════════════════════════════════════════════════
// TAB 2 · Smart Switch
// ══════════════════════════════════════════════════════════
function StateBadge({ state, source }) {
  const map = {
    vn: {icon:'flag-vn', label:'Tiếng Việt', cls:'badge--success'},
    en: {icon:'flag-en', label:'Tiếng Anh',  cls:'badge--info'},
    no: {icon:'ban',     label:'Không dùng', cls:'badge--danger'},
    auto: {icon:'robot', label:'Tự quyết',   cls:''},
  }[state];
  return (
    <div style={{display:'flex', alignItems:'center', gap:6}}>
      <button className="btn btn--sm" style={{paddingLeft:8, paddingRight:8}}>
        <Icon name={map.icon} size={14} />
        <span>{map.label}</span>
        <Icon name="chevron-down" size={10} color="var(--fg-muted)" />
      </button>
      <span title={source === 'user' ? 'User đặt thủ công' : 'vkey tự học'} style={{
        width:18, height:18, display:'flex', alignItems:'center', justifyContent:'center',
        borderRadius:'50%',
        background: source === 'user' ? 'var(--paper-200)' : 'color-mix(in srgb, var(--indigo-500) 16%, transparent)',
        color: source === 'user' ? 'var(--fg-2)' : 'var(--indigo-700)',
      }}>
        <Icon name={source === 'user' ? 'person' : 'robot'} size={11} />
      </span>
    </div>
  );
}

function TabSmart() {
  const apps = [
    {bundle:'com.apple.Terminal', name:'Terminal', state:'en', source:'user'},
    {bundle:'com.googlecode.iterm2', name:'iTerm2', state:'en', source:'user'},
    {bundle:'com.microsoft.VSCode', name:'Visual Studio Code', state:'en', source:'auto', stats:'84% EN · 6d'},
    {bundle:'com.anthropic.claudefordesktop', name:'Claude', state:'vn', source:'auto', stats:'91% VN · 14d'},
    {bundle:'com.tinyspeck.slackmacgap', name:'Slack', state:'vn', source:'user'},
    {bundle:'notion.id', name:'Notion', state:'vn', source:'auto', stats:'78% VN · 9d'},
    {bundle:'com.figma.Desktop', name:'Figma', state:'no', source:'user'},
    {bundle:'com.spotify.client', name:'Spotify', state:'no', source:'user'},
    {bundle:'com.tdesktop.Telegram', name:'Telegram', state:'vn', source:'auto', stats:'95% VN · 21d'},
  ];
  return (
    <div style={{padding:'12px 16px 24px', overflowY:'auto', flex:1}}>
      <Section>
        <Row icon="switch" accent label="Bật Smart Switch" hint="3-state per-app · auto-learn từ Thống kê"><Toggle /></Row>
      </Section>

      <div className="section-title">
        Danh sách ứng dụng <span style={{textTransform:'none', letterSpacing:0, color:'var(--fg-3)', fontWeight:400, marginLeft:'auto'}}>9 mục</span>
      </div>

      {/* Filter bar */}
      <div style={{display:'flex', gap:6, marginBottom:8, alignItems:'center'}}>
        <div style={{flex:1, display:'flex', alignItems:'center', gap:6, padding:'0 10px', background:'var(--bg-card)', border:'1px solid var(--border-2)', borderRadius:'var(--r-sm)', height:28}}>
          <Icon name="search" size={13} color="var(--fg-muted)" />
          <input style={{flex:1, border:0, background:'transparent', outline:'none', fontSize:12.5, color:'var(--fg-1)'}} placeholder="Tìm ứng dụng hoặc bundle ID..." />
        </div>
        <button className="btn btn--sm"><Icon name="plus" size={12}/>Thêm</button>
        <button className="btn btn--sm"><Icon name="robot" size={12}/>Tự học</button>
      </div>

      <div className="row-group">
        {apps.map((a,i) => (
          <div key={a.bundle} className="row" style={{padding:'8px 12px'}}>
            <div style={{
              width: 28, height: 28, borderRadius: 7,
              background: 'linear-gradient(135deg, var(--paper-200), var(--paper-300))',
              display:'flex', alignItems:'center', justifyContent:'center',
              fontFamily:'var(--font-display)', fontWeight:700, fontSize:13,
              color:'var(--ink-300)', flex:'none',
            }}>{a.name[0]}</div>
            <div className="row__body">
              <div className="row__label" style={{fontSize:12.5}}>{a.name}</div>
              <div className="row__hint" style={{fontFamily:'var(--font-mono)', fontSize:10.5}}>
                {a.bundle}
                {a.stats && <span style={{marginLeft:8, color:'var(--indigo-500)'}}>· {a.stats}</span>}
              </div>
            </div>
            <StateBadge state={a.state} source={a.source} />
            <button className="btn btn--icon btn--ghost" style={{color:'var(--danger)'}}><Icon name="trash" size={13}/></button>
          </div>
        ))}
      </div>

      <div style={{
        marginTop: 16, padding: 12,
        background: 'color-mix(in srgb, var(--info) 8%, var(--bg-card))',
        border: '1px solid color-mix(in srgb, var(--info) 24%, transparent)',
        borderRadius: 'var(--r-md)',
        display:'flex', gap: 10, alignItems:'flex-start',
      }}>
        <Icon name="info" size={16} color="var(--info)" style={{marginTop:1}}/>
        <div style={{flex:1, fontSize:12, color:'var(--fg-2)', lineHeight:1.5}}>
          <strong style={{color:'var(--fg-1)'}}>Auto-learn</strong> chạy 1 lần/ngày khi launch. Ngưỡng: ≥1 ngày dataset · ≥5 commit/ngày · ratio ≥75%. Entries 👤 user-set luôn được giữ nguyên.
        </div>
      </div>
    </div>
  );
}

// ══════════════════════════════════════════════════════════
// TAB 3 · Macro
// ══════════════════════════════════════════════════════════
function TabMacro() {
  const macros = [
    {short:'vn',     long:'Việt Nam',                                tag:'default'},
    {short:'kg',     long:'Kính gửi',                                tag:'default'},
    {short:'kga',    long:'Kính gửi Anh',                            tag:'suggest'},
    {short:'cty',    long:'công ty',                                 tag:'default'},
    {short:'ct',     long:'công ty của tôi',                         tag:'suggest'},
    {short:'sdt',    long:'số điện thoại',                           tag:'default'},
    {short:'bcao',   long:'báo cáo',                                 tag:'default'},
    {short:'tvd',    long:'tuanlong.sav@gmail.com',                  tag:'user'},
    {short:'addr',   long:'Số 1, Cầu Giấy, Hà Nội',                  tag:'user'},
  ];
  return (
    <div style={{padding:'12px 16px 24px', overflowY:'auto', flex:1}}>
      <Section>
        <Row icon="macro" accent label="Bật Macro" hint="Gõ viết tắt + Space → cụm dài"><Toggle /></Row>
      </Section>

      <div className="section-title">
        Danh sách macro <span style={{textTransform:'none', letterSpacing:0, color:'var(--fg-3)', fontWeight:400, marginLeft:'auto'}}>9 / 19 mặc định + 2 user</span>
      </div>

      {/* toolbar */}
      <div style={{display:'flex', gap:6, marginBottom:8}}>
        <button className="btn btn--sm btn--primary"><Icon name="plus" size={12}/>Thêm</button>
        <button className="btn btn--sm"><Icon name="trash" size={12}/>Xoá</button>
        <div style={{flex:1}} />
        <button className="btn btn--sm"><Icon name="download" size={12}/>Nhập</button>
        <button className="btn btn--sm"><Icon name="upload" size={12}/>Xuất</button>
      </div>

      <div className="row-group">
        {/* table header */}
        <div style={{
          display:'grid', gridTemplateColumns:'120px 1fr 80px',
          padding:'8px 14px',
          background:'var(--bg-sunken)',
          fontSize:11, fontWeight:600, color:'var(--fg-muted)',
          letterSpacing:'0.08em', textTransform:'uppercase',
          borderBottom: '1px solid var(--border-1)',
        }}>
          <span>Viết tắt</span>
          <span>Cụm dài</span>
          <span style={{textAlign:'right'}}>Nguồn</span>
        </div>
        {macros.map((m,i) => (
          <div key={m.short} className="row" style={{padding:'7px 14px', display:'grid', gridTemplateColumns:'120px 1fr 80px', gap:8, alignItems:'center'}}>
            <span className="kbd" style={{justifySelf:'start', fontSize:11.5}}>{m.short}</span>
            <span style={{fontSize:13, color:'var(--fg-1)'}}>{m.long}</span>
            <span style={{justifySelf:'end'}} className={"badge " + (m.tag === 'user' ? "badge--brand" : m.tag === 'suggest' ? "badge--warning" : "")}>
              {m.tag === 'user' ? 'User' : m.tag === 'suggest' ? 'Gợi ý' : 'Mặc định'}
            </span>
          </div>
        ))}
      </div>

      <div style={{
        marginTop: 16, padding: 12,
        background: 'color-mix(in srgb, var(--gold-500) 10%, var(--bg-card))',
        border: '1px solid color-mix(in srgb, var(--gold-500) 30%, transparent)',
        borderRadius: 'var(--r-md)',
        display:'flex', gap: 10, alignItems:'center',
      }}>
        <Icon name="lightbulb" size={18} color="var(--gold-600)" />
        <div style={{flex:1, fontSize:12.5, color:'var(--fg-2)'}}>
          Phát hiện <strong style={{color:'var(--fg-1)'}}>3 cụm bạn gõ ≥10 lần</strong> tuần này chưa có macro.
        </div>
        <button className="btn btn--sm btn--primary">Xem &amp; thêm</button>
      </div>
    </div>
  );
}

// ══════════════════════════════════════════════════════════
// TAB 4 · Chính tả (Spellcheck)
// ══════════════════════════════════════════════════════════
function TabChinhTa() {
  return (
    <div style={{padding:'12px 16px 24px', overflowY:'auto', flex:1}}>
      <Section title="Phím tắt thông minh">
        <Row icon="sparkle" accent label="Kích hoạt nhanh tất cả tính năng" hint="Master toggle gộp cho mọi tính năng chính tả"><Toggle /></Row>
      </Section>

      <Section title="Cấu hình kiểm tra chính tả">
        <Row icon="spellcheck" label="Kiểm tra chính tả 6 bước" hint="Vowel Inclusion Pairs · Impossible Clusters"><Toggle /></Row>
        <Row icon="check" label="Gợi ý sửa lỗi chính tả"><Toggle /></Row>
        <Row icon="sparkle" label="Tự động sửa khi tin cậy cao" hint="Áp dụng khi confidence ≥ 88%" dense><Toggle checked={false}/></Row>
        <Row icon="dictionary" label="Sử dụng từ điển cá nhân" hint="Allow / Keep / Deny lists">
          <button className="btn btn--sm">Sửa</button>
          <button className="btn btn--sm">Gửi cho tác giả</button>
        </Row>
        <Row icon="lightbulb" label="Tự động compute đề xuất hàng tuần">
          <Toggle />
          <button className="btn btn--sm">Xem (12)</button>
        </Row>
      </Section>

      <Section title="Đoán từ tiếp theo">
        <Row icon="tab-key" label="HUD dự đoán cạnh caret" hint="Tab để chấp nhận · phím khác bỏ qua"><Toggle /></Row>
        <Row icon="info" label="Khoảng cách HUD đến caret" hint="1 – 10 dòng" dense>
          <div style={{display:'flex', alignItems:'center', gap:6}}>
            <button className="btn btn--icon"><Icon name="minus" size={12}/></button>
            <span style={{minWidth:32, textAlign:'center', fontFamily:'var(--font-mono)', fontSize:13}}>4</span>
            <button className="btn btn--icon"><Icon name="plus" size={12}/></button>
          </div>
        </Row>
      </Section>

      <Section title="Khôi phục tiếng Anh (Space Restore)">
        <Row icon="backspace" label="Tự khôi phục khi Space" hint="ò → of, ì → if, sê → see"><Toggle /></Row>
        <Row icon="switch" label="Chính sách khôi phục" dense>
          <Segmented options={['Ưu tiên VN','Cân bằng','Ưu tiên EN']} active="Cân bằng" />
        </Row>
      </Section>

      <Section title="Từ điển từ GitHub">
        <div style={{padding:'12px 14px'}}>
          <div style={{display:'flex', gap:16}}>
            <div style={{flex:1}}>
              <div style={{fontSize:11, fontWeight:600, color:'var(--fg-muted)', letterSpacing:'0.06em', textTransform:'uppercase'}}>Tiếng Việt</div>
              <div style={{display:'flex', alignItems:'baseline', gap:8, marginTop:4}}>
                <span style={{font:'700 22px/1 var(--font-display)', color:'var(--red-600)', fontStyle:'italic'}}>8,960</span>
                <span style={{fontSize:12, color:'var(--fg-muted)'}}>syllables · v9</span>
              </div>
            </div>
            <div style={{flex:1}}>
              <div style={{fontSize:11, fontWeight:600, color:'var(--fg-muted)', letterSpacing:'0.06em', textTransform:'uppercase'}}>Tiếng Anh</div>
              <div style={{display:'flex', alignItems:'baseline', gap:8, marginTop:4}}>
                <span style={{font:'700 22px/1 var(--font-display)', color:'var(--indigo-500)', fontStyle:'italic'}}>9,826</span>
                <span style={{fontSize:12, color:'var(--fg-muted)'}}>từ · v9</span>
              </div>
            </div>
          </div>
          <div style={{display:'flex', gap:8, marginTop:12, alignItems:'center'}}>
            <button className="btn btn--sm"><Icon name="refresh" size={12}/>Cập nhật ngay</button>
            <span style={{fontSize:11.5, color:'var(--fg-muted)'}}>Lần check cuối: hôm nay 09:12</span>
          </div>
        </div>
      </Section>
    </div>
  );
}

// ══════════════════════════════════════════════════════════
// TAB 5 · Thống kê
// ══════════════════════════════════════════════════════════
function StatBar({ label, value, max, color }) {
  return (
    <div style={{display:'grid', gridTemplateColumns:'120px 1fr 60px', gap:10, alignItems:'center', padding:'5px 0'}}>
      <span style={{fontSize:12.5, color:'var(--fg-1)'}}>{label}</span>
      <div style={{height:8, background:'var(--bg-sunken)', borderRadius:999, overflow:'hidden'}}>
        <div style={{width: (value/max*100)+'%', height:'100%', background: color, borderRadius:999}} />
      </div>
      <span style={{fontSize:12, fontFamily:'var(--font-mono)', color:'var(--fg-muted)', textAlign:'right'}}>{value.toLocaleString()}</span>
    </div>
  );
}

function TabThongKe() {
  const vnWords = [
    ['không', 412], ['của', 388], ['được', 342], ['mình', 287], ['nhưng', 256],
    ['cũng', 234], ['nhé', 219], ['rồi', 198], ['lắm', 184], ['thì', 167],
  ];
  const vnPhrases = [
    ['công ty', 84], ['của tôi', 72], ['cảm ơn anh', 58], ['kính gửi', 47], ['của mình', 41],
  ];
  const apps = [
    ['Claude', 4280, 'var(--red-500)'],
    ['Slack', 2840, 'var(--indigo-500)'],
    ['VS Code', 1920, 'var(--jade-500)'],
    ['Notion', 1240, 'var(--gold-500)'],
    ['Telegram', 980, 'var(--paper-500)'],
  ];
  return (
    <div style={{padding:'12px 16px 24px', overflowY:'auto', flex:1}}>
      {/* Week header */}
      <div style={{
        padding: '14px 16px',
        background: 'linear-gradient(135deg, var(--red-500), var(--red-700))',
        color: '#fff',
        borderRadius: 'var(--r-md)',
        marginBottom: 12,
        position: 'relative', overflow: 'hidden',
      }}>
        <div style={{
          position:'absolute', right:-20, top:-20,
          width:120, height:120,
          background:'radial-gradient(circle, rgba(245,215,133,0.35), transparent 60%)',
        }}/>
        <div style={{fontSize:11, opacity:0.75, letterSpacing:'0.08em', textTransform:'uppercase'}}>Tuần này</div>
        <div style={{font:'700 18px/1.2 var(--font-display)', fontStyle:'italic', marginTop:4}}>
          Tuần 21 năm 2026
        </div>
        <div style={{fontSize:12.5, opacity:0.85, marginTop:2}}>18/05 → 24/05 · Thứ Sáu</div>
        <div style={{display:'flex', gap:16, marginTop:14}}>
          <div>
            <div style={{font:'700 26px/1 var(--font-display)', fontStyle:'italic'}}>11,260</div>
            <div style={{fontSize:10.5, opacity:0.75, letterSpacing:'0.06em', textTransform:'uppercase'}}>Tổng từ</div>
          </div>
          <div style={{width:1, background:'rgba(255,255,255,0.18)'}}/>
          <div>
            <div style={{font:'700 26px/1 var(--font-display)', fontStyle:'italic'}}>8.4k</div>
            <div style={{fontSize:10.5, opacity:0.75, letterSpacing:'0.06em', textTransform:'uppercase'}}>Tiếng Việt</div>
          </div>
          <div style={{width:1, background:'rgba(255,255,255,0.18)'}}/>
          <div>
            <div style={{font:'700 26px/1 var(--font-display)', fontStyle:'italic'}}>2.8k</div>
            <div style={{fontSize:10.5, opacity:0.75, letterSpacing:'0.06em', textTransform:'uppercase'}}>Tiếng Anh</div>
          </div>
        </div>
      </div>

      {/* Sao lưu */}
      <Section>
        <Row icon="upload" label="Xuất dữ liệu cá nhân" hint="JSON: Cài đặt + Macro + Smart Switch + Stats">
          <button className="btn btn--sm btn--primary">Xuất</button>
        </Row>
        <Row icon="download" label="Nhập từ tệp sao lưu" dense>
          <Segmented options={['Gộp thêm','Ghi đè']} active="Gộp thêm" />
          <button className="btn btn--sm">Chọn file...</button>
        </Row>
      </Section>

      <div className="section-title">Top từ tiếng Việt</div>
      <div className="row-group" style={{padding:'10px 14px'}}>
        {vnWords.slice(0,5).map(([w,n]) =>
          <StatBar key={w} label={w} value={n} max={420} color="var(--red-500)" />
        )}
      </div>

      <div className="section-title">Top cụm 2-3 từ</div>
      <div className="row-group" style={{padding:'10px 14px'}}>
        {vnPhrases.map(([w,n]) =>
          <StatBar key={w} label={w} value={n} max={90} color="var(--gold-500)" />
        )}
      </div>

      <div className="section-title">Top ứng dụng</div>
      <div className="row-group" style={{padding:'10px 14px'}}>
        {apps.map(([w,n,c]) =>
          <StatBar key={w} label={w} value={n} max={4500} color={c} />
        )}
      </div>
    </div>
  );
}

// ──────────────────────────────────────────────────────────
// Settings window per-tab artboard wrapper
// ──────────────────────────────────────────────────────────
function SettingsArtboard({ tab }) {
  const tabs = {
    chung:  {comp: TabChung,    title: 'Chung'},
    smart:  {comp: TabSmart,    title: 'Smart Switch'},
    macro:  {comp: TabMacro,    title: 'Macro'},
    chinh:  {comp: TabChinhTa,  title: 'Chính tả'},
    thong:  {comp: TabThongKe,  title: 'Thống kê & Sao lưu'},
  };
  const T = tabs[tab];
  return (
    <WindowChrome title={T.title}>
      <TabBar active={tab} />
      <T.comp />
    </WindowChrome>
  );
}

Object.assign(window, { SettingsArtboard, WindowChrome, TabBar });
