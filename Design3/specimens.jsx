// vkey · specimens.jsx — palette, type, icon overview, app-icon grid

// Palette swatch
function Swatch({ name, value, lg }) {
  const dark = lg && (
    parseInt(value.slice(1,3),16)*0.299 + parseInt(value.slice(3,5),16)*0.587 + parseInt(value.slice(5,7),16)*0.114
  ) < 130;
  return (
    <div style={{
      flex: 1, minWidth: 0,
      padding: lg ? '20px 14px' : '14px 12px',
      background: value, borderRadius: lg ? 12 : 8,
      color: dark ? '#fff' : 'var(--ink-500)',
      display:'flex', flexDirection:'column', justifyContent:'space-between',
      height: lg ? 120 : 80,
      boxShadow: 'inset 0 0 0 1px rgba(0,0,0,0.06)',
    }}>
      <div style={{fontWeight:600, fontSize: lg ? 14 : 12, opacity:0.92}}>{name}</div>
      <div style={{
        fontFamily:'var(--font-mono)', fontSize: lg ? 12 : 10.5,
        opacity:0.75,
      }}>{value}</div>
    </div>
  );
}

function PaletteArtboard() {
  const red = [
    ['50',  '#FBEBE7'],['100','#F5D2C9'],['200','#ECA89A'],['300','#DD7867'],['400','#CB4F3D'],
    ['500','#B5302A'],['600','#962219'],['700','#7E1C16'],['800','#5A1410'],['900','#3A0E0A'],
  ];
  const gold = [
    ['100','#F8EDC8'],['200','#EFD78F'],['300','#E0BC5E'],['400','#C49A4A'],['500','#A07C32'],['600','#7A5D22'],
  ];
  const paper = [
    ['0',  '#FFFFFF'],['50', '#FAF6EC'],['100','#F4EFE3'],['200','#EAE3D2'],['300','#D6CCB3'],['400','#B0A687'],['500','#847B62'],
  ];
  const ink = [
    ['50', '#6A6358'],['100','#463F35'],['200','#2E2820'],['300','#221E18'],['400','#1A1612'],['500','#131110'],['600','#0B0A09'],
  ];
  const semantic = [
    ['Success', '#0E7A5F'],['Warning', '#A07C32'],['Danger', '#B53033'],['Info', '#1F4F7A'],
  ];
  return (
    <div style={{padding: 36, background: 'var(--paper-100)', width: 1080, minHeight: 720}}>
      <div style={{display:'flex', alignItems:'baseline', gap:14, marginBottom:6}}>
        <div className="eyebrow" style={{fontFamily:'var(--font-sans)', fontSize:11, fontWeight:600, letterSpacing:'0.14em', textTransform:'uppercase', color:'var(--fg-muted)'}}>vkey · Sơn Mài</div>
        <div style={{height:1, flex:1, background:'var(--border-1)'}}/>
      </div>
      <div style={{font:'700 44px/1.05 var(--font-display)', fontStyle:'italic', color:'var(--ink-500)', letterSpacing:'-0.02em'}}>Bảng màu</div>
      <div style={{fontSize:14.5, color:'var(--fg-3)', maxWidth:680, marginTop:8, lineHeight:1.5}}>
        Tông sơn mài truyền thống Việt Nam — đỏ lacquer sâu, vàng thếp, men ngọc, vỏ trứng cream. Ink ấm, không pha xanh. Mọi token đều available ở light + dark mode.
      </div>

      <div className="section-title" style={{margin:'28px 0 8px'}}>Brand · Lacquer Red</div>
      <div style={{display:'flex', gap:8}}>{red.map(([n,v]) => <Swatch key={n} name={n} value={v} />)}</div>

      <div style={{display:'grid', gridTemplateColumns:'1fr 1fr', gap:28, marginTop: 28}}>
        <div>
          <div className="section-title" style={{margin:'0 0 8px'}}>Gold Leaf · accent</div>
          <div style={{display:'flex', gap:6}}>{gold.map(([n,v]) => <Swatch key={n} name={n} value={v} />)}</div>
        </div>
        <div>
          <div className="section-title" style={{margin:'0 0 8px'}}>Semantic</div>
          <div style={{display:'flex', gap:6}}>{semantic.map(([n,v]) => <Swatch key={n} name={n} value={v} />)}</div>
        </div>
      </div>

      <div className="section-title" style={{margin:'28px 0 8px'}}>Paper · neutral light</div>
      <div style={{display:'flex', gap:6}}>{paper.map(([n,v]) => <Swatch key={n} name={n} value={v} />)}</div>

      <div className="section-title" style={{margin:'28px 0 8px'}}>Ink · neutral dark</div>
      <div style={{display:'flex', gap:6}}>{ink.map(([n,v]) => <Swatch key={n} name={n} value={v} />)}</div>
    </div>
  );
}

