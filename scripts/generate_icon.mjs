/**
 * generate_icon.mjs
 *
 * Genera assets/icon/app_icon.png  (1024×1024)  e
 *                  app_icon_fg.png (1024×1024 con padding, per adaptive icon)
 *
 * Dipendenze: npm install canvas
 * Esecuzione: node scripts/generate_icon.mjs
 */

import { createCanvas } from 'canvas';
import { writeFileSync, mkdirSync } from 'fs';
import path from 'path';

const SIZE  = 1024;
const CHAR  = '#1A1A1A';
const LIME  = '#C5D800';
const OUT   = path.resolve('assets/icon');

mkdirSync(OUT, { recursive: true });

// ── Full icon (charcoal bg + lime "3F") ──────────────────────────────────────
{
  const canvas = createCanvas(SIZE, SIZE);
  const ctx    = canvas.getContext('2d');

  // Background
  ctx.fillStyle = CHAR;
  ctx.fillRect(0, 0, SIZE, SIZE);

  // Rounded rect mask (optional, looks better on iOS)
  // iOS clips to its own mask — no need to round corners

  // Lime border accent
  const borderW = 28;
  ctx.strokeStyle = LIME;
  ctx.lineWidth   = borderW;
  const inset = 80;
  const radius = 100;
  const x = inset, y = inset, w = SIZE - inset * 2, h = SIZE - inset * 2;
  ctx.beginPath();
  ctx.moveTo(x + radius, y);
  ctx.lineTo(x + w - radius, y);
  ctx.arcTo(x + w, y,     x + w, y + radius,     radius);
  ctx.lineTo(x + w, y + h - radius);
  ctx.arcTo(x + w, y + h, x + w - radius, y + h, radius);
  ctx.lineTo(x + radius, y + h);
  ctx.arcTo(x, y + h, x, y + h - radius, radius);
  ctx.lineTo(x, y + radius);
  ctx.arcTo(x, y, x + radius, y, radius);
  ctx.closePath();
  ctx.stroke();

  // "3F" text
  ctx.fillStyle    = LIME;
  ctx.font         = `bold ${SIZE * 0.45}px Arial Black, sans-serif`;
  ctx.textAlign    = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText('3F', SIZE / 2, SIZE / 2 + 10);

  writeFileSync(path.join(OUT, 'app_icon.png'), canvas.toBuffer('image/png'));
  console.log('✓ app_icon.png');
}

// ── Adaptive foreground (transparent bg + lime "3F", padded) ─────────────────
{
  const canvas = createCanvas(SIZE, SIZE);
  const ctx    = canvas.getContext('2d');

  // transparent background (for adaptive fg)
  ctx.clearRect(0, 0, SIZE, SIZE);

  ctx.fillStyle    = LIME;
  ctx.font         = `bold ${SIZE * 0.38}px Arial Black, sans-serif`;
  ctx.textAlign    = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText('3F', SIZE / 2, SIZE / 2);

  writeFileSync(path.join(OUT, 'app_icon_fg.png'), canvas.toBuffer('image/png'));
  console.log('✓ app_icon_fg.png');
}

console.log('\nDone! Run:');
console.log('  flutter pub run flutter_launcher_icons');
