// Inline SVG flags: emoji flags don't render on Windows. All drawn at 3:2, the UK flag cropped to fit.
const svgProps = {
  width: 30,
  height: 20,
  "aria-hidden": true,
  focusable: false,
  style: { display: "block", borderRadius: 2 },
};

export function EsFlag() {
  return (
    <svg {...svgProps} viewBox="0 0 3 2">
      <rect width="3" height="2" fill="#AA151B" />
      <rect y="0.5" width="3" height="1" fill="#F1BF00" />
    </svg>
  );
}

export function GbFlag() {
  return (
    <svg {...svgProps} viewBox="0 0 60 30" preserveAspectRatio="xMidYMid slice">
      <clipPath id="gb-flag-diagonals">
        <path d="M30,15 h30 v15 z v15 h-30 z h-30 v-15 z v-15 h30 z" />
      </clipPath>
      <rect width="60" height="30" fill="#012169" />
      <path d="M0,0 L60,30 M60,0 L0,30" stroke="#fff" strokeWidth="6" />
      <path d="M0,0 L60,30 M60,0 L0,30" clipPath="url(#gb-flag-diagonals)" stroke="#C8102E" strokeWidth="4" />
      <path d="M30,0 v30 M0,15 h60" stroke="#fff" strokeWidth="10" />
      <path d="M30,0 v30 M0,15 h60" stroke="#C8102E" strokeWidth="6" />
    </svg>
  );
}

export function FrFlag() {
  return (
    <svg {...svgProps} viewBox="0 0 3 2">
      <rect width="1" height="2" fill="#002654" />
      <rect x="1" width="1" height="2" fill="#FFFFFF" />
      <rect x="2" width="1" height="2" fill="#ED2939" />
    </svg>
  );
}
