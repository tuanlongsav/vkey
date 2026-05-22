// vkey · icons.jsx
// Custom-drawn icon set, 24×24 viewBox, 1.6px stroke, rounded caps & joins.
// Geometric, light, with selective Vietnamese-typography references.

const ICONS = {
  // ─── Mode & status ───────────────────────────────────────
  "flag-vn": (
    <svg viewBox="0 0 24 24" fill="none">
      <rect x="3" y="6" width="18" height="12" rx="2" fill="var(--red-500)" />
      <path d="M12 9.2l.93 2.05 2.27.18-1.72 1.5.52 2.22L12 13.85l-1.99 1.3.52-2.22-1.72-1.5 2.27-.18.92-2.05z" fill="var(--gold-300)" />
    </svg>
  ),
  "flag-en": (
    <svg viewBox="0 0 24 24" fill="none">
      <rect x="3" y="6" width="18" height="12" rx="2" fill="#fff" stroke="currentColor" strokeOpacity="0.18" />
      <path d="M3 8h18M3 10h18M3 12h18M3 14h18M3 16h18" stroke="#B22234" strokeWidth="1.2" />
      <rect x="3" y="6" width="8" height="6" rx="1.5" fill="#3C3B6E" />
      <g fill="#fff">
        <circle cx="5" cy="8" r="0.5" /><circle cx="7" cy="8" r="0.5" /><circle cx="9" cy="8" r="0.5" />
        <circle cx="5.5" cy="9.5" r="0.5" /><circle cx="7.5" cy="9.5" r="0.5" /><circle cx="9.5" cy="9.5" r="0.5" />
        <circle cx="5" cy="11" r="0.5" /><circle cx="7" cy="11" r="0.5" /><circle cx="9" cy="11" r="0.5" />
      </g>
      <rect x="3" y="6" width="18" height="12" rx="2" fill="none" stroke="currentColor" strokeOpacity="0.12" />
    </svg>
  ),
  "lock": (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <rect x="5" y="11" width="14" height="9" rx="2.5" />
      <path d="M8 11V8a4 4 0 0 1 8 0v3" />
      <circle cx="12" cy="15.5" r="1.1" fill="currentColor" />
    </svg>
  ),
  "lock-open": (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <rect x="5" y="11" width="14" height="9" rx="2.5" />
      <path d="M8 11V8a4 4 0 0 1 7.5-1.9" />
    </svg>
  ),
  "shield": (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <path d="M12 3l8 3v6c0 4.5-3.4 7.8-8 9-4.6-1.2-8-4.5-8-9V6l8-3z" />
      <path d="M9.2 12.2l2 2 3.6-4" />
    </svg>
  ),

  // ─── Mode / IME concepts ────────────────────────────────
  "telex": (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <text x="4.5" y="16" fontFamily="Be Vietnam Pro, sans-serif" fontSize="11.5" fontWeight="700" fill="currentColor" stroke="none">tx</text>
      <path d="M16 6l2.5 1.5L21 6" />
      <circle cx="18.5" cy="11" r="1.4" fill="currentColor" />
    </svg>
  ),
  "vni": (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <text x="3.5" y="16" fontFamily="JetBrains Mono, monospace" fontSize="10.5" fontWeight="700" fill="currentColor" stroke="none">12</text>
      <path d="M16 8h4M18 6v4" />
      <path d="M14 18h6" />
    </svg>
  ),
  "diacritic": (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <path d="M6 7l4-2 4 2" />
      <text x="6" y="20" fontFamily="Fraunces, serif" fontSize="14" fontWeight="700" fill="currentColor" stroke="none">â</text>
      <circle cx="18" cy="6" r="1" fill="currentColor" />
    </svg>
  ),
  "magic-wand": (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <path d="M5 19L15.5 8.5" />
      <path d="M14 7L17 10" />
      <path d="M18 4v3M16.5 5.5h3M19 13v2M18 14h2M9 5v2M8 6h2" />
    </svg>
  ),
  "keyboard": (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <rect x="3" y="7" width="18" height="11" rx="2.2" />
      <path d="M6 11h.01M9 11h.01M12 11h.01M15 11h.01M18 11h.01" strokeWidth="2.2" />
      <path d="M8 15h8" />
    </svg>
  ),

  // ─── Settings tab icons ──────────────────────────────────
  "gear": (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="12" r="3" />
      <path d="M12 3v2.2M12 18.8V21M3 12h2.2M18.8 12H21M5.6 5.6l1.6 1.6M16.8 16.8l1.6 1.6M5.6 18.4l1.6-1.6M16.8 7.2l1.6-1.6" />
    </svg>
  ),
  "switch": (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <path d="M4 8h13l-3-3M20 16H7l3 3" />
    </svg>
  ),
  "macro": (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <path d="M5 7h4l1.2 1.5h8" />
      <rect x="5" y="11" width="14" height="7" rx="1.8" />
      <path d="M8.5 14.5h3M14 14.5h2.5" />
    </svg>
  ),
  "spellcheck": (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <path d="M4 17l3-9 3 9M5 14h4" />
      <path d="M13 17V8h3.5a2 2 0 0 1 0 4H13M13 12h4a2 2 0 0 1 0 4h-4" />
      <path d="M18 20l2 2 3-4" stroke="var(--jade-500)" />
    </svg>
  ),
  "chart": (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <path d="M4 20V8M10 20v-7M16 20V4M22 20H3" />
    </svg>
  ),

  // ─── Smart Switch states ─────────────────────────────────
  "robot": (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <rect x="5" y="8" width="14" height="11" rx="2.5" />
      <path d="M12 5v3M9.5 4.5h5" />
      <circle cx="9.5" cy="13" r="1.2" fill="currentColor" />
      <circle cx="14.5" cy="13" r="1.2" fill="currentColor" />
      <path d="M9.5 16.5h5" />
      <path d="M3 12.5h2M19 12.5h2" />
    </svg>
  ),
  "person": (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="8" r="3.5" />
      <path d="M4.5 20c1.2-3.8 4.2-6 7.5-6s6.3 2.2 7.5 6" />
    </svg>
  ),
  "ban": (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="12" r="8" />
      <path d="M6.5 6.5l11 11" />
    </svg>
  ),

  // ─── Actions ─────────────────────────────────────────────
  "plus": (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round">
      <path d="M12 5v14M5 12h14" />
    </svg>
  ),
  "minus": (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round">
      <path d="M5 12h14" />
    </svg>
  ),
  "trash": (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <path d="M4.5 7h15M9.5 7V5.5a1.5 1.5 0 0 1 1.5-1.5h2a1.5 1.5 0 0 1 1.5 1.5V7" />
      <path d="M6.5 7l1 12a2 2 0 0 0 2 2h5a2 2 0 0 0 2-2l1-12" />
      <path d="M10.5 11v6M13.5 11v6" />
    </svg>
  ),
  "edit": (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <path d="M4 20h4l10-10-4-4L4 16v4z" />
      <path d="M14 6l4 4" />
    </svg>
  ),
  "download": (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <path d="M12 4v12M7 11l5 5 5-5" />
      <path d="M4 20h16" />
    </svg>
  ),
  "upload": (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <path d="M12 20V8M7 13l5-5 5 5" />
      <path d="M4 4h16" />
    </svg>
  ),
  "refresh": (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <path d="M3 12a9 9 0 0 1 16-5.5V3" />
      <path d="M19 3v4h-4" />
      <path d="M21 12a9 9 0 0 1-16 5.5V21" />
      <path d="M5 21v-4h4" />
    </svg>
  ),
  "search": (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="11" cy="11" r="6" />
      <path d="M15.5 15.5l4 4" />
    </svg>
  ),

  // ─── Feedback ────────────────────────────────────────────
  "check": (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
      <path d="M5 12.5l4.5 4.5L19 7" />
    </svg>
  ),
  "info": (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="12" r="9" />
      <path d="M12 11v5" />
      <circle cx="12" cy="8" r="0.9" fill="currentColor" />
    </svg>
  ),
  "warn": (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <path d="M12 3.5L22 20H2L12 3.5z" />
      <path d="M12 10v4.5" />
      <circle cx="12" cy="17.5" r="0.9" fill="currentColor" />
    </svg>
  ),
  "lightbulb": (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <path d="M9 17.5h6M10 20.5h4" />
      <path d="M12 4a6 6 0 0 0-3.5 10.8c.6.5.9 1.2.9 1.9v.3h5.2v-.3c0-.7.3-1.4.9-1.9A6 6 0 0 0 12 4z" />
    </svg>
  ),

  // ─── Misc ────────────────────────────────────────────────
  "dictionary": (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <path d="M5 4h11a3 3 0 0 1 3 3v13H8a3 3 0 0 1-3-3V4z" />
      <path d="M5 17a3 3 0 0 1 3-3h11" />
      <path d="M9 8h6M9 11h4" />
    </svg>
  ),
  "globe": (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="12" r="9" />
      <path d="M3 12h18" />
      <path d="M12 3c2.8 3 4.2 6 4.2 9s-1.4 6-4.2 9c-2.8-3-4.2-6-4.2-9s1.4-6 4.2-9z" />
    </svg>
  ),
  "command": (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <path d="M9 6a2 2 0 1 0-2 2h10a2 2 0 1 0-2-2v10a2 2 0 1 0 2-2H7a2 2 0 1 0 2 2V6z" />
    </svg>
  ),
  "sparkle": (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <path d="M12 4L13.5 9.5 19 11l-5.5 1.5L12 18l-1.5-5.5L5 11l5.5-1.5L12 4z" />
      <path d="M19 16l.7 2.3L22 19l-2.3.7L19 22l-.7-2.3L16 19l2.3-.7L19 16z" />
    </svg>
  ),
  "tab-key": (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <path d="M4 12h12M12 8l4 4-4 4" />
      <path d="M19 7v10" />
    </svg>
  ),
  "esc-key": (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round">
      <rect x="3.5" y="6.5" width="17" height="11" rx="2" />
      <text x="6" y="14.2" fontFamily="JetBrains Mono, monospace" fontSize="6" fontWeight="700" fill="currentColor" stroke="none">esc</text>
    </svg>
  ),
  "backspace": (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <path d="M9 5h10a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H9L2 12l7-7z" />
      <path d="M11 9l6 6M17 9l-6 6" />
    </svg>
  ),
  "menu-bar": (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <rect x="2" y="4" width="20" height="4" rx="1.5" />
      <rect x="2" y="11" width="20" height="9" rx="2" />
    </svg>
  ),
  "donate": (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <path d="M12 20s-7-4.5-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 5.5-7 10-7 10z" />
    </svg>
  ),
  "chevron-down": (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
      <path d="M6 9l6 6 6-6" />
    </svg>
  ),
  "chevron-right": (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
      <path d="M9 6l6 6-6 6" />
    </svg>
  ),
  "x": (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round">
      <path d="M6 6l12 12M18 6L6 18" />
    </svg>
  ),
  "external": (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <path d="M14 4h6v6M20 4L12 12" />
      <path d="M18 14v4a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4" />
    </svg>
  ),
};

function Icon({ name, size = 18, color = "currentColor", style = {} }) {
  const svg = ICONS[name];
  if (!svg) return <span style={{display:'inline-block', width:size, height:size, background:'#f0a', borderRadius:3}} title={`missing icon: ${name}`} />;
  return React.cloneElement(svg, {
    width: size, height: size,
    style: { color, display: 'block', flex: 'none', ...style },
  });
}

Object.assign(window, { Icon, ICONS });
