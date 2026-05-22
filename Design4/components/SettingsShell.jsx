/* eslint-disable */
/* Settings — vkey 3D Liquid Glass */

function TabIcon({ name, color, active }) {
  return (
    <div className={`tabicon ${active ? 'active' : ''}`}>
      <GlassTile color={active ? color : 'ink'} size="md" style={{ width: 38, height: 38, borderRadius: 11 }}>
        <Icon name={name} size={20} />
      </GlassTile>
    </div>
  );
}

function SettingsTabBar({ tab, setTab }) {
  const tabs = [
    { id: 'general',  label: 'Chung',         icon: 'gear',     color: 'gray' },
    { id: 'smart',    label: 'Smart Switch',  icon: 'switch',   color: 'blue' },
    { id: 'macro',    label: 'Macro',         icon: 'wand',     color: 'purple' },
    { id: 'spell',    label: 'Chính tả',      icon: 'check',    color: 'green' },
    { id: 'stats',    label: 'Thống kê',      icon: 'chart',    color: 'gold' },
  ];
  return (
    <div className="set-tabbar">
      {tabs.map(t => (
        <button key={t.id} className={`set-tab ${tab === t.id ? 'active' : ''}`} onClick={() => setTab(t.id)}>
          <TabIcon name={t.icon} color={t.color} active={tab === t.id} />
          <span>{t.label}</span>
        </button>
      ))}
    </div>
  );
}

function Row({ icon, color = 'gray', label, sub, control, divider = true }) {
  return (
    <div className={`row ${divider ? '' : 'row--no-div'}`}>
      {icon && (
        <GlassTile color={color} size="md" style={{ width: 32, height: 32, borderRadius: 9 }}>
          <Icon name={icon} size={17} />
        </GlassTile>
      )}
      <div className="row-text">
        <div className="row-label">{label}</div>
        {sub && <div className="row-sub">{sub}</div>}
      </div>
      <div className="row-ctrl">{control}</div>
    </div>
  );
}

function Toggle({ on, onClick }) {
  return <button className={`toggle ${on ? 'on' : ''}`} onClick={onClick} aria-label="toggle"></button>;
}

function Segmented({ options, value, onChange }) {
  return (
    <div className="segmented">
      {options.map(o => (
        <span
          key={o.value}
          className={`seg ${value === o.value ? 'active' : ''}`}
          onClick={() => onChange(o.value)}
        >{o.label}</span>
      ))}
    </div>
  );
}

function SettingsHeader() {
  return (
    <div className="set-header">
      <div className="set-header-icon">
        <img src="assets/app-icon.svg" alt="Vkey" width="96" height="96" />
        <div className="set-header-halo" />
      </div>
      <div>
        <h1 className="set-header-title">vkey</h1>
        <div className="set-header-tag">Bộ gõ tiếng Việt cho macOS · v2.2.0</div>
      </div>
    </div>
  );
}

window.SettingsTabBar = SettingsTabBar;
window.SettingsHeader = SettingsHeader;
window.Row = Row;
window.Toggle = Toggle;
window.Segmented = Segmented;
