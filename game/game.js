'use strict';
/*
 * GUNFALL — платформер-рогалик.
 * Чистый JavaScript + Canvas, без зависимостей.
 * Каждый забег: новая процедурная карта, огнестрельное оружие,
 * враги, улучшения между уровнями, перманентная смерть.
 */
(() => {

// ============================== Константы ==============================

const TILE = 32, VW = 960, VH = 540;
const GRAV = 0.55, MAX_FALL = 15;

// Тайлы: 0 пусто, 1 твёрдый, 2 платформа (односторонняя), 3 шипы, 4 выход
const T_EMPTY = 0, T_SOLID = 1, T_PLAT = 2, T_SPIKE = 3, T_EXIT = 4;

const THEMES = [
  { name: 'Изумрудные пещеры', sky0: '#0e1830', sky1: '#1d3250', hillFar: '#15233c', hillNear: '#1b2c4a',
    ground: '#2c3a55', top: '#58c98f', plat: '#7fdcae', spike: '#bcd0ff' },
  { name: 'Багровые руины', sky0: '#180d1c', sky1: '#3a1c33', hillFar: '#241229', hillNear: '#301a37',
    ground: '#3d2438', top: '#e0707a', plat: '#f29a8e', spike: '#ffd3c0' },
  { name: 'Ледяные шахты', sky0: '#0b1426', sky1: '#1d3a55', hillFar: '#142339', hillNear: '#1b2f4a',
    ground: '#31415f', top: '#8fd8f2', plat: '#b5e8fa', spike: '#e8f6ff' },
  { name: 'Токсичные топи', sky0: '#0d1612', sky1: '#1d3328', hillFar: '#13241b', hillNear: '#1a3124',
    ground: '#2b3d31', top: '#a8d65c', plat: '#c6ec85', spike: '#e9ffc9' },
  { name: 'Пустынный форт', sky0: '#1a1208', sky1: '#3d2c14', hillFar: '#291e0e', hillNear: '#352813',
    ground: '#4a3a20', top: '#e6b566', plat: '#f4ce8d', spike: '#ffe9c2' },
];

const WEAPONS = {
  pistol:  { name: 'Пистолет',  dmg: 12, cd: 16, spd: 12, spread: 0.035, pellets: 1, auto: false, ammo: Infinity, color: '#ffd86b', kick: 1.2, len: 15 },
  smg:     { name: 'ПП «Оса»',  dmg: 8,  cd: 6,  spd: 13, spread: 0.10,  pellets: 1, auto: true,  ammo: 150,      color: '#9be8ff', kick: 1.6, len: 17 },
  shotgun: { name: 'Дробовик',  dmg: 9,  cd: 44, spd: 11, spread: 0.24,  pellets: 6, auto: false, ammo: 32,       color: '#ffb077', kick: 5.0, len: 19 },
  rifle:   { name: 'Винтовка',  dmg: 36, cd: 34, spd: 18, spread: 0.012, pellets: 1, auto: false, ammo: 30,       color: '#d3a4ff', kick: 3.2, len: 23 },
};
const WEAPON_DROPS = ['smg', 'shotgun', 'rifle'];

const UPGRADES = [
  { id: 'hp',    icon: '❤️', name: 'Живучесть',        desc: '+25 к максимуму здоровья и лечение на 25' },
  { id: 'dmg',   icon: '💥', name: 'Крупный калибр',   desc: '+15% к урону всего оружия' },
  { id: 'rate',  icon: '🔥', name: 'Скорострельность', desc: 'Оружие стреляет на 12% быстрее' },
  { id: 'speed', icon: '👟', name: 'Лёгкие ботинки',   desc: '+10% к скорости бега' },
  { id: 'djump', icon: '🕊️', name: 'Двойной прыжок',   desc: 'Дополнительный прыжок в воздухе', unique: true },
  { id: 'steal', icon: '🩸', name: 'Вампиризм',        desc: '+3 здоровья за каждое убийство' },
  { id: 'armor', icon: '🛡️', name: 'Бронежилет',       desc: 'Получаемый урон снижен на 15%' },
  { id: 'crit',  icon: '🎯', name: 'Крит. патроны',    desc: '+10% шанс двойного урона' },
  { id: 'jump',  icon: '🦘', name: 'Пружины',          desc: '+8% к высоте прыжка' },
];

const ENEMY_BASE = {
  walker:  { w: 26, h: 28, hp: 30,  spd: 1.1, dmg: 12, score: 10 },
  shooter: { w: 26, h: 30, hp: 42,  spd: 0,   dmg: 9,  score: 20, cd: 105 },
  flyer:   { w: 24, h: 20, hp: 22,  spd: 1.7, dmg: 10, score: 15, fly: true },
  tank:    { w: 36, h: 38, hp: 130, spd: 0.55, dmg: 11, score: 45, cd: 135 },
};

// ============================== Утилиты ==============================

const clamp = (v, a, b) => v < a ? a : v > b ? b : v;
const lerp = (a, b, t) => a + (b - a) * t;

function mulberry32(seed) {
  let s = seed >>> 0;
  return () => {
    s = (s + 0x6D2B79F5) >>> 0;
    let t = s;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const ri = (rng, a, b) => a + Math.floor(rng() * (b - a + 1));
const pick = (rng, arr) => arr[Math.floor(rng() * arr.length)];

function hashSeed(str) {
  let h = 2166136261;
  for (let i = 0; i < str.length; i++) {
    h ^= str.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

// ============================== DOM ==============================

const cv = document.getElementById('game');
const ctx = cv.getContext('2d');
const ov = {
  menu: document.getElementById('menuOv'),
  upgrade: document.getElementById('upgradeOv'),
  dead: document.getElementById('deadOv'),
  pause: document.getElementById('pauseOv'),
};
const seedInput = document.getElementById('seedInput');
const cardsEl = document.getElementById('cards');
const deadStatsEl = document.getElementById('deadStats');
const bestLineEl = document.getElementById('bestLine');

function showOverlay(name) {
  for (const k in ov) ov[k].classList.toggle('hidden', k !== name);
}

// ============================== Звук ==============================

let actx = null, muted = false;
try { muted = localStorage.getItem('gunfall.muted') === '1'; } catch (e) { /* приватный режим */ }

function audioInit() {
  if (actx) return;
  try {
    const AC = window.AudioContext || window.webkitAudioContext;
    if (AC) actx = new AC();
  } catch (e) { actx = null; }
}

function tone(freq, freqEnd, dur, type, vol) {
  if (!actx || muted) return;
  try {
    const t0 = actx.currentTime;
    const o = actx.createOscillator(), g = actx.createGain();
    o.type = type;
    o.frequency.setValueAtTime(freq, t0);
    o.frequency.exponentialRampToValueAtTime(Math.max(1, freqEnd), t0 + dur);
    g.gain.setValueAtTime(vol, t0);
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
    o.connect(g).connect(actx.destination);
    o.start(t0);
    o.stop(t0 + dur);
  } catch (e) { /* звук не критичен */ }
}

function noise(dur, vol, low) {
  if (!actx || muted) return;
  try {
    const n = Math.floor(actx.sampleRate * dur);
    const buf = actx.createBuffer(1, n, actx.sampleRate);
    const d = buf.getChannelData(0);
    let v = 0;
    for (let i = 0; i < n; i++) {
      const w = Math.random() * 2 - 1;
      v = low ? v * 0.92 + w * 0.08 : w;
      d[i] = v * (1 - i / n);
    }
    const src = actx.createBufferSource(), g = actx.createGain();
    src.buffer = buf;
    g.gain.value = vol;
    src.connect(g).connect(actx.destination);
    src.start();
  } catch (e) { /* звук не критичен */ }
}

const sfx = {
  shoot:   () => { tone(320, 90, 0.09, 'square', 0.10); },
  shotgun: () => { noise(0.22, 0.30); tone(140, 50, 0.18, 'sawtooth', 0.12); },
  rifle:   () => { noise(0.10, 0.18); tone(520, 120, 0.12, 'square', 0.10); },
  hit:     () => { tone(210, 140, 0.06, 'triangle', 0.14); },
  kill:    () => { noise(0.16, 0.20, true); tone(160, 40, 0.22, 'triangle', 0.16); },
  hurt:    () => { tone(160, 55, 0.22, 'sawtooth', 0.18); },
  jump:    () => { tone(240, 480, 0.10, 'square', 0.07); },
  pickup:  () => { tone(520, 880, 0.12, 'square', 0.10); },
  portal:  () => { tone(330, 660, 0.30, 'sine', 0.16); tone(440, 880, 0.30, 'sine', 0.12); },
  select:  () => { tone(600, 900, 0.08, 'square', 0.08); },
};

// ============================== Ввод ==============================

const keys = {}, pressed = {};
const mouse = { x: VW / 2, y: VH / 2, down: false, clicked: false };

const GAME_CODES = new Set(['Space', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'KeyW', 'KeyA', 'KeyS', 'KeyD']);

window.addEventListener('keydown', (e) => {
  if (e.target && e.target.tagName === 'INPUT') {
    if (e.code === 'Enter' && G.state === 'menu') startFromMenu();
    return;
  }
  if (GAME_CODES.has(e.code)) e.preventDefault();
  if (!e.repeat) pressed[e.code] = true;
  keys[e.code] = true;

  if (e.code === 'KeyM') {
    muted = !muted;
    try { localStorage.setItem('gunfall.muted', muted ? '1' : '0'); } catch (err) { /* ок */ }
  }
  if (e.code === 'Escape' || e.code === 'KeyP') {
    if (G.state === 'play') setState('pause');
    else if (G.state === 'pause') setState('play');
  }
  if (e.code === 'Enter') {
    if (G.state === 'menu') startFromMenu();
    else if (G.state === 'dead') startFromMenu();
  }
});
window.addEventListener('keyup', (e) => { keys[e.code] = false; });
window.addEventListener('blur', () => {
  for (const k in keys) keys[k] = false;
  mouse.down = false;
  if (G.state === 'play') setState('pause');
});

cv.addEventListener('mousemove', (e) => {
  const r = cv.getBoundingClientRect();
  mouse.x = (e.clientX - r.left) * (VW / r.width);
  mouse.y = (e.clientY - r.top) * (VH / r.height);
});
cv.addEventListener('mousedown', (e) => {
  audioInit();
  if (e.button === 0) { mouse.down = true; mouse.clicked = true; }
});
window.addEventListener('mouseup', (e) => { if (e.button === 0) mouse.down = false; });
cv.addEventListener('contextmenu', (e) => e.preventDefault());
cv.addEventListener('wheel', (e) => {
  e.preventDefault();
  if (G.state !== 'play' || P.weapons.length < 2) return;
  const d = e.deltaY > 0 ? 1 : -1;
  switchWeapon((P.wi + d + P.weapons.length) % P.weapons.length);
}, { passive: false });

document.addEventListener('visibilitychange', () => {
  if (document.hidden && G.state === 'play') setState('pause');
});

// ============================== Состояние игры ==============================

const G = {
  state: 'menu',   // menu | play | pause | upgrade | dead
  level: 1, score: 0, kills: 0,
  runSeed: 0, seedLabel: '',
  t: 0, shake: 0,
  camX: 0, camY: 0,
  intro: 0, introText: '',
  lowAmmoT: 0,
  offer: [],
  best: 0,
};
try { G.best = +localStorage.getItem('gunfall.best') || 0; } catch (e) { /* ок */ }

let level = null;      // текущая карта
let P = null;          // игрок
let enemies = [], bullets = [], parts = [], pickups = [], texts = [];

function makePlayer() {
  return {
    x: 0, y: 0, w: 20, h: 30, vx: 0, vy: 0,
    hp: 100, maxhp: 100,
    onGround: false, hitWall: false,
    coyote: 0, buffer: 0, airJumps: 0, drop: 0,
    inv: 0, cd: 0, face: 1, aim: 0,
    weapons: [{ id: 'pistol', ammo: Infinity }], wi: 0,
    stats: { dmgMul: 1, cdMul: 1, spdMul: 1, jumps: 1, lifesteal: 0, armorMul: 1, crit: 0, jumpMul: 1 },
  };
}
P = makePlayer();

function setState(s) {
  G.state = s;
  if (s === 'play') showOverlay(null);
  else if (s === 'pause') showOverlay('pause');
  else if (s === 'menu') { showOverlay('menu'); updateBestLine(); }
  else if (s === 'dead') showOverlay('dead');
  else if (s === 'upgrade') showOverlay('upgrade');
}

function updateBestLine() {
  bestLineEl.textContent = G.best > 0 ? `Рекорд: ${G.best} очков` : 'Удачного первого забега!';
}

// ============================== Генерация уровня ==============================

function generateLevel(seed, lvl) {
  const rng = mulberry32(seed);
  const W = clamp(130 + lvl * 12, 130, 260);
  const H = 36;
  const grid = new Uint8Array(W * H);
  const groundY = new Array(W);
  const tile = (tx, ty) => grid[ty * W + tx];
  const setTile = (tx, ty, t) => { if (tx >= 0 && tx < W && ty >= 0 && ty < H) grid[ty * W + tx] = t; };

  // --- рельеф: случайное блуждание высоты, шаг не больше 1 тайла ---
  let h = 26;
  const minH = 13, maxH = 31;
  for (let x = 0; x < 8; x++) groundY[x] = h;
  const spikeCols = new Set();
  let x = 8, lastPitEnd = -99;

  while (x < W - 10) {
    const r = rng();
    if (r < 0.16 && x - lastPitEnd > 7 && h + 3 < maxH) {
      // яма с шипами: пол ниже, высота после ямы та же — перепрыгивается
      const pw = ri(rng, 2, 4);
      const depth = ri(rng, 2, 3);
      for (let i = 0; i < pw && x < W - 10; i++, x++) {
        groundY[x] = h + depth;
        spikeCols.add(x);
      }
      lastPitEnd = x;
      continue;
    }
    if (r < 0.55) h = clamp(h + pick(rng, [-1, -1, 0, 1, 1]), minH, maxH);
    groundY[x] = h;
    x++;
  }
  for (; x < W; x++) groundY[x] = h;

  // одиночные шипы на ровных участках
  for (let sx = 14; sx < W - 14; sx++) {
    if (rng() < 0.018 && !spikeCols.has(sx) && !spikeCols.has(sx - 1) && !spikeCols.has(sx + 1)
        && groundY[sx] === groundY[sx - 1] && groundY[sx] === groundY[sx + 1]) {
      spikeCols.add(sx);
    }
  }

  // заливка земли и шипов
  for (let tx = 0; tx < W; tx++) {
    for (let ty = groundY[tx]; ty < H; ty++) setTile(tx, ty, T_SOLID);
    if (spikeCols.has(tx)) setTile(tx, groundY[tx] - 1, T_SPIKE);
  }

  // --- односторонние платформы (3 тайла над опорой — достаётся прыжком) ---
  const platforms = [];
  const platCells = [];
  const platTries = 14 + lvl * 3;
  for (let i = 0; i < platTries; i++) {
    const len = ri(rng, 3, 6);
    const x0 = ri(rng, 10, W - 14 - len);
    let base = H;
    for (let j = 0; j < len; j++) base = Math.min(base, groundY[x0 + j]);
    const py = base - ri(rng, 3, 4);
    if (py < 6) continue;
    let ok = true;
    for (let j = 0; j < len; j++) {
      if (tile(x0 + j, py) !== T_EMPTY || tile(x0 + j, py - 1) !== T_EMPTY || tile(x0 + j, py + 1) !== T_EMPTY) { ok = false; break; }
    }
    if (!ok) continue;
    for (let j = 0; j < len; j++) { setTile(x0 + j, py, T_PLAT); platCells.push({ x: x0 + j, y: py }); }
    platforms.push({ x0, len, y: py });
  }
  // второй ярус над существующими платформами
  const tier2Tries = Math.floor(platforms.length / 2);
  for (let i = 0; i < tier2Tries; i++) {
    const p = pick(rng, platforms);
    if (!p) break;
    const len = ri(rng, 3, 5);
    const x0 = clamp(p.x0 + ri(rng, -2, 2), 8, W - 12 - len);
    const py = p.y - 3;
    if (py < 5) continue;
    let ok = true;
    for (let j = 0; j < len; j++) {
      if (tile(x0 + j, py) !== T_EMPTY || tile(x0 + j, py - 1) !== T_EMPTY || tile(x0 + j, py + 1) !== T_EMPTY) { ok = false; break; }
    }
    if (!ok) continue;
    for (let j = 0; j < len; j++) { setTile(x0 + j, py, T_PLAT); platCells.push({ x: x0 + j, y: py }); }
  }

  // --- выход ---
  const ex = W - 5;
  const egy = groundY[ex];
  setTile(ex, egy - 1, T_EXIT);
  setTile(ex, egy - 2, T_EXIT);
  const exitPx = { x: (ex + 0.5) * TILE, y: (egy - 1) * TILE };

  // --- враги ---
  const hpMul = 1 + 0.25 * (lvl - 1);
  const dmgAdd = 2 * (lvl - 1);
  const enemyList = [];
  const usedX = [];
  // ровная площадка шириной span тайлов без шипов, не занятая другими
  const groundSpot = (span = 1) => {
    for (let tries = 0; tries < 60; tries++) {
      const sx = ri(rng, 14, W - 12 - span);
      let ok = true;
      for (let j = 0; j < span; j++) {
        if (spikeCols.has(sx + j) || groundY[sx + j] !== groundY[sx]) { ok = false; break; }
      }
      if (!ok) continue;
      if (usedX.some((u) => Math.abs(u - sx) < 3)) continue;
      usedX.push(sx);
      return sx;
    }
    return -1;
  };
  const addEnemy = (type, sx, sy) => {
    const b = ENEMY_BASE[type];
    enemyList.push({
      type, x: sx, y: sy, w: b.w, h: b.h,
      hp: Math.round(b.hp * hpMul), maxhp: Math.round(b.hp * hpMul),
      vx: 0, vy: 0, dir: rng() < 0.5 ? -1 : 1,
      spd: b.spd, dmg: b.dmg + dmgAdd, score: b.score,
      fly: !!b.fly, cd: b.cd ? ri(rng, 30, b.cd) : 0, cdMax: b.cd || 0,
      hurtT: 0, phase: rng() * Math.PI * 2,
      onGround: false, hitWall: false, drop: 0,
    });
  };
  const counts = {
    walker: Math.min(4 + lvl, 12),
    shooter: Math.min(1 + Math.floor(lvl * 0.8), 8),
    flyer: lvl >= 2 ? Math.min(1 + lvl, 9) : 0,
    tank: lvl >= 3 ? Math.min(lvl - 2, 5) : 0,
  };
  for (const type in counts) {
    for (let i = 0; i < counts[type]; i++) {
      if (ENEMY_BASE[type].fly) {
        let placed = false;
        for (let tries = 0; tries < 20 && !placed; tries++) {
          const sx = ri(rng, 16, W - 12);
          const sty = Math.max(2, groundY[sx] - ri(rng, 4, 8));
          // место должно быть свободно (учитывая ширину в 2 тайла)
          if (tile(sx, sty) === T_EMPTY && tile(sx + 1, sty) === T_EMPTY
              && tile(sx, sty + 1) === T_EMPTY && tile(sx + 1, sty + 1) === T_EMPTY) {
            addEnemy(type, sx * TILE + 4, sty * TILE + 4);
            placed = true;
          }
        }
      } else {
        const b = ENEMY_BASE[type];
        const span = Math.ceil((b.w + 8) / TILE);
        const sx = groundSpot(span);
        if (sx < 0) continue;
        addEnemy(type, sx * TILE + (span * TILE - b.w) / 2, groundY[sx] * TILE - b.h - 1);
      }
    }
  }

  // --- подбираемое: оружие, аптечки, патроны ---
  const pickupList = [];
  const addPickup = (kind, px, py, extra) => pickupList.push(Object.assign({ kind, x: px, y: py, w: 22, h: 18, vy: 0, t: rng() * 6 }, extra));
  const spotOnPlatOrGround = () => {
    if (platCells.length && rng() < 0.6) {
      const c = pick(rng, platCells);
      return { x: c.x * TILE + 5, y: c.y * TILE - 20 };
    }
    const sx = groundSpot();
    if (sx < 0) return null;
    return { x: sx * TILE + 5, y: groundY[sx] * TILE - 20 };
  };
  const nWeapons = lvl === 1 ? 2 : ri(rng, 1, 2);
  for (let i = 0; i < nWeapons; i++) {
    const s = spotOnPlatOrGround();
    if (s) addPickup('weapon', s.x, s.y, { weapon: pick(rng, WEAPON_DROPS) });
  }
  for (let i = 0, n = ri(rng, 1, 2); i < n; i++) {
    const s = spotOnPlatOrGround();
    if (s) addPickup('med', s.x, s.y, { heal: 30 });
  }
  for (let i = 0, n = ri(rng, 2, 3); i < n; i++) {
    const s = spotOnPlatOrGround();
    if (s) addPickup('ammo', s.x, s.y, {});
  }

  return {
    W, H, grid, groundY,
    theme: THEMES[(lvl - 1) % THEMES.length],
    pxW: W * TILE, pxH: H * TILE,
    spawn: { x: 2 * TILE + 6, y: groundY[2] * TILE - 31 },
    exitPx, enemies: enemyList, pickups: pickupList,
  };
}

function tileAt(tx, ty) {
  if (!level) return T_EMPTY;
  if (tx < 0 || tx >= level.W) return T_SOLID;
  if (ty >= level.H) return T_SOLID;
  if (ty < 0) return T_EMPTY;
  return level.grid[ty * level.W + tx];
}
const solidPx = (px, py) => tileAt(Math.floor(px / TILE), Math.floor(py / TILE)) === T_SOLID;

function lineOfSight(x0, y0, x1, y1) {
  const d = Math.hypot(x1 - x0, y1 - y0);
  const n = Math.max(1, Math.ceil(d / 12));
  for (let i = 1; i < n; i++) {
    const t = i / n;
    if (solidPx(lerp(x0, x1, t), lerp(y0, y1, t))) return false;
  }
  return true;
}

// ============================== Физика ==============================

function collideEntity(e) {
  const prevBottom = e.y + e.h;
  e.hitWall = false;
  e.onGround = false;

  // по X
  e.x += e.vx;
  let y0 = Math.floor(e.y / TILE), y1 = Math.floor((e.y + e.h - 0.01) / TILE);
  if (e.vx > 0) {
    const tx = Math.floor((e.x + e.w - 0.01) / TILE);
    for (let ty = y0; ty <= y1; ty++) {
      if (tileAt(tx, ty) === T_SOLID) { e.x = tx * TILE - e.w; e.vx = 0; e.hitWall = true; break; }
    }
  } else if (e.vx < 0) {
    const tx = Math.floor(e.x / TILE);
    for (let ty = y0; ty <= y1; ty++) {
      if (tileAt(tx, ty) === T_SOLID) { e.x = (tx + 1) * TILE; e.vx = 0; e.hitWall = true; break; }
    }
  }

  // по Y
  e.y += e.vy;
  const x0 = Math.floor(e.x / TILE), x1 = Math.floor((e.x + e.w - 0.01) / TILE);
  if (e.vy > 0) {
    const ty = Math.floor((e.y + e.h - 0.01) / TILE);
    for (let tx = x0; tx <= x1; tx++) {
      const t = tileAt(tx, ty);
      if (t === T_SOLID || (t === T_PLAT && prevBottom <= ty * TILE + 0.5 && e.drop <= 0)) {
        e.y = ty * TILE - e.h;
        e.vy = 0;
        e.onGround = true;
        break;
      }
    }
  } else if (e.vy < 0) {
    const ty = Math.floor(e.y / TILE);
    for (let tx = x0; tx <= x1; tx++) {
      if (tileAt(tx, ty) === T_SOLID) { e.y = (ty + 1) * TILE; e.vy = 0; break; }
    }
  }
}

function overlapsTile(e, type) {
  const x0 = Math.floor(e.x / TILE), x1 = Math.floor((e.x + e.w - 0.01) / TILE);
  const y0 = Math.floor(e.y / TILE), y1 = Math.floor((e.y + e.h - 0.01) / TILE);
  for (let ty = y0; ty <= y1; ty++) {
    for (let tx = x0; tx <= x1; tx++) {
      if (tileAt(tx, ty) === type) return true;
    }
  }
  return false;
}

const aabb = (a, b) => a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y;

function standingOnPlatform(e) {
  const ty = Math.floor((e.y + e.h + 1) / TILE);
  const x0 = Math.floor(e.x / TILE), x1 = Math.floor((e.x + e.w - 0.01) / TILE);
  let plat = false;
  for (let tx = x0; tx <= x1; tx++) {
    const t = tileAt(tx, ty);
    if (t === T_SOLID) return false;
    if (t === T_PLAT) plat = true;
  }
  return plat;
}

// ============================== Запуск забега / уровня ==============================

function startFromMenu() {
  audioInit();
  const raw = (seedInput && typeof seedInput.value === 'string') ? seedInput.value.trim() : '';
  let seed, label;
  if (raw) {
    seed = /^\d{1,10}$/.test(raw) ? (parseInt(raw, 10) >>> 0) : hashSeed(raw);
    label = raw;
  } else {
    seed = (Math.random() * 4294967296) >>> 0;
    label = String(seed);
  }
  startRun(seed, label);
}

function startRun(seed, label) {
  G.runSeed = seed >>> 0;
  G.seedLabel = label || String(seed >>> 0);
  G.level = 1;
  G.score = 0;
  G.kills = 0;
  P = makePlayer();
  startLevel();
  setState('play');
}

function startLevel() {
  const levelSeed = (G.runSeed ^ Math.imul(G.level, 0x9E3779B9)) >>> 0;
  level = generateLevel(levelSeed, G.level);
  enemies = level.enemies;
  pickups = level.pickups;
  bullets = [];
  parts = [];
  texts = [];
  P.x = level.spawn.x;
  P.y = level.spawn.y;
  P.vx = 0; P.vy = 0; P.cd = 0; P.inv = 90; P.drop = 0;
  G.camX = clamp(P.x - VW / 2, 0, level.pxW - VW);
  G.camY = clamp(P.y - VH / 2, 0, level.pxH - VH);
  G.shake = 0;
  G.intro = 150;
  G.introText = `Уровень ${G.level} — ${level.theme.name}`;
  buildBackground(levelSeed);
}

// ============================== Улучшения ==============================

function offerUpgrades() {
  const pool = UPGRADES.filter((u) => !(u.unique && u.id === 'djump' && P.stats.jumps > 1));
  // перемешивание Фишера–Йетса
  for (let i = pool.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [pool[i], pool[j]] = [pool[j], pool[i]];
  }
  G.offer = pool.slice(0, 3);
  cardsEl.innerHTML = '';
  for (const u of G.offer) {
    const card = document.createElement('div');
    card.className = 'card';
    card.innerHTML = `<div class="icon">${u.icon}</div><div class="name">${u.name}</div><div class="desc">${u.desc}</div>`;
    card.addEventListener('click', () => chooseUpgrade(u));
    cardsEl.appendChild(card);
  }
  setState('upgrade');
}

function chooseUpgrade(u) {
  const st = P.stats;
  switch (u.id) {
    case 'hp':    P.maxhp += 25; P.hp = Math.min(P.maxhp, P.hp + 25); break;
    case 'dmg':   st.dmgMul *= 1.15; break;
    case 'rate':  st.cdMul *= 0.88; break;
    case 'speed': st.spdMul *= 1.10; break;
    case 'djump': st.jumps = 2; break;
    case 'steal': st.lifesteal += 3; break;
    case 'armor': st.armorMul *= 0.85; break;
    case 'crit':  st.crit = Math.min(0.6, st.crit + 0.10); break;
    case 'jump':  st.jumpMul *= 1.08; break;
  }
  sfx.select();
  G.level++;
  startLevel();
  setState('play');
}

function levelClear() {
  G.score += 100 + G.level * 25;
  sfx.portal();
  offerUpgrades();
}

// ============================== Урон и смерть ==============================

function hurtPlayer(dmg, fromDir) {
  if (P.inv > 0 || G.state !== 'play') return;
  const real = Math.max(1, Math.round(dmg * P.stats.armorMul));
  P.hp -= real;
  P.inv = 55;
  P.vx = clamp(P.vx + (fromDir || 0) * 4, -8, 8);
  P.vy = Math.min(P.vy, -4);
  G.shake = Math.min(14, G.shake + 7);
  sfx.hurt();
  addText(P.x + P.w / 2, P.y - 6, `-${real}`, '#ff6b5e');
  burst(P.x + P.w / 2, P.y + P.h / 2, 8, '#ff6b5e');
  if (P.hp <= 0) {
    P.hp = 0;
    die();
  }
}

function die() {
  burst(P.x + P.w / 2, P.y + P.h / 2, 30, '#ff6b5e');
  noise(0.4, 0.25, true);
  if (G.score > G.best) {
    G.best = G.score;
    try { localStorage.setItem('gunfall.best', String(G.best)); } catch (e) { /* ок */ }
  }
  deadStatsEl.innerHTML =
    `<div>Очки: <b>${G.score}</b></div>` +
    `<div>Уровень: <b>${G.level}</b> · Убийств: <b>${G.kills}</b></div>` +
    `<div>Сид: <b>${G.seedLabel}</b></div>` +
    `<div>Рекорд: <b>${G.best}</b></div>`;
  setState('dead');
}

function hurtEnemy(en, dmg, crit) {
  en.hp -= dmg;
  en.hurtT = 90;
  addText(en.x + en.w / 2, en.y - 4, String(dmg), crit ? '#ffd86b' : '#ffffff');
  burst(en.x + en.w / 2, en.y + en.h / 2, crit ? 7 : 4, '#ffd1a8');
  sfx.hit();
  if (en.hp <= 0) {
    en.dead = true;
    G.kills++;
    G.score += en.score;
    if (P.stats.lifesteal > 0) P.hp = Math.min(P.maxhp, P.hp + P.stats.lifesteal);
    burst(en.x + en.w / 2, en.y + en.h / 2, 16, '#ff9d6b');
    addText(en.x + en.w / 2, en.y - 14, `+${en.score}`, '#9be8ff');
    sfx.kill();
    dropLoot(en);
  }
}

function dropLoot(en) {
  const r = Math.random();
  const cx = en.x + en.w / 2 - 11, cy = en.y;
  if (r < 0.30) pickups.push({ kind: 'coin', x: cx + 4, y: cy, w: 12, h: 12, vy: -3, t: 0 });
  else if (r < 0.38) pickups.push({ kind: 'med', x: cx, y: cy, w: 22, h: 18, vy: -3, t: 0, heal: 15 });
  else if (r < 0.46) pickups.push({ kind: 'ammo', x: cx, y: cy, w: 22, h: 18, vy: -3, t: 0 });
}

// ============================== Оружие ==============================

function switchWeapon(i) {
  if (i === P.wi || i < 0 || i >= P.weapons.length) return;
  P.wi = i;
  P.cd = Math.max(P.cd, 8);
  sfx.select();
}

function tryShoot() {
  const slot = P.weapons[P.wi];
  const w = WEAPONS[slot.id];
  const want = w.auto ? mouse.down : mouse.clicked;
  if (!want || P.cd > 0) return;
  if (slot.ammo <= 0) {
    addText(P.x + P.w / 2, P.y - 8, 'Нет патронов!', '#ff6b5e');
    G.lowAmmoT = 60;
    switchWeapon(0);
    return;
  }
  if (isFinite(slot.ammo)) slot.ammo--;
  P.cd = Math.max(3, Math.round(w.cd * P.stats.cdMul));
  const cx = P.x + P.w / 2, cy = P.y + P.h / 2 - 2;
  const angle = Math.atan2(mouse.y + G.camY - cy, mouse.x + G.camX - cx);
  P.aim = angle;
  for (let i = 0; i < w.pellets; i++) {
    const a = angle + (Math.random() - 0.5) * 2 * w.spread;
    const crit = Math.random() < P.stats.crit;
    const dmg = Math.max(1, Math.round(w.dmg * P.stats.dmgMul * (crit ? 2 : 1)));
    bullets.push({
      x: cx + Math.cos(a) * 16, y: cy + Math.sin(a) * 16,
      vx: Math.cos(a) * w.spd, vy: Math.sin(a) * w.spd,
      dmg, crit, from: 'p', life: 90, color: w.color,
    });
  }
  P.vx = clamp(P.vx - Math.cos(angle) * w.kick * 0.35, -9, 9);
  G.shake = Math.min(12, G.shake + w.kick * 0.55);
  burst(cx + Math.cos(angle) * 18, cy + Math.sin(angle) * 18, 3, '#fff2b0');
  if (slot.id === 'shotgun') sfx.shotgun();
  else if (slot.id === 'rifle') sfx.rifle();
  else sfx.shoot();
}

function giveWeapon(id) {
  const owned = P.weapons.find((s) => s.id === id);
  if (owned) {
    if (isFinite(owned.ammo)) owned.ammo += WEAPONS[id].ammo;
    addText(P.x + P.w / 2, P.y - 10, `${WEAPONS[id].name}: +патроны`, '#9be8ff');
  } else {
    P.weapons.push({ id, ammo: WEAPONS[id].ammo });
    if (P.weapons.length > 1) P.wi = P.weapons.length - 1;
    addText(P.x + P.w / 2, P.y - 10, WEAPONS[id].name + '!', '#ffd86b');
  }
}

function giveAmmo() {
  // пополняем выбранное оружие, а если это пистолет — первое не-пистолетное
  let slot = P.weapons[P.wi];
  if (!isFinite(slot.ammo)) slot = P.weapons.find((s) => isFinite(s.ammo));
  if (slot) {
    const add = Math.round(WEAPONS[slot.id].ammo * 0.6);
    slot.ammo += add;
    addText(P.x + P.w / 2, P.y - 10, `+${add} патронов`, '#9be8ff');
  } else {
    G.score += 25;
    addText(P.x + P.w / 2, P.y - 10, '+25 очков', '#9be8ff');
  }
}

// ============================== Эффекты ==============================

function burst(x, y, n, color) {
  for (let i = 0; i < n; i++) {
    const a = Math.random() * Math.PI * 2, s = 1 + Math.random() * 3.2;
    parts.push({
      x, y, vx: Math.cos(a) * s, vy: Math.sin(a) * s - 1,
      life: 18 + Math.random() * 22, color, size: 1.5 + Math.random() * 2.5, grav: 0.12,
    });
  }
}

function addText(x, y, str, color) {
  texts.push({ x, y, str, color, life: 55, vy: -0.8 });
}

// ============================== Обновление мира ==============================

function updatePlayer() {
  const st = P.stats;
  const left = keys.KeyA || keys.ArrowLeft, right = keys.KeyD || keys.ArrowRight;
  const down = keys.KeyS || keys.ArrowDown;
  const dir = (right ? 1 : 0) - (left ? 1 : 0);
  const target = dir * 4.3 * st.spdMul;
  const accel = P.onGround ? 0.8 : 0.45;
  P.vx += clamp(target - P.vx, -accel, accel);
  if (Math.abs(P.vx) < 0.05) P.vx = 0;
  P.vy = Math.min(P.vy + GRAV, MAX_FALL);

  if (P.onGround) { P.coyote = 7; P.airJumps = st.jumps - 1; }
  else P.coyote--;

  const jumpPressed = pressed.KeyW || pressed.ArrowUp || pressed.Space;
  const jumpHeld = keys.KeyW || keys.ArrowUp || keys.Space;
  if (jumpPressed) P.buffer = 7; else P.buffer--;

  if (P.buffer > 0) {
    if (down && P.coyote > 0 && standingOnPlatform(P)) {
      P.drop = 12;
      P.vy = Math.max(P.vy, 2);
      P.buffer = 0;
      P.coyote = 0;
    } else if (P.coyote > 0) {
      doJump();
    } else if (P.airJumps > 0) {
      P.airJumps--;
      doJump();
      burst(P.x + P.w / 2, P.y + P.h, 6, '#cfe3ff');
    }
  }
  if (!jumpHeld && P.vy < -4.5) P.vy = -4.5;
  if (P.drop > 0) P.drop--;

  collideEntity(P);

  // прицел и направление взгляда
  P.aim = Math.atan2(mouse.y + G.camY - (P.y + P.h / 2), mouse.x + G.camX - (P.x + P.w / 2));
  P.face = Math.cos(P.aim) >= 0 ? 1 : -1;

  if (P.inv <= 0 && overlapsTile(P, T_SPIKE)) {
    P.vy = -9; // подброс с шипов
    hurtPlayer(15, 0);
  }
  if (overlapsTile(P, T_EXIT)) { levelClear(); return; }

  if (P.inv > 0) P.inv--;
  if (P.cd > 0) P.cd--;
  if (G.lowAmmoT > 0) G.lowAmmoT--;

  // смена оружия с клавиатуры
  for (let i = 0; i < 4; i++) {
    if (pressed['Digit' + (i + 1)] && i < P.weapons.length) switchWeapon(i);
  }

  tryShoot();
}

function doJump() {
  P.vy = -12.2 * P.stats.jumpMul;
  P.coyote = 0;
  P.buffer = 0;
  sfx.jump();
  burst(P.x + P.w / 2, P.y + P.h, 4, '#aab8d8');
}

function updateEnemies() {
  const pcx = P.x + P.w / 2, pcy = P.y + P.h / 2;
  for (const en of enemies) {
    if (en.dead) continue;
    const ecx = en.x + en.w / 2, ecy = en.y + en.h / 2;
    const dist = Math.hypot(pcx - ecx, pcy - ecy);

    if (en.type === 'walker') {
      en.vy = Math.min(en.vy + GRAV, MAX_FALL);
      const sees = dist < 280 && Math.abs(pcy - ecy) < 80 && lineOfSight(ecx, ecy, pcx, pcy);
      if (sees) en.dir = pcx > ecx ? 1 : -1;
      en.vx = en.dir * en.spd * (sees ? 1.7 : 1);
      collideEntity(en);
      if (en.hitWall) en.dir *= -1;
      else if (en.onGround) {
        // разворот на краю и перед шипами
        const aheadX = en.dir > 0 ? en.x + en.w + 2 : en.x - 2;
        const footTx = Math.floor(aheadX / TILE);
        const footTy = Math.floor((en.y + en.h + 4) / TILE);
        const below = tileAt(footTx, footTy);
        const atFeet = tileAt(footTx, footTy - 1);
        if ((below !== T_SOLID && below !== T_PLAT) || atFeet === T_SPIKE) en.dir *= -1;
      }
    } else if (en.type === 'shooter' || en.type === 'tank') {
      en.vy = Math.min(en.vy + GRAV, MAX_FALL);
      en.vx = 0;
      if (en.type === 'tank' && dist < 240 && en.onGround) {
        en.vx = (pcx > ecx ? 1 : -1) * en.spd;
      }
      en.dir = pcx > ecx ? 1 : -1;
      collideEntity(en);
      const range = en.type === 'tank' ? 460 : 420;
      if (dist < range && lineOfSight(ecx, ecy, pcx, pcy)) {
        en.cd--;
        if (en.cd <= 0) {
          en.cd = en.cdMax;
          const baseA = Math.atan2(pcy - ecy, pcx - ecx);
          const pellets = en.type === 'tank' ? 3 : 1;
          const spread = en.type === 'tank' ? 0.16 : 0.06;
          const spd = en.type === 'tank' ? 5.5 : 6.5;
          for (let i = 0; i < pellets; i++) {
            const a = baseA + (pellets > 1 ? (i - (pellets - 1) / 2) * spread : (Math.random() - 0.5) * spread * 2);
            bullets.push({
              x: ecx + Math.cos(a) * (en.w / 2 + 4), y: ecy + Math.sin(a) * (en.w / 2 + 4),
              vx: Math.cos(a) * spd, vy: Math.sin(a) * spd,
              dmg: en.dmg, from: 'e', life: 240, color: '#ff7a6b',
            });
          }
          burst(ecx + en.dir * (en.w / 2 + 6), ecy, 3, '#ffb0a0');
        }
      } else {
        en.cd = Math.max(en.cd, 25);
      }
    } else if (en.type === 'flyer') {
      en.phase += 0.06;
      if (dist < 340 && lineOfSight(ecx, ecy, pcx, pcy)) {
        en.vx += clamp(pcx - ecx, -1, 1) * 0.08;
        en.vy += clamp(pcy - ecy, -1, 1) * 0.08;
      } else {
        en.vx += Math.cos(en.phase) * 0.05;
        en.vy += Math.sin(en.phase * 1.3) * 0.05;
      }
      const sp = Math.hypot(en.vx, en.vy);
      if (sp > en.spd) { en.vx *= en.spd / sp; en.vy *= en.spd / sp; }
      const pvx = en.vx, pvy = en.vy;
      collideEntity(en);
      if (en.vx === 0 && pvx !== 0) en.vx = -pvx * 0.5;
      if (en.vy === 0 && pvy !== 0) en.vy = -pvy * 0.5;
      en.dir = pcx > ecx ? 1 : -1;
    }

    if (en.hurtT > 0) en.hurtT--;

    // контактный урон
    if (P.inv <= 0 && aabb(en, P)) {
      hurtPlayer(en.dmg, P.x + P.w / 2 > ecx ? 1 : -1);
    }
  }
  enemies = enemies.filter((en) => !en.dead);
}

function updateBullets() {
  const alive = [];
  for (const b of bullets) {
    b.life--;
    let hit = b.life <= 0;
    const steps = 2;
    for (let s = 0; s < steps && !hit; s++) {
      b.x += b.vx / steps;
      b.y += b.vy / steps;
      if (solidPx(b.x, b.y)) {
        burst(b.x, b.y, 3, '#cdd6f0');
        hit = true;
        break;
      }
      if (b.from === 'p') {
        for (const en of enemies) {
          if (en.dead) continue;
          if (b.x > en.x - 2 && b.x < en.x + en.w + 2 && b.y > en.y - 2 && b.y < en.y + en.h + 2) {
            hurtEnemy(en, b.dmg, b.crit);
            hit = true;
            break;
          }
        }
      } else if (P.inv <= 0 && G.state === 'play'
          && b.x > P.x - 2 && b.x < P.x + P.w + 2 && b.y > P.y - 2 && b.y < P.y + P.h + 2) {
        hurtPlayer(b.dmg, b.vx > 0 ? 1 : -1);
        hit = true;
      }
      if (b.y < -200 || b.y > level.pxH + 200 || b.x < -200 || b.x > level.pxW + 200) hit = true;
    }
    if (!hit) alive.push(b);
  }
  bullets = alive;
}

function updatePickups() {
  const alive = [];
  for (const pk of pickups) {
    pk.t += 0.08;
    // лёгкая физика: падение до земли
    pk.vy = Math.min(pk.vy + 0.4, 10);
    const ny = pk.y + pk.vy;
    const ty = Math.floor((ny + pk.h) / TILE);
    const tx0 = Math.floor(pk.x / TILE), tx1 = Math.floor((pk.x + pk.w - 0.01) / TILE);
    let landed = false;
    for (let tx = tx0; tx <= tx1; tx++) {
      const t = tileAt(tx, ty);
      if (t === T_SOLID || (t === T_PLAT && pk.y + pk.h <= ty * TILE + 0.5)) { landed = true; break; }
    }
    if (landed) { pk.y = ty * TILE - pk.h; pk.vy = pk.kind === 'coin' ? -pk.vy * 0.4 : 0; if (Math.abs(pk.vy) < 1) pk.vy = 0; }
    else pk.y = ny;

    // магнит для монет
    if (pk.kind === 'coin') {
      const dx = P.x + P.w / 2 - (pk.x + pk.w / 2), dy = P.y + P.h / 2 - (pk.y + pk.h / 2);
      const d = Math.hypot(dx, dy);
      if (d < 90 && d > 1) { pk.x += dx / d * 3.4; pk.y += dy / d * 3.4; }
    }

    if (aabb(pk, P)) {
      if (pk.kind === 'weapon') giveWeapon(pk.weapon);
      else if (pk.kind === 'med') {
        P.hp = Math.min(P.maxhp, P.hp + pk.heal);
        addText(P.x + P.w / 2, P.y - 10, `+${pk.heal} HP`, '#7df2a5');
      } else if (pk.kind === 'ammo') giveAmmo();
      else if (pk.kind === 'coin') { G.score += 5; addText(pk.x, pk.y - 6, '+5', '#ffd86b'); }
      sfx.pickup();
      continue;
    }
    alive.push(pk);
  }
  pickups = alive;
}

function updateEffects() {
  const pa = [];
  for (const p of parts) {
    p.life--;
    if (p.life <= 0) continue;
    p.vy += p.grav;
    p.x += p.vx;
    p.y += p.vy;
    pa.push(p);
  }
  parts = pa;
  const ta = [];
  for (const t of texts) {
    t.life--;
    if (t.life <= 0) continue;
    t.y += t.vy;
    ta.push(t);
  }
  texts = ta;
}

function updateCamera() {
  const tx = clamp(P.x + P.w / 2 - VW / 2 + P.face * 40, 0, Math.max(0, level.pxW - VW));
  const ty = clamp(P.y + P.h / 2 - VH / 2, 0, Math.max(0, level.pxH - VH));
  G.camX = lerp(G.camX, tx, 0.12);
  G.camY = lerp(G.camY, ty, 0.14);
  G.shake *= 0.86;
  if (G.shake < 0.3) G.shake = 0;
}

function clearFrameInput() {
  for (const k in pressed) pressed[k] = false;
  mouse.clicked = false;
}

function step() {
  G.t++;
  if (G.state === 'play') {
    updatePlayer();
    if (G.state === 'play') {
      updateEnemies();
      updateBullets();
      updatePickups();
    }
    updateEffects();
    updateCamera();
    if (G.intro > 0) G.intro--;
  }
  clearFrameInput();
}

// ============================== Фон ==============================

let skyCv = null, hillFarCv = null, hillNearCv = null;

function makeCanvas(w, h) {
  const c = document.createElement('canvas');
  c.width = w;
  c.height = h;
  return c;
}

function buildBackground(seed) {
  const rng = mulberry32((seed ^ 0xBADA55) >>> 0);
  const th = level.theme;

  skyCv = makeCanvas(VW, VH);
  const sc = skyCv.getContext('2d');
  const g = sc.createLinearGradient(0, 0, 0, VH);
  g.addColorStop(0, th.sky0);
  g.addColorStop(1, th.sky1);
  sc.fillStyle = g;
  sc.fillRect(0, 0, VW, VH);
  sc.fillStyle = 'rgba(255,255,255,0.5)';
  for (let i = 0; i < 70; i++) {
    const s = rng() * 1.6 + 0.4;
    sc.globalAlpha = 0.15 + rng() * 0.5;
    sc.fillRect(rng() * VW, rng() * VH * 0.7, s, s);
  }
  sc.globalAlpha = 1;

  const buildHills = (color, baseY, amp) => {
    const c = makeCanvas(1920, 760);
    const hc = c.getContext('2d');
    hc.fillStyle = color;
    hc.beginPath();
    hc.moveTo(0, 760);
    let y = baseY;
    for (let hx = 0; hx <= 1920; hx += 24) {
      y = clamp(y + (rng() - 0.5) * amp, baseY - 90, baseY + 60);
      hc.lineTo(hx, y);
    }
    hc.lineTo(1920, 760);
    hc.closePath();
    hc.fill();
    return c;
  };
  hillFarCv = buildHills(th.hillFar, 330, 26);
  hillNearCv = buildHills(th.hillNear, 420, 34);
}

// ============================== Отрисовка ==============================

function roundRect(x, y, w, h, r) {
  ctx.beginPath();
  if (ctx.roundRect) ctx.roundRect(x, y, w, h, r);
  else ctx.rect(x, y, w, h);
  ctx.fill();
}

function render() {
  ctx.clearRect(0, 0, VW, VH);

  if (!level) {
    ctx.fillStyle = '#0d1020';
    ctx.fillRect(0, 0, VW, VH);
    return;
  }

  const shx = G.shake ? (Math.random() - 0.5) * G.shake : 0;
  const shy = G.shake ? (Math.random() - 0.5) * G.shake : 0;
  const cx = G.camX + shx, cy = G.camY + shy;

  // фон
  ctx.drawImage(skyCv, 0, 0);
  const drawHills = (c, par) => {
    const ox = -((cx * par) % 1920);
    const oy = -cy * 0.12 - 120;
    ctx.drawImage(c, ox, oy);
    ctx.drawImage(c, ox + 1920, oy);
    if (ox > 0) ctx.drawImage(c, ox - 1920, oy);
  };
  drawHills(hillFarCv, 0.25);
  drawHills(hillNearCv, 0.45);

  ctx.save();
  ctx.translate(-cx, -cy);

  drawTiles(cx, cy);
  drawPortal();
  drawPickups();
  drawEnemies();
  drawPlayer();
  drawBullets();
  drawParticles();
  drawTexts();

  ctx.restore();

  drawHUD();
}

function drawTiles(cx, cy) {
  const th = level.theme;
  const x0 = Math.max(0, Math.floor(cx / TILE));
  const x1 = Math.min(level.W - 1, Math.floor((cx + VW) / TILE) + 1);
  const y0 = Math.max(0, Math.floor(cy / TILE));
  const y1 = Math.min(level.H - 1, Math.floor((cy + VH) / TILE) + 1);
  for (let ty = y0; ty <= y1; ty++) {
    for (let tx = x0; tx <= x1; tx++) {
      const t = level.grid[ty * level.W + tx];
      if (t === T_SOLID) {
        const px = tx * TILE, py = ty * TILE;
        ctx.fillStyle = th.ground;
        ctx.fillRect(px, py, TILE, TILE);
        if (((tx * 7 + ty * 13) & 3) === 0) {
          ctx.fillStyle = 'rgba(0,0,0,0.08)';
          ctx.fillRect(px, py, TILE, TILE);
        }
        if (tileAt(tx, ty - 1) !== T_SOLID) {
          ctx.fillStyle = th.top;
          ctx.fillRect(px, py, TILE, 6);
        }
      } else if (t === T_PLAT) {
        ctx.fillStyle = th.plat;
        ctx.fillRect(tx * TILE, ty * TILE, TILE, 8);
        ctx.fillStyle = 'rgba(0,0,0,0.25)';
        ctx.fillRect(tx * TILE, ty * TILE + 6, TILE, 2);
      } else if (t === T_SPIKE) {
        const px = tx * TILE, py = ty * TILE;
        ctx.fillStyle = th.spike;
        ctx.beginPath();
        ctx.moveTo(px, py + TILE);
        ctx.lineTo(px + 8, py + 6);
        ctx.lineTo(px + 16, py + TILE);
        ctx.lineTo(px + 24, py + 6);
        ctx.lineTo(px + TILE, py + TILE);
        ctx.closePath();
        ctx.fill();
      }
    }
  }
}

function drawPortal() {
  const e = level.exitPx;
  const cxp = e.x, cyp = e.y + TILE / 2;
  const pulse = 1 + Math.sin(G.t * 0.07) * 0.12;
  const grad = ctx.createRadialGradient(cxp, cyp, 4, cxp, cyp, 46 * pulse);
  grad.addColorStop(0, 'rgba(155,232,255,0.9)');
  grad.addColorStop(0.5, 'rgba(120,160,255,0.35)');
  grad.addColorStop(1, 'rgba(120,160,255,0)');
  ctx.fillStyle = grad;
  ctx.fillRect(cxp - 50, cyp - 60, 100, 120);
  ctx.strokeStyle = 'rgba(200,240,255,0.85)';
  ctx.lineWidth = 3;
  ctx.beginPath();
  ctx.ellipse(cxp, cyp, 13 * pulse, 26 * pulse, 0, 0, Math.PI * 2);
  ctx.stroke();
  ctx.strokeStyle = 'rgba(140,190,255,0.5)';
  ctx.beginPath();
  ctx.ellipse(cxp, cyp, 18 * pulse, 32 * pulse, 0, 0, Math.PI * 2);
  ctx.stroke();
}

function drawPickups() {
  for (const pk of pickups) {
    const bob = Math.sin(pk.t * 2) * 2.5;
    const x = pk.x, y = pk.y + bob;
    if (pk.kind === 'weapon') {
      const w = WEAPONS[pk.weapon];
      ctx.fillStyle = 'rgba(255,255,255,0.10)';
      roundRect(x - 3, y - 3, pk.w + 6, pk.h + 6, 5);
      ctx.fillStyle = '#1e2740';
      roundRect(x, y, pk.w, pk.h, 4);
      ctx.fillStyle = w.color;
      ctx.fillRect(x + 4, y + pk.h / 2 - 2, pk.w - 8, 4);
      ctx.fillRect(x + pk.w - 10, y + pk.h / 2, 3, 6);
    } else if (pk.kind === 'med') {
      ctx.fillStyle = '#f2f5ff';
      roundRect(x, y, pk.w, pk.h, 4);
      ctx.fillStyle = '#ff5e57';
      ctx.fillRect(x + pk.w / 2 - 2, y + 4, 4, pk.h - 8);
      ctx.fillRect(x + 5, y + pk.h / 2 - 2, pk.w - 10, 4);
    } else if (pk.kind === 'ammo') {
      ctx.fillStyle = '#caa64a';
      roundRect(x, y, pk.w, pk.h, 3);
      ctx.fillStyle = '#8a6f2c';
      ctx.fillRect(x, y + 5, pk.w, 3);
    } else if (pk.kind === 'coin') {
      ctx.fillStyle = '#ffd86b';
      ctx.beginPath();
      ctx.arc(x + 6, y + 6, 6, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = '#b88f2e';
      ctx.beginPath();
      ctx.arc(x + 6, y + 6, 3, 0, Math.PI * 2);
      ctx.fill();
    }
  }
}

function drawEnemies() {
  for (const en of enemies) {
    const flash = en.hurtT > 84;
    if (en.type === 'walker') {
      ctx.fillStyle = flash ? '#ffffff' : '#e2554f';
      roundRect(en.x, en.y, en.w, en.h, 6);
      ctx.fillStyle = '#2a0f0e';
      const ex = en.x + en.w / 2 + en.dir * 5;
      ctx.fillRect(ex - 3, en.y + 8, 3, 5);
      ctx.fillRect(ex + 2, en.y + 8, 3, 5);
    } else if (en.type === 'shooter') {
      ctx.fillStyle = flash ? '#ffffff' : '#b06ee8';
      roundRect(en.x, en.y, en.w, en.h, 5);
      ctx.fillStyle = '#34204a';
      ctx.fillRect(en.x + en.w / 2 - 2 + en.dir * 4, en.y + 9, 5, 5);
      ctx.fillStyle = flash ? '#ffffff' : '#7a4aa8';
      ctx.fillRect(en.x + en.w / 2 + (en.dir > 0 ? 4 : -4 - 12), en.y + en.h / 2 - 2, 12, 4);
    } else if (en.type === 'flyer') {
      const flap = Math.sin(G.t * 0.3 + en.phase) * 5;
      ctx.fillStyle = flash ? '#ffffff' : '#5fb0e8';
      ctx.beginPath();
      ctx.ellipse(en.x + en.w / 2, en.y + en.h / 2, en.w / 2, en.h / 2, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = flash ? '#ffffff' : '#3d7eb0';
      ctx.beginPath();
      ctx.moveTo(en.x + 2, en.y + en.h / 2);
      ctx.lineTo(en.x - 7, en.y + en.h / 2 - 6 + flap);
      ctx.lineTo(en.x + 4, en.y + en.h / 2 + 4);
      ctx.closePath();
      ctx.fill();
      ctx.beginPath();
      ctx.moveTo(en.x + en.w - 2, en.y + en.h / 2);
      ctx.lineTo(en.x + en.w + 7, en.y + en.h / 2 - 6 + flap);
      ctx.lineTo(en.x + en.w - 4, en.y + en.h / 2 + 4);
      ctx.closePath();
      ctx.fill();
      ctx.fillStyle = '#10243a';
      ctx.fillRect(en.x + en.w / 2 + en.dir * 4 - 2, en.y + en.h / 2 - 3, 4, 4);
    } else if (en.type === 'tank') {
      ctx.fillStyle = flash ? '#ffffff' : '#c8893a';
      roundRect(en.x, en.y + 8, en.w, en.h - 8, 6);
      ctx.fillStyle = flash ? '#ffffff' : '#9c6a28';
      ctx.beginPath();
      ctx.arc(en.x + en.w / 2, en.y + 12, en.w / 2 - 4, Math.PI, 0);
      ctx.fill();
      ctx.fillStyle = '#3a2810';
      ctx.fillRect(en.x + en.w / 2 + (en.dir > 0 ? 6 : -6 - 16), en.y + en.h / 2, 16, 5);
      ctx.fillRect(en.x + en.w / 2 + en.dir * 6 - 3, en.y + 14, 6, 5);
    }

    if (en.hurtT > 0 && en.hp < en.maxhp) {
      const bw = en.w + 8;
      ctx.fillStyle = 'rgba(0,0,0,0.55)';
      ctx.fillRect(en.x - 4, en.y - 9, bw, 4);
      ctx.fillStyle = '#ff5e57';
      ctx.fillRect(en.x - 4, en.y - 9, bw * clamp(en.hp / en.maxhp, 0, 1), 4);
    }
  }
}

function drawPlayer() {
  if (G.state === 'dead') return;
  if (P.inv > 0 && (G.t & 4)) return; // мигание при неуязвимости

  // тело
  ctx.fillStyle = '#3ec6a8';
  roundRect(P.x, P.y + 4, P.w, P.h - 4, 5);
  ctx.fillStyle = '#2c917b';
  roundRect(P.x, P.y + P.h - 7, P.w, 7, 3);
  // голова/визор
  ctx.fillStyle = '#e9f4ff';
  ctx.fillRect(P.x + (P.face > 0 ? 8 : 2), P.y + 8, 10, 5);
  ctx.fillStyle = '#1c3a4a';
  ctx.fillRect(P.x + (P.face > 0 ? 13 : 3), P.y + 9, 4, 3);

  // оружие, повёрнутое к прицелу
  const w = WEAPONS[P.weapons[P.wi].id];
  const gx = P.x + P.w / 2, gy = P.y + P.h / 2 - 2;
  ctx.save();
  ctx.translate(gx, gy);
  ctx.rotate(P.aim);
  ctx.fillStyle = '#222b3d';
  ctx.fillRect(2, -3, w.len, 6);
  ctx.fillStyle = w.color;
  ctx.fillRect(w.len - 3, -2, 4, 4);
  ctx.restore();
}

function drawBullets() {
  for (const b of bullets) {
    ctx.strokeStyle = b.color;
    ctx.lineWidth = b.crit ? 3.5 : 2.5;
    ctx.beginPath();
    ctx.moveTo(b.x - b.vx * 1.4, b.y - b.vy * 1.4);
    ctx.lineTo(b.x, b.y);
    ctx.stroke();
  }
}

function drawParticles() {
  for (const p of parts) {
    ctx.globalAlpha = clamp(p.life / 24, 0, 1);
    ctx.fillStyle = p.color;
    ctx.fillRect(p.x - p.size / 2, p.y - p.size / 2, p.size, p.size);
  }
  ctx.globalAlpha = 1;
}

function drawTexts() {
  ctx.font = 'bold 13px "Segoe UI", sans-serif';
  ctx.textAlign = 'center';
  for (const t of texts) {
    ctx.globalAlpha = clamp(t.life / 30, 0, 1);
    ctx.fillStyle = 'rgba(0,0,0,0.6)';
    ctx.fillText(t.str, t.x + 1, t.y + 1);
    ctx.fillStyle = t.color;
    ctx.fillText(t.str, t.x, t.y);
  }
  ctx.globalAlpha = 1;
  ctx.textAlign = 'left';
}

function drawHUD() {
  // здоровье
  const hpw = 190;
  ctx.fillStyle = 'rgba(0,0,0,0.45)';
  roundRect(12, 12, hpw + 4, 20, 6);
  const frac = clamp(P.hp / P.maxhp, 0, 1);
  ctx.fillStyle = frac > 0.35 ? '#56d98b' : (G.t % 30 < 15 ? '#ff5e57' : '#c93a34');
  roundRect(14, 14, hpw * frac, 16, 5);
  ctx.fillStyle = '#eaf0ff';
  ctx.font = 'bold 12px "Segoe UI", sans-serif';
  ctx.fillText(`${Math.ceil(P.hp)} / ${P.maxhp}`, 20, 27);

  // уровень и тема — сверху по центру
  ctx.textAlign = 'center';
  ctx.font = 'bold 14px "Segoe UI", sans-serif';
  ctx.fillStyle = 'rgba(0,0,0,0.5)';
  ctx.fillText(`Уровень ${G.level} · ${level.theme.name}`, VW / 2 + 1, 25);
  ctx.fillStyle = '#dfe5ff';
  ctx.fillText(`Уровень ${G.level} · ${level.theme.name}`, VW / 2, 24);

  // очки — справа
  ctx.textAlign = 'right';
  ctx.font = 'bold 16px "Segoe UI", sans-serif';
  ctx.fillStyle = '#ffd86b';
  ctx.fillText(`${G.score}`, VW - 16, 26);
  ctx.font = '11px "Segoe UI", sans-serif';
  ctx.fillStyle = '#8d97bd';
  ctx.fillText(`убийств: ${G.kills} · сид: ${G.seedLabel}`, VW - 16, 42);
  ctx.textAlign = 'left';

  // оружие — снизу слева
  const slot = P.weapons[P.wi];
  const w = WEAPONS[slot.id];
  ctx.fillStyle = 'rgba(0,0,0,0.45)';
  roundRect(12, VH - 46, 210, 34, 8);
  ctx.fillStyle = w.color;
  ctx.fillRect(22, VH - 32, 18, 6);
  ctx.fillStyle = '#eaf0ff';
  ctx.font = 'bold 13px "Segoe UI", sans-serif';
  const ammoStr = isFinite(slot.ammo) ? String(slot.ammo) : '∞';
  ctx.fillStyle = (G.lowAmmoT > 0 || (isFinite(slot.ammo) && slot.ammo <= 5)) ? '#ff5e57' : '#eaf0ff';
  ctx.fillText(`${w.name} · ${ammoStr}`, 50, VH - 24);
  // слоты
  for (let i = 0; i < P.weapons.length; i++) {
    const sx = 232 + i * 26;
    ctx.fillStyle = i === P.wi ? 'rgba(255,216,107,0.85)' : 'rgba(255,255,255,0.15)';
    roundRect(sx, VH - 42, 22, 22, 5);
    ctx.fillStyle = i === P.wi ? '#2a1c04' : '#cfd6f5';
    ctx.font = 'bold 12px "Segoe UI", sans-serif';
    ctx.fillText(String(i + 1), sx + 7, VH - 27);
  }

  // интро уровня
  if (G.intro > 0) {
    const a = clamp(G.intro > 120 ? (150 - G.intro) / 30 : G.intro / 60, 0, 1);
    ctx.globalAlpha = a;
    ctx.textAlign = 'center';
    ctx.font = 'bold 30px "Segoe UI", sans-serif';
    ctx.fillStyle = 'rgba(0,0,0,0.6)';
    ctx.fillText(G.introText, VW / 2 + 2, VH / 2 - 58);
    ctx.fillStyle = '#ffe9b0';
    ctx.fillText(G.introText, VW / 2, VH / 2 - 60);
    ctx.font = '15px "Segoe UI", sans-serif';
    ctx.fillStyle = '#aab3d6';
    ctx.fillText('Доберитесь до портала →', VW / 2, VH / 2 - 30);
    ctx.globalAlpha = 1;
    ctx.textAlign = 'left';
  }

  // прицел
  if (G.state === 'play') {
    ctx.strokeStyle = 'rgba(255,255,255,0.9)';
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.arc(mouse.x, mouse.y, 7, 0, Math.PI * 2);
    ctx.stroke();
    ctx.fillStyle = 'rgba(255,255,255,0.9)';
    ctx.fillRect(mouse.x - 1, mouse.y - 1, 2, 2);
  }
}

// ============================== Цикл ==============================

let last = performance.now(), acc = 0;
const STEP_MS = 1000 / 60;

function frame(now) {
  requestAnimationFrame(frame);
  let dt = now - last;
  last = now;
  if (dt > 100) dt = 100;
  acc += dt;
  let n = 0;
  while (acc >= STEP_MS && n < 5) {
    step();
    acc -= STEP_MS;
    n++;
  }
  if (n === 5) acc = 0;
  render();
}

// ============================== Кнопки меню ==============================

document.getElementById('playBtn').addEventListener('click', startFromMenu);
document.getElementById('retryBtn').addEventListener('click', startFromMenu);
document.getElementById('menuBtn').addEventListener('click', () => setState('menu'));
document.getElementById('resumeBtn').addEventListener('click', () => setState('play'));
document.getElementById('quitBtn').addEventListener('click', () => setState('menu'));

updateBestLine();
requestAnimationFrame(frame);

// Хуки для автотестов (в браузере не используются)
window.__test = {
  generateLevel, startRun, step, G,
  player: () => P,
  levelRef: () => level,
  enemiesRef: () => enemies,
  keys, mouse, pressed,
  hurtPlayer, chooseUpgrade,
  pickOffer: (i) => chooseUpgrade(G.offer[i]),
  teleport: (x, y) => { P.x = x; P.y = y; },
};

})();
