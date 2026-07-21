import React from "react";

/* Logo mark: a stylized anvil + spark, standing in for the "forge" in CartForge */
export function LogoMark({ size = 26 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 32 32" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path d="M4 21h20l3 4H1l3-4Z" fill="#ff7a29" />
      <rect x="10" y="14" width="8" height="7" rx="1.5" fill="#ff7a29" />
      <path d="M12 14v-3a2 2 0 0 1 2-2h0a2 2 0 0 1 2 2v3" stroke="#ff7a29" strokeWidth="2" strokeLinecap="round" />
      <path d="M23 6l1.6 3.4L28 11l-3.4 1.6L23 16l-1.6-3.4L18 11l3.4-1.6L23 6Z" fill="#ffb37a" />
    </svg>
  );
}

export const NavIcon = {
  home: (p) => (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" {...p}>
      <path d="M4 11.5 12 4l8 7.5" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
      <path d="M6 10v9a1 1 0 0 0 1 1h4v-6h2v6h4a1 1 0 0 0 1-1v-9" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  ),
  login: (p) => (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" {...p}>
      <path d="M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
      <path d="M10 17l5-5-5-5M15 12H3" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  ),
  register: (p) => (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" {...p}>
      <circle cx="9" cy="8" r="3.2" stroke="currentColor" strokeWidth="1.8" />
      <path d="M3 20c0-3.3 2.7-6 6-6s6 2.7 6 6" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
      <path d="M18 8v6M15 11h6" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
    </svg>
  ),
  cart: (p) => (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" {...p}>
      <path d="M3 4h2l2.4 12.2A2 2 0 0 0 9.36 18H18a2 2 0 0 0 1.94-1.5L21.5 9H6" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
      <circle cx="10" cy="21" r="1.4" fill="currentColor" />
      <circle cx="18" cy="21" r="1.4" fill="currentColor" />
    </svg>
  ),
  orders: (p) => (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" {...p}>
      <path d="M6 3h9l4 4v13a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1Z" stroke="currentColor" strokeWidth="1.8" strokeLinejoin="round" />
      <path d="M9 10h6M9 14h6M9 18h3" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
    </svg>
  ),
  plus: (p) => (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" {...p}>
      <path d="M12 5v14M5 12h14" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
    </svg>
  ),
  logout: (p) => (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" {...p}>
      <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
      <path d="M16 17l5-5-5-5M21 12H9" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  ),
  search: (p) => (
    <svg width="15" height="15" viewBox="0 0 24 24" fill="none" {...p}>
      <circle cx="11" cy="11" r="7" stroke="currentColor" strokeWidth="1.8" />
      <path d="m21 21-4.3-4.3" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
    </svg>
  ),
  tag: (p) => (
    <svg width="15" height="15" viewBox="0 0 24 24" fill="none" {...p}>
      <path d="M20 12.5 12.5 20a1.5 1.5 0 0 1-2.1 0L3 12.5V4h8.5l8.5 8.5Z" stroke="currentColor" strokeWidth="1.8" strokeLinejoin="round" />
      <circle cx="8" cy="8" r="1.3" fill="currentColor" />
    </svg>
  ),
  rupee: (p) => (
    <svg width="15" height="15" viewBox="0 0 24 24" fill="none" {...p}>
      <path d="M6 4h12M6 9h12M6 4c4 0 8 1 8 5s-4 5-8 5l9 6" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  ),
  sort: (p) => (
    <svg width="15" height="15" viewBox="0 0 24 24" fill="none" {...p}>
      <path d="M7 4v16M7 4l-3 3M7 4l3 3M17 20V4M17 20l3-3M17 20l-3-3" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  ),
  flame: (p) => (
    <svg width="13" height="13" viewBox="0 0 24 24" fill="none" {...p}>
      <path d="M12 2s-5 5.5-5 10a5 5 0 0 0 10 0c0-1.6-.7-2.8-1.5-4 .3 2-.7 3-1.5 3 1-3-1-5-2-6 .3 1.5-1 2.7-1.8 3.7-.6.8-.7 1.8.3 2.8" fill="currentColor" />
    </svg>
  ),
  box: (p) => (
    <svg width="46" height="46" viewBox="0 0 24 24" fill="none" {...p}>
      <path d="M21 8 12 3 3 8l9 5 9-5Z" stroke="currentColor" strokeWidth="1.6" strokeLinejoin="round" />
      <path d="M3 8v8l9 5 9-5V8M12 13v8" stroke="currentColor" strokeWidth="1.6" strokeLinejoin="round" />
    </svg>
  ),
};

/* ---- Product illustrations: simple, cohesive geometric icons per category ---- */

export function ArtBottle() {
  return (
    <svg width="86" height="120" viewBox="0 0 86 120" fill="none">
      <rect x="34" y="6" width="18" height="14" rx="2" fill="#4b4f5c" />
      <path d="M30 20h26l6 14v70a6 6 0 0 1-6 6H30a6 6 0 0 1-6-6V34l6-14Z" fill="#ff9a4d" />
      <path d="M24 50h38v40a6 6 0 0 1-6 6H30a6 6 0 0 1-6-6V50Z" fill="#ffb37a" />
      <rect x="20" y="58" width="46" height="26" rx="4" fill="#14161f" />
      <text x="43" y="73" fontFamily="Space Grotesk, sans-serif" fontSize="9" fill="#fff" textAnchor="middle" fontWeight="700">JUICE</text>
    </svg>
  );
}

