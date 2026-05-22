// vkey · huds.jsx — overlay surfaces

function ToggleHUD({ mode = 'vn' }) {
  return (
    <div style={{
      display: 'inline-flex', alignItems: 'center', gap: 14,
      padding: '18px 28px',
      background: 'rgba(20, 16, 12, 0.78)',
      backdropFilter: 'blur(40px) saturate(180%)',
      WebkitBackdropFilter: 'blur(40px) saturate(180%)',
      borderRadius: 22,
      boxShadow: '0 24px 60px -16px rgba(0,0,0,0.55), inset 0 0 0 1px rgba(255,255,255,0.08)',
      color: '#fff',
      fontFamily: 'var(--font-sans)',
    }}>
      <div style={{
        width: 40, height: 40, borderRadius: 10, overflow: 'hidden',
        boxShadow: '0 4px 14px rgba(0,0,0,0.4)',
      }}>
        <svg viewBox="0 0 40 40" width="40" height="40">
          {mode === 'vn' ? (
            <>
              <rect width="40" height="40" fill="#B5302A" />
              <path d="M20 11.5l2.4 5.3 5.8.5-4.4 3.8 1.3 5.7L20 23.5l-5.1 3.3 1.3-5.7-4.4-3.8 5.8-.5z" fill="#F5D785" />
            </>
          ) : (
            <>
              <rect width="40" height="40" fill="#fff" />
              <g>
                {[0,1,2,3,4,5,6].map(i =>
                  <rect key={i} y={5.7*i} width="40" height="3" fill={i%2 ? "transparent" : "#B22234"} />
                )}
                <rect width="20" height="20" fill="#3C3B6E" />
              </g>
            </>
          )}
        </svg>
      </div>
      <div>
        <div style={{
          fontFamily: 'var(--font-display)', fontStyle: 'italic',
          fontWeight: 700, fontSize: 22, letterSpacing: '-0.01em', lineHeight: 1,
        }}>{mode === 'vn' ? 'Tiếng Việt' : 'English'}</div>
        <div style={{fontSize: 11.5, opacity: 0.6, marginTop: 4, letterSpacing: '0.04em'}}>
          ⌃⇧ · {mode === 'vn' ? 'Telex' : 'EN passthrough'}
        </div>
      </div>
    </div>
  );
}

function PredictionHUD({ word = "Việt Nam", typed = "Vie" }) {
  return (
    <div style={{
      display: 'inline-flex', alignItems: 'center', gap: 10,
      padding: '8px 14px',
      background: 'rgba(20, 16, 12, 0.82)',
      backdropFilter: 'blur(28px) saturate(180%)',
      WebkitBackdropFilter: 'blur(28px) saturate(180%)',
      borderRadius: 10,
      boxShadow: '0 12px 32px -8px rgba(0,0,0,0.5), inset 0 0 0 1px rgba(255,255,255,0.08)',
      color: '#fff',
      fontFamily: 'var(--font-mono)',
    }}>
      <span style={{opacity:0.55, fontSize:13}}>{typed}</span>
      <span style={{fontSize:13, color:'#FBE9A0', fontWeight:600}}>{word.slice(typed.length)}</span>
      <span style={{
        marginLeft:6, padding:'2px 7px',
        background: 'rgba(255,255,255,0.12)',
        borderRadius:4, fontSize:10, letterSpacing:'0.06em',
        fontFamily:'var(--font-sans)', fontWeight:600,
      }}>TAB</span>
    </div>
  );
}