// ──────────────────────────────────────────────────────────
// Type specimen
// ──────────────────────────────────────────────────────────
function TypeArtboard() {
  return (
    <div style={{padding:36, background:'var(--paper-100)', width:1080, minHeight:720, color:'var(--ink-500)'}}>
      <div style={{display:'flex', alignItems:'baseline', gap:14, marginBottom:6}}>
        <div style={{fontSize:11, fontWeight:600, letterSpacing:'0.14em', textTransform:'uppercase', color:'var(--fg-muted)'}}>vkey · Typography</div>
        <div style={{height:1, flex:1, background:'var(--border-1)'}}/>
      </div>
      <div style={{font:'700 44px/1.05 var(--font-display)', fontStyle:'italic', letterSpacing:'-0.02em'}}>Chữ pháp</div>

      {/* Display row */}
      <div style={{marginTop:36}}>
        <div className="section-title" style={{margin:'0 0 8px'}}>Display · Fraunces Italic</div>
        <div style={{font:'700 88px/0.95 var(--font-display)', fontStyle:'italic', letterSpacing:'-0.03em'}}>
          Tiếng Việt nhẹ tênh.
        </div>
      </div>

      {/* Headings */}
      <div style={{marginTop:32, display:'grid', gridTemplateColumns:'1fr 1fr', gap: 32}}>
        <div>
          <div className="section-title" style={{margin:'0 0 12px'}}>Heading · Be Vietnam Pro</div>
          <div style={{font:'700 36px/1.12 var(--font-sans)', letterSpacing:'-0.02em'}}>Bộ gõ trầm hương</div>
          <div style={{font:'600 26px/1.2 var(--font-sans)', letterSpacing:'-0.015em', marginTop:14}}>Telex, VNI, Smart Switch</div>
          <div style={{font:'600 19px/1.3 var(--font-sans)', letterSpacing:'-0.01em', marginTop:10}}>Tự sửa lỗi gõ nhầm</div>
          <div style={{font:'600 15px/1.35 var(--font-sans)', marginTop:8}}>Cấu hình kiểm tra chính tả</div>
        </div>
        <div>
          <div className="section-title" style={{margin:'0 0 12px'}}>Body · Be Vietnam Pro</div>
          <p style={{font:'400 16px/1.6 var(--font-sans)', color:'var(--fg-2)', margin:0}}>
            vkey là một bộ gõ tiếng Việt cá nhân, đơn giản, cho macOS. Viết bằng Swift native, chạy như một app menu bar nhỏ gọn.
          </p>
          <p style={{font:'400 14px/1.55 var(--font-sans)', color:'var(--fg-2)', margin:'10px 0 0'}}>
            Từ điển 8,960 syllables tiếng Việt + 9,826 từ tiếng Anh. Tự fetch từ GitHub, không telemetry, không gửi data đi đâu.
          </p>
          <p style={{font:'400 12.5px/1.5 var(--font-sans)', color:'var(--fg-muted)', margin:'10px 0 0'}}>
            Diacritics: à á ả ã ạ · ă ằ ắ ẳ ẵ ặ · â ầ ấ ẩ ẫ ậ · đ · ê ề ế ể ễ ệ · ô ồ ố ổ ỗ ộ · ơ ờ ớ ở ỡ ợ · ư ừ ứ ử ữ ự.
          </p>
        </div>
      </div>

      {/* Mono */}
      <div style={{marginTop:32}}>
        <div className="section-title" style={{margin:'0 0 8px'}}>Mono · JetBrains Mono</div>
        <div style={{
          background:'var(--ink-500)', color:'var(--paper-100)',
          padding: '16px 20px', borderRadius:12,
          font:'500 14px/1.7 var(--font-mono)',
        }}>
          <span style={{color:'#9C937C'}}>// telex parse</span><br/>
          <span style={{color:'#E0BC5E'}}>let</span> <span style={{color:'#DD7867'}}>tieengs</span> = <span style={{color:'#6FB394'}}>"tiếng"</span> <span style={{color:'#9C937C'}}>// 7 keys → 1 syllable in ~92 ms</span>
        </div>
      </div>

      {/* Sizes */}
      <div style={{marginTop:32}}>
        <div className="section-title" style={{margin:'0 0 8px'}}>Scale</div>
        <div style={{display:'flex', gap:10, alignItems:'baseline', flexWrap:'wrap'}}>
          {[
            ['t-brand',  '64', 'fraunces'],
            ['display',  '60', 'sans 800'],
            ['h1', '36', 'sans 700'],
            ['h2', '26', 'sans 600'],
            ['h3', '19', 'sans 600'],
            ['h4', '15', 'sans 600'],
            ['body', '14', 'sans 400'],
            ['small', '12.5', 'sans 400'],
            ['micro', '11', 'sans 500'],
          ].map(([n,s,d]) => (
            <div key={n} style={{
              padding:'8px 12px',
              background:'var(--bg-card)',
              border:'1px solid var(--border-1)',
              borderRadius:8,
              fontSize:11.5, color:'var(--fg-3)',
              fontFamily:'var(--font-mono)',
            }}>
              {n} · <strong style={{color:'var(--fg-1)'}}>{s}</strong>px · {d}
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

// ──────────────────────────────────────────────────────────
// Icon grid
// ──────────────────────────────────────────────────────────
function IconArtboard() {
  const groups = [
    ['Mode · status',   ['flag-vn','flag-en','lock','lock-open','shield']],
    ['Bộ gõ',           ['telex','vni','diacritic','magic-wand','keyboard']],
    ['Tab nav',         ['gear','switch','macro','spellcheck','chart']],
    ['Smart Switch',    ['robot','person','ban']],
    ['Actions',         ['plus','minus','trash','edit','download','upload','refresh','search']],
    ['Feedback',        ['check','info','warn','lightbulb']],
    ['Misc',            ['dictionary','globe','command','sparkle','tab-key','esc-key','backspace','menu-bar','donate','external']],
    ['Navigation',      ['chevron-down','chevron-right','x']],
  ];
  return (
    <div style={{padding:36, background:'var(--paper-100)', width:1080, minHeight:720, color:'var(--ink-500)'}}>
      <div style={{display:'flex', alignItems:'baseline', gap:14, marginBottom:6}}>
        <div style={{fontSize:11, fontWeight:600, letterSpacing:'0.14em', textTransform:'uppercase', color:'var(--fg-muted)'}}>vkey · Iconography</div>
        <div style={{height:1, flex:1, background:'var(--border-1)'}}/>
      </div>
      <div style={{display:'flex', alignItems:'baseline', gap:16}}>
        <div style={{font:'700 44px/1.05 var(--font-display)', fontStyle:'italic', letterSpacing:'-0.02em'}}>Bộ icon</div>
        <div style={{fontSize:13.5, color:'var(--fg-3)'}}>
          <strong style={{color:'var(--fg-1)'}}>42 glyphs</strong> · 24×24 viewBox · stroke 1.6 · rounded caps
        </div>
      </div>
      <div style={{fontSize:14, color:'var(--fg-3)', maxWidth:680, marginTop:6, lineHeight:1.5}}>
        Light geometric line set với key glyphs đặc thù cho IME tiếng Việt — diacritic, telex/vni, key caps, Smart Switch states.
      </div>

      <div style={{marginTop:24, display:'grid', gridTemplateColumns:'1fr 1fr', gap: 16}}>
        {groups.map(([title, list]) => (
          <div key={title}>
            <div className="section-title" style={{margin:'4px 0 8px'}}>{title} · {list.length}</div>
            <div className="row-group" style={{padding:'10px', display:'grid', gridTemplateColumns:'repeat(5, 1fr)', gap:4}}>
              {list.map(n => (
                <div key={n} style={{
                  display:'flex', flexDirection:'column', alignItems:'center', gap:6,
                  padding:'10px 4px', borderRadius:6,
                }}>
                  <Icon name={n} size={22} color="var(--ink-400)" />
                  <span style={{fontSize:10, fontFamily:'var(--font-mono)', color:'var(--fg-muted)', textAlign:'center', overflow:'hidden', textOverflow:'ellipsis', maxWidth:'100%', whiteSpace:'nowrap'}}>{n}</span>
                </div>
              ))}
            </div>
          </div>
        ))}
      </div>

      {/* Construction notes */}
      <div style={{marginTop:24, padding:16, background:'var(--bg-card)', border:'1px solid var(--border-1)', borderRadius:12, display:'grid', gridTemplateColumns:'1fr 1fr 1fr', gap:24}}>
        <div>
          <div className="section-title" style={{margin:'0 0 8px'}}>Stroke</div>
          <div style={{display:'flex', gap:14, alignItems:'center'}}>
            {[1.2, 1.6, 2.0].map(s => (
              <div key={s} style={{display:'flex', flexDirection:'column', alignItems:'center', gap:4}}>
                <svg width="34" height="34" viewBox="0 0 24 24" fill="none" stroke="var(--ink-400)" strokeWidth={s} strokeLinecap="round" strokeLinejoin="round">
                  <circle cx="12" cy="12" r="8" />
                  <path d="M8 12l3 3 5-6" />
                </svg>
                <span style={{fontSize:10.5, fontFamily:'var(--font-mono)', color:'var(--fg-muted)'}}>{s}</span>
              </div>
            ))}
          </div>
        </div>
        <div>
          <div className="section-title" style={{margin:'0 0 8px'}}>Sizes</div>
          <div style={{display:'flex', gap:14, alignItems:'center'}}>
            {[14,16,20,24].map(s => (
              <div key={s} style={{display:'flex', flexDirection:'column', alignItems:'center', gap:4}}>
                <Icon name="sparkle" size={s} color="var(--red-600)" />
                <span style={{fontSize:10.5, fontFamily:'var(--font-mono)', color:'var(--fg-muted)'}}>{s}</span>
              </div>
            ))}
          </div>
        </div>
        <div>
          <div className="section-title" style={{margin:'0 0 8px'}}>Color</div>
          <div style={{display:'flex', gap:14, alignItems:'center'}}>
            <Icon name="diacritic" size={22} color="var(--ink-400)" />
            <Icon name="diacritic" size={22} color="var(--red-600)" />
            <Icon name="diacritic" size={22} color="var(--jade-500)" />
            <Icon name="diacritic" size={22} color="var(--gold-500)" />
            <Icon name="diacritic" size={22} color="var(--indigo-500)" />
          </div>
        </div>
      </div>
    </div>
  );
}

// ──────────────────────────────────────────────────────────
// App icon grid
// ──────────────────────────────────────────────────────────
function AppIconGridArtboard() {
  return (
    <div style={{padding:36, background:'linear-gradient(180deg, var(--paper-100), var(--paper-150))', width:1080, minHeight:680, color:'var(--ink-500)'}}>
      <div style={{display:'flex', alignItems:'baseline', gap:14, marginBottom:6}}>
        <div style={{fontSize:11, fontWeight:600, letterSpacing:'0.14em', textTransform:'uppercase', color:'var(--fg-muted)'}}>vkey · App icon</div>
        <div style={{height:1, flex:1, background:'var(--border-1)'}}/>
      </div>
      <div style={{font:'700 44px/1.05 var(--font-display)', fontStyle:'italic', letterSpacing:'-0.02em'}}>App icon</div>
      <div style={{fontSize:14.5, color:'var(--fg-3)', maxWidth:680, marginTop:8, lineHeight:1.5}}>
        Năm hướng. Mỗi cái khai thác một biểu tượng riêng — chữ V có dấu mũ thếp vàng, key cap, ngôi sao cờ Việt, đặt dấu xếp lớp. Mặc định khuyến nghị: <strong style={{color:'var(--red-700)'}}>Lacquer</strong>.
      </div>

      {/* Big primary */}
      <div style={{display:'grid', gridTemplateColumns:'auto 1fr', gap:32, marginTop:32, alignItems:'center'}}>
        <AppIconLacquer size={220} />
        <div>
          <div style={{font:'600 24px/1.2 var(--font-sans)', color:'var(--ink-500)'}}>Lacquer</div>
          <div style={{fontSize:14, color:'var(--fg-3)', marginTop:6, maxWidth:520, lineHeight:1.55}}>
            Chữ <em style={{fontFamily:'var(--font-display)', fontStyle:'italic'}}>V</em> heavy với đường mũ thếp vàng phía trên — pháp danh: <em style={{fontFamily:'var(--font-display)', fontStyle:'italic'}}>"V có nón"</em>. Nền gradient sơn son sâu, gradient vàng thếp giữa hộp.
          </div>
          <div style={{display:'flex', gap:8, marginTop:14}}>
            <span className="badge badge--brand">Default</span>
            <span className="badge badge--success">Tonal + Sonoma</span>
          </div>
        </div>
      </div>

      {/* Variant row */}
      <div className="section-title" style={{margin:'32px 0 16px'}}>Biến thể (cycle qua Tweaks → Giao diện ứng dụng)</div>
      <div style={{display:'grid', gridTemplateColumns:'repeat(4, 1fr)', gap:20}}>
        {[
          [AppIconEggshell, 'Eggshell', 'Light mode'],
          [AppIconKeycap,   'Keycap',   '3D bóng bẩy'],
          [AppIconStack,    'Stack',    'Pure type — sắc · huyền · hỏi · ngã · nặng'],
          [AppIconStar,     'Star',     'Emoji vui tươi · VN flag inspired'],
        ].map(([C, name, desc]) => (
          <div key={name} style={{display:'flex', flexDirection:'column', alignItems:'flex-start', gap:10}}>
            <C size={150} />
            <div style={{fontSize:13, fontWeight:600, color:'var(--ink-500)'}}>{name}</div>
            <div style={{fontSize:11.5, color:'var(--fg-muted)', lineHeight:1.45}}>{desc}</div>
          </div>
        ))}
      </div>

      {/* Sizes row */}
      <div className="section-title" style={{margin:'32px 0 12px'}}>Size + dock</div>
      <div style={{display:'flex', alignItems:'flex-end', gap:18}}>
        {[128, 96, 72, 56, 40, 28, 18].map(s => (
          <div key={s} style={{display:'flex', flexDirection:'column', alignItems:'center', gap:4}}>
            <AppIconLacquer size={s} />
            <span style={{fontSize:10, fontFamily:'var(--font-mono)', color:'var(--fg-muted)'}}>{s}px</span>
          </div>
        ))}
      </div>
    </div>
  );
}

Object.assign(window, { PaletteArtboard, TypeArtboard, IconArtboard, AppIconGridArtboard });
