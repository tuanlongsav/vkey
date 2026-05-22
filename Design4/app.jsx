/* eslint-disable */
/* vkey 3D — main app */

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "theme": "dark",
  "accent": "#E04434",
  "wallpaper": "twilight",
  "glassIntensity": 1
}/*EDITMODE-END*/;

function App() {
  const [tweaks, setTweak] = useTweaks(TWEAK_DEFAULTS);

  // Apply tweaks live
  React.useEffect(() => {
    document.documentElement.dataset.theme = tweaks.theme;
    document.documentElement.style.setProperty('--vk-red-500', tweaks.accent);
  }, [tweaks.theme, tweaks.accent]);

  // Settings state — used in General + Spell tabs
  const [sG, setSG] = React.useState({
    vi: true, autostart: true, layout: 'telex', zwjf: true,
    autotypo: true, hud: true, modern: true, predict: true,
  });
  const [sS, setSS] = React.useState({
    spellMaster: true, spell: true, suggest: true, autocorrect: false,
    spaceRestore: true, policy: 'balanced',
  });

  const [activeTab, setActiveTab] = React.useState('general');
  const renderTab = () => {
    switch (activeTab) {
      case 'general': return <GeneralTab s={sG} setS={setSG}/>;
      case 'smart':   return <SmartSwitchTab/>;
      case 'macro':   return <MacroTab/>;
      case 'spell':   return <SpellTab s={sS} setS={setSS}/>;
      case 'stats':   return <StatsTab/>;
      default:        return null;
    }
  };

  const wp = tweaks.wallpaper;

  return (
    <>
      <DesignCanvas>
        {/* ============ A · OVERVIEW & APP ICON ============ */}
        <DCSection id="overview" title="App icon · 3D Liquid Glass" subtitle="Squircle glossy, gradient ball-lighting + specular gloss + caustic halo.">
          <DCArtboard id="app-icon-hero" label="01 · App icon · multi-size" width={900} height={620}>
            <div className="artboard-inner">
              <div className={`desk-bg ${wp}`}/>
              <div className="center"><AppIconShowcase/></div>
            </div>
          </DCArtboard>

          <DCArtboard id="icon-lib" label="02 · Icon library · 28 glass icons" width={780} height={620}>
            <div className="artboard-inner">
              <div className={`desk-bg ${wp}`}/>
              <div className="center" style={{ alignItems: 'flex-start', overflowY: 'auto' }}>
                <IconLibrary/>
              </div>
            </div>
          </DCArtboard>
        </DCSection>

        {/* ============ B · MENU BAR & STATUS ============ */}
        <DCSection id="menubar" title="Menu bar" subtitle="Liquid Glass dropdown that sits on top of the macOS menu bar. Refractive tint, header strip with current language, status segmented control.">
          <DCArtboard id="mb-vi" label="03 · Menu bar dropdown · VI active" width={460} height={560}>
            <div className="artboard-inner">
              <div className={`desk-bg ${wp}`}/>
              <div style={{position:'absolute',top:0,left:0,right:0}}>
                <MenuBarStatusBar/>
              </div>
              <div style={{ position: 'absolute', top: 38, left: 30 }}>
                <div className="menu-arrow"/>
                <MenuBarDropdown/>
              </div>
            </div>
          </DCArtboard>

          <DCArtboard id="hud-vi" label="04 · HUD · chuyển VI/EN" width={460} height={560}>
            <div className="artboard-inner">
              <div className={`desk-bg ${wp}`}/>
              <div className="stack-v">
                <HudToggleVi/>
                <HudToggleEn/>
                <HudLocked/>
              </div>
            </div>
          </DCArtboard>

          <DCArtboard id="hud-pred" label="05 · HUD · đoán từ tiếp theo" width={460} height={560}>
            <div className="artboard-inner">
              <div className={`desk-bg ${wp}`}/>
              <div className="stack-v">
                <HudPrediction/>
                <CaretSample/>
                <div style={{
                  font: '500 12px/1.4 var(--font-sans)',
                  color: 'rgba(255,255,255,0.55)',
                  textAlign: 'center', maxWidth: 320,
                }}>
                  HUD pill nổi cạnh caret sau commit từ. <strong style={{color:'#fff'}}>Tab</strong> để chấp nhận; phím khác bỏ qua.
                </div>
              </div>
            </div>
          </DCArtboard>
        </DCSection>

        {/* ============ C · SETTINGS WINDOW (interactive) ============ */}
        <DCSection id="settings" title="Settings window" subtitle="5 tabs. Bấm tab dưới đây để chuyển — đây là 1 artboard interactive duy nhất.">
          <DCArtboard id="settings-live" label="06 · Settings · interactive" width={620} height={820}>
            <div className="artboard-inner">
              <div className={`desk-bg ${wp}`}/>
              <div className="lg-window settings-window" style={{ position: 'absolute', top: 20, left: 20, right: 20, bottom: 20, width: 'auto', height: 'auto' }}>
                <div className="set-titlebar">
                  <div className="set-traffic">
                    <span className="r"/><span className="y"/><span className="g"/>
                  </div>
                  <div className="set-title">{({general:'Chung',smart:'Smart Switch',macro:'Macro',spell:'Chính tả',stats:'Thống kê & Sao lưu'})[activeTab]}</div>
                </div>
                <SettingsTabBar tab={activeTab} setTab={setActiveTab}/>
                {renderTab()}
              </div>
            </div>
          </DCArtboard>
        </DCSection>

        {/* ============ D · STATIC SETTINGS SNAPSHOTS ============ */}
        <DCSection id="snapshots" title="Settings snapshots" subtitle="Mỗi tab ở trạng thái typical, để xem song song.">
          <DCArtboard id="snap-general" label="07 · Chung" width={580} height={780}>
            <div className="artboard-inner">
              <div className={`desk-bg ${wp}`}/>
              <div className="lg-window settings-window" style={{ position: 'absolute', top: 16, left: 16, right: 16, bottom: 16, width: 'auto', height: 'auto' }}>
                <div className="set-titlebar"><div className="set-traffic"><span className="r"/><span className="y"/><span className="g"/></div><div className="set-title">Chung</div></div>
                <SettingsTabBar tab="general" setTab={()=>{}}/>
                <GeneralTab s={sG} setS={setSG}/>
              </div>
            </div>
          </DCArtboard>

          <DCArtboard id="snap-smart" label="08 · Smart Switch" width={580} height={780}>
            <div className="artboard-inner">
              <div className={`desk-bg ${wp}`}/>
              <div className="lg-window settings-window" style={{ position: 'absolute', top: 16, left: 16, right: 16, bottom: 16, width: 'auto', height: 'auto' }}>
                <div className="set-titlebar"><div className="set-traffic"><span className="r"/><span className="y"/><span className="g"/></div><div className="set-title">Smart Switch</div></div>
                <SettingsTabBar tab="smart" setTab={()=>{}}/>
                <SmartSwitchTab/>
              </div>
            </div>
          </DCArtboard>

          <DCArtboard id="snap-macro" label="09 · Macro" width={580} height={780}>
            <div className="artboard-inner">
              <div className={`desk-bg ${wp}`}/>
              <div className="lg-window settings-window" style={{ position: 'absolute', top: 16, left: 16, right: 16, bottom: 16, width: 'auto', height: 'auto' }}>
                <div className="set-titlebar"><div className="set-traffic"><span className="r"/><span className="y"/><span className="g"/></div><div className="set-title">Macro</div></div>
                <SettingsTabBar tab="macro" setTab={()=>{}}/>
                <MacroTab/>
              </div>
            </div>
          </DCArtboard>

          <DCArtboard id="snap-spell" label="10 · Chính tả" width={580} height={780}>
            <div className="artboard-inner">
              <div className={`desk-bg ${wp}`}/>
              <div className="lg-window settings-window" style={{ position: 'absolute', top: 16, left: 16, right: 16, bottom: 16, width: 'auto', height: 'auto' }}>
                <div className="set-titlebar"><div className="set-traffic"><span className="r"/><span className="y"/><span className="g"/></div><div className="set-title">Chính tả</div></div>
                <SettingsTabBar tab="spell" setTab={()=>{}}/>
                <SpellTab s={sS} setS={setSS}/>
              </div>
            </div>
          </DCArtboard>

          <DCArtboard id="snap-stats" label="11 · Thống kê" width={680} height={780}>
            <div className="artboard-inner">
              <div className={`desk-bg ${wp}`}/>
              <div className="lg-window settings-window" style={{ position: 'absolute', top: 16, left: 16, right: 16, bottom: 16, width: 'auto', height: 'auto' }}>
                <div className="set-titlebar"><div className="set-traffic"><span className="r"/><span className="y"/><span className="g"/></div><div className="set-title">Thống kê & Sao lưu</div></div>
                <SettingsTabBar tab="stats" setTab={()=>{}}/>
                <StatsTab/>
              </div>
            </div>
          </DCArtboard>
        </DCSection>

        {/* ============ E · ONBOARDING ============ */}
        <DCSection id="onboarding" title="Onboarding" subtitle="First-run flow — single screen with stepped checklist.">
          <DCArtboard id="onb" label="12 · Onboarding · cấp quyền" width={560} height={720}>
            <div className="artboard-inner">
              <div className={`desk-bg ${wp}`}/>
              <div className="lg-window" style={{ position: 'absolute', top: 30, left: 30, right: 30, bottom: 30, width: 'auto', height: 'auto', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <OnboardingScreen/>
              </div>
            </div>
          </DCArtboard>
        </DCSection>
      </DesignCanvas>

      {/* Tweaks panel */}
      <TweaksPanel title="vkey 3D — Tweaks">
        <TweakSection label="Wallpaper">
          <TweakRadio
            label="Mood"
            value={tweaks.wallpaper}
            options={[
              { value: 'twilight', label: 'Twilight' },
              { value: 'warm',     label: 'Warm' },
              { value: 'cool',     label: 'Cool' },
              { value: 'amber',    label: 'Amber' },
            ]}
            onChange={v => setTweak('wallpaper', v)}
          />
        </TweakSection>
        <TweakSection label="Brand accent">
          <TweakColor
            label="Color"
            value={tweaks.accent}
            options={[ '#E04434', '#FF6363', '#D26F5C', '#2D89E5', '#8B5CF6', '#2BB673' ]}
            onChange={v => setTweak('accent', v)}
          />
        </TweakSection>
        <TweakSection label="Appearance">
          <TweakRadio
            label="Mode"
            value={tweaks.theme}
            options={[
              { value: 'dark',  label: 'Dark' },
              { value: 'light', label: 'Light' },
            ]}
            onChange={v => setTweak('theme', v)}
          />
        </TweakSection>
      </TweaksPanel>
    </>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App/>);
