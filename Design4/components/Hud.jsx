/* eslint-disable */
/* HUD overlays — vkey 3D Liquid Glass */

function HudToggleVi() {
  return (
    <div className="hud hud--lg">
      <div className="hud-flag">
        <Icon name="flagVn" size={36}/>
        <div className="hud-flag-gloss"/>
      </div>
      <div className="hud-text">
        <div className="hud-title">Tiếng Việt</div>
        <div className="hud-sub">Telex · Kiểu mới</div>
      </div>
      <div className="hud-keys">
        <span className="keycap">⌃</span>
        <span className="keycap">⇧</span>
      </div>
    </div>
  );
}

function HudToggleEn() {
  return (
    <div className="hud hud--lg">
      <div className="hud-flag">
        <Icon name="flagUs" size={36}/>
        <div className="hud-flag-gloss"/>
      </div>
      <div className="hud-text">
        <div className="hud-title">English</div>
        <div className="hud-sub">Smart Switch · Auto</div>
      </div>
      <div className="hud-keys">
        <span className="keycap">⌃</span>
        <span className="keycap">⇧</span>
      </div>
    </div>
  );
}

function HudPrediction() {
  return (
    <div className="hud hud--predict">
      <span className="pred-mono">tiếng</span>
      <span className="pred-arrow">→</span>
      <span className="pred-suggest">Việt</span>
      <span className="keycap keycap--sm">Tab</span>
    </div>
  );
}

function HudLocked() {
  return (
    <div className="hud hud--lg hud--locked">
      <div className="hud-flag">
        <GlassTile color="ink" size="md" style={{ width: 44, height: 44, borderRadius: 12 }}>
          <Icon name="lock" size={22}/>
        </GlassTile>
      </div>
      <div className="hud-text">
        <div className="hud-title">Ô bảo mật</div>
        <div className="hud-sub">vkey tự bypass · Secure Input</div>
      </div>
    </div>
  );
}

function CaretSample() {
  return (
    <div className="caret-sample">
      <div className="caret-line">
        Một bộ gõ tiếng <span className="caret-word">Việt|</span>
      </div>
      <div className="caret-hud-anchor">
        <HudPrediction/>
      </div>
    </div>
  );
}

window.HudToggleVi = HudToggleVi;
window.HudToggleEn = HudToggleEn;
window.HudPrediction = HudPrediction;
window.HudLocked = HudLocked;
window.CaretSample = CaretSample;
