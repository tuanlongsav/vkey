// vkey · app-icons.jsx — new app icon system
// 5 variants exploring different metaphors. All built as inline SVG,
// designed for macOS Big-Sur-style square-with-rounded-corners (sq).

function AppIconShell({ size = 240, children, bg, shadow = true }) {
  const radius = size * 0.225; // macOS app icon radius
  return (
    <div style={{
      width: size, height: size,
      borderRadius: radius, position: 'relative',
      background: bg,
      boxShadow: shadow
        ? `0 ${size*0.06}px ${size*0.16}px -${size*0.04}px rgba(0,0,0,0.36), inset 0 1px 0 rgba(255,255,255,0.2)`
        : 'none',
      overflow: 'hidden',
    }}>
      <svg width={size} height={size} viewBox="0 0 240 240" style={{display:'block'}}>
        {children}
      </svg>
      {/* macOS top highlight */}
      {shadow && <div style={{
        position: 'absolute', inset: 0, borderRadius: radius,
        boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.22), inset 0 -1px 0 rgba(0,0,0,0.12)',
        pointerEvents: 'none',
      }} />}
    </div>
  );
}

// 1. Lacquer red with gilded V — primary
function AppIconLacquer({ size = 240 }) {
  return (
    <AppIconShell size={size} bg="linear-gradient(160deg, #C53A2B 0%, #951F19 70%, #6C140F 100%)">
      <defs>
        <linearGradient id="goldGrad" x1="0" x2="0" y1="0" y2="1">
          <stop offset="0" stopColor="#F5D785" />
          <stop offset="0.5" stopColor="#D4A24C" />
          <stop offset="1" stopColor="#9C722A" />
        </linearGradient>
        <radialGradient id="vGlow" cx="0.5" cy="0.4" r="0.6">
          <stop offset="0" stopColor="rgba(255,222,140,0.45)" />
          <stop offset="1" stopColor="rgba(255,222,140,0)" />
        </radialGradient>
      </defs>
      {/* subtle radial */}
      <rect width="240" height="240" fill="url(#vGlow)" />
      {/* Diacritic — circumflex above */}
      <path d="M86 56 L120 38 L154 56" stroke="url(#goldGrad)" strokeWidth="10" strokeLinecap="round" strokeLinejoin="round" fill="none" />
      {/* The V — heavy weight, custom geometry */}
      <path d="M58 88 L120 198 L182 88"
        stroke="url(#goldGrad)" strokeWidth="22" strokeLinecap="round" strokeLinejoin="round" fill="none" />
      {/* Inner highlight on V */}
      <path d="M62 92 L120 194"
        stroke="rgba(255,236,180,0.55)" strokeWidth="6" strokeLinecap="round" fill="none" />
    </AppIconShell>
  );
}

// 2. Eggshell with red V (light variant)
function AppIconEggshell({ size = 240 }) {
  return (
    <AppIconShell size={size} bg="linear-gradient(160deg, #FAF5E6 0%, #ECDFC1 100%)">
      <path d="M86 56 L120 38 L154 56" stroke="#B5302A" strokeWidth="10" strokeLinecap="round" strokeLinejoin="round" fill="none" />
      <path d="M58 88 L120 198 L182 88"
        stroke="#B5302A" strokeWidth="22" strokeLinecap="round" strokeLinejoin="round" fill="none" />
      <path d="M58 88 L120 198"
        stroke="#962219" strokeWidth="22" strokeLinecap="round" strokeLinejoin="round" fill="none" opacity="0.35" />
    </AppIconShell>
  );
}

// 3. Keycap (3D bóng bẩy theme)
function AppIconKeycap({ size = 240 }) {
  return (
    <AppIconShell size={size} bg="linear-gradient(160deg, #2A1F18 0%, #161210 100%)">
      <defs>
        <linearGradient id="keyFace" x1="0" x2="0" y1="0" y2="1">
          <stop offset="0" stopColor="#FBEBE7" />
          <stop offset="1" stopColor="#D4B59B" />
        </linearGradient>
        <linearGradient id="keySide" x1="0" x2="0" y1="0" y2="1">
          <stop offset="0" stopColor="#B5302A" />
          <stop offset="1" stopColor="#7E1C16" />
        </linearGradient>
      </defs>
      {/* keycap shape */}
      <rect x="36" y="46" width="168" height="148" rx="22" fill="url(#keySide)" />
      <rect x="48" y="56" width="144" height="120" rx="16" fill="url(#keyFace)" />
      <rect x="52" y="60" width="136" height="6" rx="3" fill="rgba(255,255,255,0.6)" />
      {/* Vietnamese letter "â" on the cap */}
      <text x="120" y="146" textAnchor="middle"
        fontFamily="Fraunces, serif" fontSize="92" fontWeight="700" fill="#B5302A">â</text>
    </AppIconShell>
  );
}

// 4. Diacritic stack — pure-type variant
function AppIconStack({ size = 240 }) {
  return (
    <AppIconShell size={size} bg="linear-gradient(160deg, #F4EFE3 0%, #E4D8B5 100%)">
      {/* 4 diacritics descending */}
      <g stroke="#B5302A" strokeWidth="6" strokeLinecap="round" strokeLinejoin="round" fill="none">
        {/* sắc */}
        <path d="M88 56 L132 38" />
        {/* huyền */}
        <path d="M88 88 L132 106" />
        {/* hỏi */}
        <path d="M104 132 q12 -10 22 0" />
        {/* nặng */}
      </g>
      <circle cx="115" cy="172" r="6" fill="#B5302A" />
      {/* ngã */}
      <path d="M88 200 q12 -6 22 0 q12 6 22 0" stroke="#B5302A" strokeWidth="6" strokeLinecap="round" fill="none" />
    </AppIconShell>
  );
}

// 5. Star (emoji vui tươi variant) — playful
function AppIconStar({ size = 240 }) {
  return (
    <AppIconShell size={size} bg="linear-gradient(160deg, #DD442F 0%, #B5302A 70%, #7E1C16 100%)">
      <defs>
        <radialGradient id="starShine" cx="0.5" cy="0.4" r="0.6">
          <stop offset="0" stopColor="#FFEFB8" />
          <stop offset="0.6" stopColor="#E5C461" />
          <stop offset="1" stopColor="#A07C32" />
        </radialGradient>
      </defs>
      {/* big VN-flag star */}
      <path d="M120 36
        L142 102 L210 102
        L156 142 L176 208
        L120 168 L64 208
        L84 142 L30 102 L98 102 Z"
        fill="url(#starShine)" stroke="#7E1C16" strokeWidth="2.5" strokeLinejoin="round" />
      <path d="M120 36 L132 80" stroke="rgba(255,255,255,0.5)" strokeWidth="3" strokeLinecap="round" />
    </AppIconShell>
  );
}

// Menu bar variant — small, monochrome silhouette
function MenuBarIcon({ size = 22, color = "#fff" }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" style={{display:'block'}}>
      <path d="M5 6 L12 19 L19 6" stroke={color} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" fill="none" />
      <path d="M9 4 L12 2.5 L15 4" stroke={color} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" fill="none" />
    </svg>
  );
}

Object.assign(window, {
  AppIconShell, AppIconLacquer, AppIconEggshell, AppIconKeycap, AppIconStack, AppIconStar,
  MenuBarIcon,
});