function DictHUD() {
  // Inline dictionary lookup - new feature mockup
  return (
    <div style={{
      width: 340,
      background: 'rgba(252,248,236,0.96)',
      backdropFilter: 'blur(40px) saturate(180%)',
      WebkitBackdropFilter: 'blur(40px) saturate(180%)',
      borderRadius: 14,
      padding: 14,
      boxShadow: '0 24px 60px -16px rgba(0,0,0,0.32), 0 0 0 0.5px rgba(0,0,0,0.16), inset 0 0 0 1px rgba(255,255,255,0.5)',
      fontFamily: 'var(--font-sans)',
    }}>
      <div style={{display:'flex', alignItems:'center', gap:8}}>
        <Icon name="dictionary" size={16} color="var(--red-600)" />
        <span style={{fontSize:11, fontWeight:600, color:'var(--fg-muted)', letterSpacing:'0.10em', textTransform:'uppercase'}}>Tra cứu</span>
        <div style={{flex:1}}/>
        <span className="kbd" style={{fontSize:10}}>⌃⌥D</span>
      </div>
      <div style={{
        marginTop:8,
        display:'flex', alignItems:'baseline', gap:10,
      }}>
        <span style={{font:'700 28px/1 var(--font-display)', fontStyle:'italic', color:'var(--ink-500)'}}>thuỷ</span>
        <span style={{fontFamily:'var(--font-mono)', fontSize:11.5, color:'var(--fg-muted)'}}>/tʰwi³/</span>
        <span className="badge badge--success" style={{marginLeft:'auto'}}>VN baseline</span>
      </div>
      <div style={{fontSize:12.5, color:'var(--fg-2)', marginTop:6, lineHeight:1.5}}>
        Trong lexicon v9 · 8,960 syllables · curated. Phụ âm đầu <code style={{fontFamily:'var(--font-mono)',color:'var(--red-600)'}}>th</code> + nguyên âm <code style={{fontFamily:'var(--font-mono)',color:'var(--red-600)'}}>uy</code> + dấu hỏi. Kiểu mới.
      </div>
      <div style={{
        display:'flex', flexWrap:'wrap', gap:4, marginTop:10,
        paddingTop:10, borderTop:'1px solid var(--border-1)',
      }}>
        {['thủy','thuỷ','water','aqua'].map((v,i) => (
          <span key={v} className={"badge " + (i === 0 ? "badge--brand" : "")}>{v}</span>
        ))}
      </div>
    </div>
  );
}

function HUDArtboard() {
  return (
    <div style={{
      width: 1080, height: 480,
      borderRadius: 16, overflow: 'hidden',
      background: 'linear-gradient(135deg, #4A332A 0%, #2A1812 60%, #1A0E0A 100%)',
      position: 'relative',
      padding: 32,
      display: 'flex', flexDirection: 'column', gap: 24,
    }}>
      {/* faux wallpaper texture */}
      <div style={{
        position:'absolute', inset:0,
        background:'radial-gradient(circle at 30% 30%, rgba(196,154,74,0.15), transparent 50%), radial-gradient(circle at 80% 70%, rgba(181,48,42,0.18), transparent 50%)',
      }}/>
      {/* labels row */}
      <div style={{position:'relative', display:'grid', gridTemplateColumns:'1fr 1fr 1fr', gap:24}}>
        <div style={{color:'rgba(255,255,255,0.45)', fontFamily:'var(--font-display)', fontStyle:'italic', fontSize:15}}>Toggle HUD</div>
        <div style={{color:'rgba(255,255,255,0.45)', fontFamily:'var(--font-display)', fontStyle:'italic', fontSize:15}}>Prediction HUD</div>
        <div style={{color:'rgba(255,255,255,0.45)', fontFamily:'var(--font-display)', fontStyle:'italic', fontSize:15}}>Dictionary HUD <span style={{color:'var(--gold-300)', fontStyle:'normal', fontSize:11, marginLeft:6}}>● NEW</span></div>
      </div>
      <div style={{position:'relative', display:'grid', gridTemplateColumns:'1fr 1fr 1fr', gap:24, alignItems:'center'}}>
        <div style={{display:'flex', flexDirection:'column', gap:12, alignItems:'flex-start'}}>
          <ToggleHUD mode="vn" />
          <ToggleHUD mode="en" />
        </div>
        <div style={{display:'flex', flexDirection:'column', gap:12, alignItems:'flex-start'}}>
          <PredictionHUD word="Việt Nam" typed="Vi" />
          <PredictionHUD word="không thể" typed="kho" />
          <PredictionHUD word="cảm ơn anh" typed="cảm " />
        </div>
        <div>
          <DictHUD />
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { ToggleHUD, PredictionHUD, DictHUD, HUDArtboard });
