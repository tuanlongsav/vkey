// vkey · menubar.jsx — menu bar mockup
// Shows: macOS menu bar strip with vkey icon active, plus an opened dropdown
// pinned below it. Uses the new design tokens.

function MenuBarStrip() {
  const items = ["Finder", "File", "Edit", "View", "Go", "Window", "Help"];
  return (
    <div style={{
      height: 28, background: 'rgba(20,16,12,0.78)',
      backdropFilter: 'blur(40px) saturate(160%)',
      WebkitBackdropFilter: 'blur(40px) saturate(160%)',
      display: 'flex', alignItems: 'center',
      padding: '0 12px', gap: 16, color: '#fff',
      fontFamily: '-apple-system, "SF Pro Text", sans-serif', fontSize: 13,
      borderBottom: '0.5px solid rgba(255,255,255,0.06)',
    }}>
      {/* Apple logo */}
      <svg width="14" height="14" viewBox="0 0 24 24" fill="#fff" style={{opacity:0.95}}>
        <path d="M17.05 12.04c-.02-2.4 1.96-3.55 2.05-3.61-1.12-1.64-2.86-1.87-3.48-1.9-1.48-.15-2.89.87-3.64.87-.76 0-1.92-.85-3.16-.83-1.62.02-3.12.94-3.95 2.4-1.69 2.94-.43 7.27 1.21 9.65.81 1.16 1.77 2.46 3.02 2.41 1.21-.05 1.67-.78 3.14-.78s1.88.78 3.15.76c1.3-.02 2.13-1.18 2.93-2.35.92-1.35 1.3-2.66 1.32-2.72-.03-.01-2.53-.97-2.55-3.85zM14.4 4.55c.67-.81 1.12-1.94.99-3.06-.96.04-2.13.65-2.82 1.46-.62.72-1.16 1.86-1.02 2.96 1.07.08 2.17-.55 2.85-1.36z"/>
      </svg>
      <span style={{fontWeight:600}}>vkey</span>
      {items.map(i => (
        <span key={i} style={{opacity:0.85}}>{i}</span>
      ))}
      <div style={{flex:1}} />
      {/* status icons */}
      <span style={{opacity:0.85, fontSize:12}}>100%</span>
      <Icon name="globe" size={14} />
      {/* vkey icon — active */}
      <div style={{
        background: 'var(--red-500)',
        padding: '2px 6px',
        borderRadius: 4,
        display: 'flex', alignItems: 'center', gap: 4,
      }}>
        <MenuBarIcon size={14} color="#FBE9A0" />
      </div>
      <span style={{opacity:0.85}}>Th 5 22 Th5</span>
      <span style={{opacity:0.85}}>10:24</span>
    </div>
  );
}

function MenuRow({ icon, label, shortcut, check, danger, brand, sub, onHover }) {
  return (
    <div className={"menu-row" + (onHover ? " is-hover" : "")} style={{
      display: 'flex', alignItems: 'center', gap: 10,
      padding: '5px 10px',
      borderRadius: 5,
      cursor: 'default',
      color: danger ? 'var(--danger)' : 'var(--fg-1)',
      background: onHover ? 'var(--red-500)' : 'transparent',
      ...(onHover && { color: '#fff' }),
    }}>
      <div style={{width: 16, display:'flex', justifyContent:'center', opacity: check ? 1 : 0}}>
        {check && <Icon name="check" size={13} color={onHover ? '#fff' : 'var(--red-600)'} />}
      </div>
      {icon && <div style={{width:16, display:'flex', justifyContent:'center'}}>{icon}</div>}
      <span style={{flex:1, fontSize:13, fontWeight: brand ? 600 : 400}}>{label}</span>
      {sub && <Icon name="chevron-right" size={11} color={onHover ? '#fff' : 'var(--fg-muted)'} />}
      {shortcut && (
        <span style={{
          fontSize: 12, fontFamily: 'var(--font-mono)',
          color: onHover ? 'rgba(255,255,255,0.85)' : 'var(--fg-muted)',
          letterSpacing: '0.04em',
        }}>{shortcut}</span>
      )}
    </div>
  );
}

function MenuDivider() {
  return <div style={{height:1, background:'var(--border-1)', margin:'4px 8px'}} />;
}

