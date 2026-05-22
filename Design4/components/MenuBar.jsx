/* eslint-disable */
/* Menu bar dropdown — vkey 3D Liquid Glass */

function MenuBarStatusBar() {
  return (
    <div className="mbs">
      <span className="apple">􀣺</span>
      <span className="menu-item">Finder</span>
      <span className="menu-item bold">File</span>
      <span className="menu-item">Edit</span>
      <span className="menu-item">View</span>
      <span className="menu-item">Go</span>
      <span className="menu-item">Window</span>
      <span className="menu-item">Help</span>
      <div className="mbs-spacer"></div>
      <div className="mbs-vkey active">
        <GlassTile color="red" size="sm" style={{ width: 18, height: 18, borderRadius: 5 }}>
          <svg viewBox="0 0 24 24" width="12" height="12">
            <text x="12" y="17" textAnchor="middle" fill="white" fontWeight="800" fontSize="14" fontFamily="-apple-system, sans-serif">V</text>
          </svg>
        </GlassTile>
      </div>
      <Icon name="globe" size={16} color="rgba(255,255,255,0.85)" />
      <span className="mbs-clock">22:48</span>
    </div>
  );
}

function MenuItem({ icon, color = 'gray', label, shortcut, check, danger, sub, onHover }) {
  return (
    <div className={`mi ${danger ? 'mi--danger' : ''}`}>
      {icon && (
        <GlassTile color={color} size="sm" style={{ width: 24, height: 24, borderRadius: 7 }}>
          <Icon name={icon} size={14} />
        </GlassTile>
      )}
      <div className="mi-body">
        <div className="mi-label">{label}</div>
        {sub && <div className="mi-sub">{sub}</div>}
      </div>
      {check && <span className="mi-check">✓</span>}
      {shortcut && <span className="mi-shortcut">{shortcut}</span>}
      {onHover && <span className="mi-caret">›</span>}
    </div>
  );
}

function MenuBarDropdown() {
  return (
    <div className="mb-dropdown lg-window">
      {/* Header strip with current language */}
      <div className="mb-header">
        <GlassTile color="red" size="sm" style={{ width: 28, height: 28, borderRadius: 8 }}>
          <Icon name="flagVn" size={18} />
        </GlassTile>
        <div className="mb-header-text">
          <div className="mb-header-title">Tiếng Việt</div>
          <div className="mb-header-sub">Telex · Smart Switch đang bật</div>
        </div>
        <div className="mb-toggle-pill">
          <span className="active">VN</span>
          <span>EN</span>
        </div>
      </div>

      <div className="mb-section">
        <MenuItem icon="switch" color="blue" label="Chuyển đổi ngôn ngữ" shortcut="⌃⇧" />
      </div>

      <div className="mb-sep" />

      <div className="mb-section">
        <div className="mb-section-title">Kiểu gõ</div>
        <MenuItem icon="keyboard" color="gray" label="Telex" check />
        <MenuItem icon="keyboard" color="gray" label="VNI" />
      </div>

      <div className="mb-sep" />

      <div className="mb-section">
        <MenuItem icon="gear" color="gray" label="Cài đặt…" shortcut="⌘," />
        <MenuItem icon="switch" color="blue" label="Smart Switch" check />
        <MenuItem icon="check" color="green" label="Sửa lỗi chính tả" check />
        <MenuItem icon="wand" color="purple" label="Macro" check />
        <MenuItem icon="paintbrush" color="gold" label="Giao diện ứng dụng" onHover />
      </div>

      <div className="mb-sep" />

      <div className="mb-section">
        <MenuItem icon="info" color="blue" label="Thông tin dự án" />
        <MenuItem icon="refresh" color="green" label="Kiểm tra cập nhật" />
        <MenuItem icon="power" color="red" label="Thoát" danger shortcut="⌘Q" />
      </div>
    </div>
  );
}

window.MenuBarStatusBar = MenuBarStatusBar;
window.MenuBarDropdown = MenuBarDropdown;