export function ArtFruit() {
  return (
    <svg width="120" height="110" viewBox="0 0 120 110" fill="none">
      <circle cx="42" cy="55" r="26" fill="#6b8f3c" />
      <circle cx="78" cy="65" r="22" fill="#7ea34a" />
      <circle cx="60" cy="35" r="18" fill="#8bb35a" />
      <circle cx="60" cy="35" r="18" fill="none" />
      <g transform="translate(46,20)">
        <circle cx="14" cy="14" r="13" fill="#e9f2d6" />
        <circle cx="14" cy="14" r="9" fill="#c7de8e" />
        {[...Array(8)].map((_, i) => {
          const a = (i / 8) * Math.PI * 2;
          return <circle key={i} cx={14 + Math.cos(a) * 6} cy={14 + Math.sin(a) * 6} r="1.3" fill="#3d4a1f" />;
        })}
      </g>
    </svg>
  );
}

export function ArtCosmeticWand() {
  return (
    <svg width="70" height="120" viewBox="0 0 70 120" fill="none">
      <rect x="26" y="8" width="18" height="46" rx="9" fill="#14161f" />
      <rect x="29" y="4" width="12" height="10" rx="3" fill="#4b4f5c" />
      <rect x="30" y="52" width="10" height="58" rx="4" fill="#1e2130" />
      <rect x="30" y="52" width="10" height="12" fill="#ff7a29" />
      {[...Array(6)].map((_, i) => (
        <rect key={i} x="24" y={60 + i * 8} width="22" height="3" rx="1.5" fill="#3d4152" />
      ))}
    </svg>
  );
}

export function ArtLipstick() {
  return (
    <svg width="60" height="120" viewBox="0 0 60 120" fill="none">
      <rect x="16" y="60" width="28" height="46" rx="4" fill="#14161f" />
      <rect x="16" y="60" width="28" height="10" fill="#4b4f5c" />
      <rect x="18" y="34" width="24" height="28" rx="3" fill="#d6d9e0" />
      <path d="M20 34c0-9 4-16 10-16s10 7 10 16H20Z" fill="#d64545" />
    </svg>
  );
}

export function ArtBread() {
  return (
    <svg width="120" height="90" viewBox="0 0 120 90" fill="none">
      <path d="M14 70V38c0-16 12-26 46-26s46 10 46 26v32H14Z" fill="#d9a25e" />
      <path d="M14 70V44c8 6 20 9 46 9s38-3 46-9v26H14Z" fill="#c98a45" />
      <path d="M20 38c8-14 24-20 40-20s32 6 40 20" stroke="#8a5a28" strokeWidth="2" strokeLinecap="round" fill="none" />
      <line x1="30" y1="30" x2="34" y2="46" stroke="#8a5a28" strokeWidth="2" strokeLinecap="round" />
      <line x1="45" y1="24" x2="48" y2="42" stroke="#8a5a28" strokeWidth="2" strokeLinecap="round" />
      <line x1="60" y1="21" x2="60" y2="40" stroke="#8a5a28" strokeWidth="2" strokeLinecap="round" />
      <line x1="75" y1="24" x2="72" y2="42" stroke="#8a5a28" strokeWidth="2" strokeLinecap="round" />
      <line x1="90" y1="30" x2="86" y2="46" stroke="#8a5a28" strokeWidth="2" strokeLinecap="round" />
    </svg>
  );
}

export function ArtEarbuds() {
  return (
    <svg width="100" height="110" viewBox="0 0 100 110" fill="none">
      <rect x="20" y="10" width="60" height="80" rx="14" fill="#14161f" />
      <circle cx="35" cy="40" r="13" fill="#3d4152" />
      <circle cx="65" cy="40" r="13" fill="#3d4152" />
      <rect x="29" y="55" width="12" height="30" rx="6" fill="#3d4152" />
      <rect x="59" y="55" width="12" height="30" rx="6" fill="#3d4152" />
      <circle cx="35" cy="40" r="5" fill="#ff7a29" />
      <circle cx="65" cy="40" r="5" fill="#ff7a29" />
    </svg>
  );
}

export function ArtGrain() {
  return (
    <svg width="90" height="120" viewBox="0 0 90 120" fill="none">
      <path d="M14 30h62l-6 78a6 6 0 0 1-6 5.5H26a6 6 0 0 1-6-5.5L14 30Z" fill="#f2e6c8" />
      <path d="M10 18h70l4 12H6l4-12Z" fill="#c9640a" />
      <rect x="20" y="22" width="50" height="8" rx="2" fill="#ff9a4d" />
      <circle cx="45" cy="66" r="18" fill="#e8871e" opacity="0.15" />
      <text x="45" y="72" fontFamily="Space Grotesk, sans-serif" fontSize="11" fill="#c9640a" textAnchor="middle" fontWeight="700">RICE</text>
    </svg>
  );
}

export function ArtJar() {
  return (
    <svg width="90" height="110" viewBox="0 0 90 110" fill="none">
      <rect x="24" y="8" width="42" height="14" rx="3" fill="#4b4f5c" />
      <path d="M20 22h50a4 4 0 0 1 4 4v66a10 10 0 0 1-10 10H26a10 10 0 0 1-10-10V26a4 4 0 0 1 4-4Z" fill="#f2e6c8" />
      <rect x="16" y="50" width="58" height="40" fill="#b98a4a" />
      <rect x="16" y="60" width="58" height="6" fill="#14161f" opacity="0.85" />
    </svg>
  );
}