function MenuBarDropdown() {
  return (
    <div style={{
      width: 280,
      background: 'rgba(252,248,236,0.92)',
      backdropFilter: 'blur(40px) saturate(180%)',
      WebkitBackdropFilter: 'blur(40px) saturate(180%)',
      borderRadius: 12,
      padding: 6,
      boxShadow: '0 24px 60px -16px rgba(0,0,0,0.35), 0 0 0 0.5px rgba(0,0,0,0.18), inset 0 0 0 1px rgba(255,255,255,0.6)',
      fontFamily: 'var(--font-sans)',
    }}>
      {/* Header */}
      <div style={{
        display:'flex', alignItems:'center', gap:10,
        padding:'8px 10px 10px',
      }}>
        <AppIconLacquer size={36} />
        <div style={{flex:1, minWidth:0}}>
          <div style={{fontSize:13, fontWeight:600, color:'var(--ink-500)'}}>vkey</div>
          <div style={{fontSize:11.5, color:'var(--fg-muted)', display:'flex', gap:6, alignItems:'center'}}>
            <span>v2.2.0 “Sơn Mài”</span>
            <span style={{width:3, height:3, borderRadius:'50%', background:'var(--paper-400)'}} />
            <span style={{color:'var(--jade-500)'}}>● Tiếng Việt</span>
          </div>
        </div>
      </div>
      <MenuDivider />

      <MenuRow icon={<Icon name="flag-vn" size={14} />} label="Chuyển đổi ngôn ngữ" shortcut="⌃⇧" onHover />
      <MenuDivider />

      <MenuRow check label="Bật / Tắt gõ TV" />
      <MenuRow check label="Kiểu Telex" />
      <MenuRow label="Kiểu VNI" />
      <MenuDivider />

      <MenuRow check icon={<Icon name="switch" size={14} color="var(--fg-muted)" />} label="Smart Switch" />
      <MenuRow check icon={<Icon name="spellcheck" size={14} color="var(--fg-muted)" />} label="Sửa lỗi chính tả" />
      <MenuRow check icon={<Icon name="macro" size={14} color="var(--fg-muted)" />} label="Macro" />
      <MenuDivider />

      <MenuRow icon={<Icon name="sparkle" size={14} color="var(--gold-500)" />} label="Giao diện ứng dụng" sub />
      <MenuRow icon={<Icon name="gear" size={14} color="var(--fg-muted)" />} label="Cài đặt..." shortcut="⌘," />
      <MenuDivider />

      <MenuRow icon={<Icon name="donate" size={14} color="var(--red-500)" />} label="Ủng hộ tác giả" />
      <MenuRow icon={<Icon name="external" size={14} color="var(--fg-muted)" />} label="Thông tin dự án" />
      <MenuRow icon={<Icon name="refresh" size={14} color="var(--fg-muted)" />} label="Kiểm tra cập nhật..." />
      <MenuDivider />
      <MenuRow label="Thoát vkey" shortcut="⌘Q" danger />
    </div>
  );
}

function MenubarArtboard() {
  return (
    <div style={{
      width: 720, height: 640,
      borderRadius: 16, overflow: 'hidden',
      background: 'linear-gradient(160deg, #6B5640 0%, #3D2C1D 100%)',
      position: 'relative',
      boxShadow: 'inset 0 0 0 1px rgba(255,255,255,0.04)',
    }}>
      <MenuBarStrip />
      {/* desktop hint — tied to vkey icon */}
      <div style={{
        position: 'absolute',
        top: 36, right: 92,
        width: 8, height: 8,
        borderTop: '8px solid rgba(252,248,236,0.92)',
        borderLeft: '8px solid transparent',
        borderRight: '8px solid transparent',
        transform: 'translateX(-50%)',
        filter: 'drop-shadow(0 -2px 4px rgba(0,0,0,0.18))',
      }} />
      <div style={{
        position: 'absolute',
        top: 38, right: 12,
      }}>
        <MenuBarDropdown />
      </div>
      {/* faint type behind */}
      <div style={{
        position: 'absolute', bottom: 24, left: 24,
        fontFamily: 'var(--font-display)',
        fontSize: 22, color: 'rgba(255,255,255,0.4)',
        fontStyle: 'italic',
      }}>Menu bar · ⌃⇧ toggle</div>
    </div>
  );
}

Object.assign(window, { MenubarArtboard, MenuBarStrip, MenuBarDropdown });
