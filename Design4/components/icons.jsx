/* eslint-disable */
/* vkey 3D — Icon library
   Each icon is a simple SF-Symbol-style glyph rendered in white/currentColor.
   The 3D glass effect lives in the .tile wrapper (see glass.css).
   Use: <Icon name="gear" /> or <GlassTile color="red"><Icon name="gear"/></GlassTile>
*/

const GLYPHS = {
  gear: (
    <g fill="currentColor">
      <path d="M12 8a4 4 0 1 1 0 8 4 4 0 0 1 0-8zm0 2a2 2 0 1 0 0 4 2 2 0 0 0 0-4z"/>
      <path d="M19.4 13.6c.03-.5.03-1.06 0-1.6l1.6-1.2-2-3.4-1.9.7c-.4-.3-.85-.55-1.3-.75L15.5 5h-3l-.3 2c-.45.2-.9.45-1.3.75l-1.9-.7-2 3.4 1.6 1.2c-.03.54-.03 1.1 0 1.6l-1.6 1.2 2 3.4 1.9-.7c.4.3.85.55 1.3.75l.3 2h3l.3-2c.45-.2.9-.45 1.3-.75l1.9.7 2-3.4-1.6-1.2z" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinejoin="round"/>
    </g>
  ),
  sparkles: (
    <g fill="currentColor">
      <path d="M12 2l1.4 4.6L18 8l-4.6 1.4L12 14l-1.4-4.6L6 8l4.6-1.4z"/>
      <path d="M18 14l.8 2.4L21 17l-2.2.6L18 20l-.8-2.4L15 17l2.2-.6z"/>
      <path d="M6 16l.6 1.8L8 18l-1.4.4L6 20l-.6-1.6L4 18l1.4-.4z"/>
    </g>
  ),
  lightbulb: (
    <g fill="currentColor">
      <path d="M12 3a6 6 0 0 0-4 10.5c.6.7 1 1.6 1 2.5v.5h6V16c0-.9.4-1.8 1-2.5A6 6 0 0 0 12 3z" fill="none" stroke="currentColor" strokeWidth="1.5"/>
      <rect x="9.5" y="18" width="5" height="2" rx="1"/>
      <path d="M10.5 21h3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/>
    </g>
  ),
  wand: (
    <g fill="currentColor">
      <path d="M5 19l9-9 3 3-9 9-3-3z" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinejoin="round"/>
      <path d="M14 6l1-3 1 3 3 1-3 1-1 3-1-3-3-1z"/>
      <circle cx="20" cy="11" r="0.8"/>
      <circle cx="8" cy="4" r="0.8"/>
    </g>
  ),
  chart: (
    <g fill="currentColor">
      <rect x="4" y="13" width="3" height="7" rx="0.6"/>
      <rect x="9.5" y="9" width="3" height="11" rx="0.6"/>
      <rect x="15" y="5" width="3" height="15" rx="0.6"/>
    </g>
  ),
  robot: (
    <g fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinejoin="round">
      <rect x="5" y="8" width="14" height="11" rx="3"/>
      <path d="M12 5v3"/>
      <circle cx="12" cy="4" r="1" fill="currentColor"/>
      <circle cx="9.5" cy="13" r="1.2" fill="currentColor" stroke="none"/>
      <circle cx="14.5" cy="13" r="1.2" fill="currentColor" stroke="none"/>
      <path d="M3 12v3M21 12v3"/>
    </g>
  ),
  lock: (
    <g fill="currentColor">
      <rect x="5" y="11" width="14" height="10" rx="2.5"/>
      <path d="M8 11V8a4 4 0 0 1 8 0v3" fill="none" stroke="currentColor" strokeWidth="1.8"/>
      <circle cx="12" cy="16" r="1.4" fill="rgba(0,0,0,0.4)"/>
    </g>
  ),
  lockOpen: (
    <g fill="currentColor">
      <rect x="5" y="11" width="14" height="10" rx="2.5"/>
      <path d="M8 11V8a4 4 0 0 1 7.5-2" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"/>
      <circle cx="12" cy="16" r="1.4" fill="rgba(0,0,0,0.4)"/>
    </g>
  ),
  abc: (
    <g fill="currentColor" fontFamily="-apple-system, sans-serif" fontWeight="800" fontSize="10">
      <text x="3" y="16">A</text>
      <text x="10" y="16">B</text>
      <text x="17" y="16">C</text>
      <rect x="3" y="18" width="18" height="1.5" rx="0.7" opacity="0.5"/>
    </g>
  ),
  power: (
    <g fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round">
      <path d="M12 4v8"/>
      <path d="M8.5 6.5a6 6 0 1 0 7 0"/>
    </g>
  ),
  info: (
    <g fill="currentColor">
      <circle cx="12" cy="12" r="9" fill="none" stroke="currentColor" strokeWidth="1.5"/>
      <circle cx="12" cy="8" r="1.1"/>
      <rect x="11" y="10.5" width="2" height="7" rx="0.8"/>
    </g>
  ),
  keyboard: (
    <g fill="currentColor">
      <rect x="3" y="6" width="18" height="13" rx="2.5" fill="none" stroke="currentColor" strokeWidth="1.5"/>
      <rect x="5.5" y="8.5" width="2" height="2" rx="0.4"/>
      <rect x="9" y="8.5" width="2" height="2" rx="0.4"/>
      <rect x="12.5" y="8.5" width="2" height="2" rx="0.4"/>
      <rect x="16" y="8.5" width="2.5" height="2" rx="0.4"/>
      <rect x="5.5" y="11.5" width="2" height="2" rx="0.4"/>
      <rect x="9" y="11.5" width="2" height="2" rx="0.4"/>
      <rect x="12.5" y="11.5" width="2" height="2" rx="0.4"/>
      <rect x="16" y="11.5" width="2.5" height="2" rx="0.4"/>
      <rect x="7" y="14.5" width="10" height="2" rx="0.6"/>
    </g>
  ),
  rocket: (
    <g fill="currentColor">
      <path d="M12 2c3 2 5 5.5 5 9v5l-2.5 2.5L12 21l-2.5-2.5L7 16v-5c0-3.5 2-7 5-9z" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinejoin="round"/>
      <circle cx="12" cy="10" r="2"/>
      <path d="M9 18l-2 3M15 18l2 3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" fill="none"/>
    </g>
  ),
  book: (
    <g fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinejoin="round">
      <path d="M4 5v14a2 2 0 0 0 2 2h13V4H6a2 2 0 0 0-2 1z"/>
      <path d="M9 4v17M19 8H12M19 11H12M19 14H12"/>
    </g>
  ),
  paintbrush: (
    <g fill="currentColor">
      <path d="M19 3l-9 9-2-2 9-9z" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinejoin="round"/>
      <path d="M10 12c-2 1-3 3-3 5l-3 3c2 0 4-1 5-3 2-1 3-3 3-5z"/>
    </g>
  ),
  person: (
    <g fill="currentColor">
      <circle cx="12" cy="8" r="3.5" fill="none" stroke="currentColor" strokeWidth="1.5"/>
      <path d="M5 20c1-3 3.5-5 7-5s6 2 7 5" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/>
    </g>
  ),
  trash: (
    <g fill="currentColor">
      <path d="M5 7h14M9 7V5a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2v2M7 7l1 13a2 2 0 0 0 2 2h4a2 2 0 0 0 2-2l1-13" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinejoin="round"/>
      <path d="M10 11v6M14 11v6" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/>
    </g>
  ),
  download: (
    <g fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
      <path d="M12 4v11"/>
      <path d="M7 11l5 5 5-5"/>
      <path d="M5 19h14"/>
    </g>
  ),
  upload: (
    <g fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
      <path d="M12 20V9"/>
      <path d="M7 13l5-5 5 5"/>
      <path d="M5 5h14"/>
    </g>
  ),
  plus: (
    <g fill="currentColor">
      <rect x="4" y="11" width="16" height="2.4" rx="1.2"/>
      <rect x="10.8" y="4" width="2.4" height="16" rx="1.2"/>
    </g>
  ),
  check: (
    <g fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round">
      <path d="M5 12l5 5L20 7"/>
    </g>
  ),
  shield: (
    <g fill="currentColor">
      <path d="M12 3l8 3v6c0 4.5-3 8.5-8 10-5-1.5-8-5.5-8-10V6z" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinejoin="round"/>
      <path d="M9 12l2.5 2.5L16 10" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
    </g>
  ),
  switch: (
    <g fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
      <path d="M4 8h13l-3-3"/>
      <path d="M20 16H7l3 3"/>
    </g>
  ),
  globe: (
    <g fill="none" stroke="currentColor" strokeWidth="1.5">
      <circle cx="12" cy="12" r="9"/>
      <ellipse cx="12" cy="12" rx="9" ry="4"/>
      <path d="M12 3v18M3 12h18"/>
    </g>
  ),
  cmd: (
    <g fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinejoin="round">
      <path d="M9 9V6.5A2.5 2.5 0 1 0 6.5 9zM15 9V6.5a2.5 2.5 0 1 1 2.5 2.5zM9 15v2.5A2.5 2.5 0 1 1 6.5 15zM15 15v2.5a2.5 2.5 0 1 0 2.5-2.5zM9 9h6v6H9z"/>
    </g>
  ),
  flagVn: (
    <g>
      <rect x="3" y="6" width="18" height="12" rx="2" fill="#DA251D"/>
      <path d="M12 8.5l1.4 3 3.1.3-2.4 2 .8 3-2.9-1.6-2.9 1.6.8-3-2.4-2 3.1-.3z" fill="#FFD400"/>
    </g>
  ),
  flagUs: (
    <g>
      <rect x="3" y="6" width="18" height="12" rx="2" fill="#FFFFFF"/>
      <path d="M3 8h18M3 10h18M3 12h18M3 14h18M3 16h18" stroke="#B22234" strokeWidth="1"/>
      <rect x="3" y="6" width="8" height="7" fill="#3C3B6E" rx="1"/>
      <g fill="#fff">
        {[...Array(3)].map((_, r) => [...Array(4)].map((_, c) => (
          <circle key={r+'-'+c} cx={4 + c*2} cy={7 + r*2} r="0.5"/>
        )))}
      </g>
    </g>
  ),
  bell: (
    <g fill="currentColor">
      <path d="M12 3a5 5 0 0 0-5 5v4l-2 3h14l-2-3V8a5 5 0 0 0-5-5z" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinejoin="round"/>
      <path d="M10 18a2 2 0 0 0 4 0" fill="none" stroke="currentColor" strokeWidth="1.5"/>
    </g>
  ),
  refresh: (
    <g fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
      <path d="M4 12a8 8 0 0 1 14-5.3"/>
      <path d="M18 3v4h-4"/>
      <path d="M20 12a8 8 0 0 1-14 5.3"/>
      <path d="M6 21v-4h4"/>
    </g>
  ),
};

function Icon({ name, size = 22, color, style }) {
  const glyph = GLYPHS[name];
  if (!glyph) return null;
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      width={size}
      height={size}
      style={{ color: color || 'white', ...style }}
    >
      {glyph}
    </svg>
  );
}

function GlassTile({ color = 'red', size = 'md', children, style }) {
  const cls = `tile tile--${color}${size === 'sm' ? ' tile--sm' : size === 'lg' ? ' tile--lg' : ''}`;
  return <span className={cls} style={style}>{children}</span>;
}

window.Icon = Icon;
window.GlassTile = GlassTile;
window.ICON_NAMES = Object.keys(GLYPHS);
