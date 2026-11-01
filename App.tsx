import React, { useEffect, useRef, useState } from 'react';
import { Platform, Pressable, ScrollView, StyleSheet, Text, View, useWindowDimensions } from 'react-native';
import * as Haptics from 'expo-haptics';
import { RobotBody, SKINS, FREE_SKINS } from './skins';
import { createRoom, joinRoom, onlineAvailable, rng, MAX, type Room, type Msg } from './online';

type Kind = 'gear' | 'oil' | 'battery' | 'coat' | 'igloo' | 'ans';
type Obj = { id: number; x: number; kind: Kind; y: number; taken?: boolean; live?: boolean; dyn?: boolean; label?: string; color?: string; ok?: boolean; q?: number };
type WorldId = 'fabrica' | 'gelo' | 'deserto' | 'doces' | 'cidade' | 'vulcao' | 'matematica' | 'portugues' | 'cores' | 'espaco';
type World = { emoji: string; name: string; sky: string; deco: string[]; ground: string; top: string; belt: string; a: string; b: string; puddle?: string; roll?: boolean; hills?: boolean; cars?: boolean; ice?: boolean; lava?: boolean; space?: boolean; quiz?: 'math' | 'pt' | 'cor'; tip: string };
const WORLDS: Record<WorldId, World> = {
  fabrica: { emoji: '🏭', name: 'Fábrica', sky: '#FFE8A3', deco: ['#8ECAE6', '#A0C4FF', '#BDB2FF', '#9BF6FF'], ground: '#6C757D', top: '#FB8500', belt: '▸ ▸ ▸ ▸ ▸ ▸ ▸ ▸ ▸ ▸ ▸ ▸', a: '⚙️', b: '', puddle: '#1D3557', roll: true, tip: 'Pule as engrenagens e o óleo!' },
  gelo: { emoji: '❄️', name: 'Gelo', sky: '#DFF6FF', deco: ['#FFFFFF', '#CAF0F8', '#ADE8F4', '#E9F5FF'], ground: '#BDE0FE', top: '#FFFFFF', belt: '❄  ❄  ❄  ❄  ❄  ❄  ❄  ❄', a: '⚪', b: '🧊', roll: true, ice: true, tip: 'Pule bolas de neve e gelo. Na ❄️ Tempestade, use a 🧣 roupinha ou entre no iglu!' },
  deserto: { emoji: '🏜️', name: 'Deserto', sky: '#FFE5B4', deco: ['#F4A261', '#E9C46A', '#F6BD60', '#E76F51'], ground: '#E9C46A', top: '#F4A261', belt: '', a: '🌵', b: '🪨', hills: true, tip: 'Suba e desça as dunas pulando cactos e pedras!' },
  doces: { emoji: '🍭', name: 'Doces', sky: '#FFE5EC', deco: ['#FFC8DD', '#BDE0FE', '#CDB4DB', '#FFAFCC'], ground: '#CDB4DB', top: '#FF8FAB', belt: '🍬    🍬    🍬    🍬    🍬', a: '🍩', b: '', puddle: '#FF4D8D', roll: true, tip: 'Pule as rosquinhas e a calda grudenta!' },
  cidade: { emoji: '🏙️', name: 'Cidade', sky: '#CAF0F8', deco: ['#ADB5BD', '#90E0EF', '#FFD6A5', '#CDB4DB'], ground: '#495057', top: '#ADB5BD', belt: '—   —   —   —   —   —   —', a: '🚗', b: '🚕', cars: true, tip: 'Pule os carrinhos que vêm na rua!' },
  vulcao: { emoji: '🌋', name: 'Vulcão', sky: '#FFE0C2', deco: ['#D4A373', '#CCD5AE', '#E9EDC9', '#FAEDCD'], ground: '#7F5539', top: '#FF9F1C', belt: '·  ·  ·  ·  ·  ·  ·  ·  ·', a: '', b: '', puddle: '#FF7B00', lava: true, tip: 'O vulcão solta bolinhas de lava que quicam: pule na hora certa!' },
  matematica: { emoji: '🔢', name: 'Matemática', sky: '#E7F5FF', deco: ['#A5D8FF', '#FFD8A8', '#B2F2BB', '#FFC9C9'], ground: '#4C6EF5', top: '#FFD43B', belt: '1  2  3  4  5  6  7  8  9', a: '➕', b: '📏', roll: true, quiz: 'math', tip: 'Resolva a conta: pule na bolha certa (em cima) ou passe por baixo para turbo!' },
  portugues: { emoji: '🔤', name: 'Português', sky: '#FFF9DB', deco: ['#FFEC99', '#D0BFFF', '#A5D8FF', '#FFC9C9'], ground: '#AE3EC9', top: '#FFD43B', belt: 'A  E  I  O  U  A  E  I  O', a: '📚', b: '✏️', quiz: 'pt', tip: 'Complete a palavra com a letra certa para ganhar turbo!' },
  cores: { emoji: '🎨', name: 'Cores', sky: '#F8F0FC', deco: ['#FF8787', '#FFD43B', '#69DB7C', '#74C0FC'], ground: '#495057', top: '#F06595', belt: '●  ●  ●  ●  ●  ●  ●  ●', a: '🎨', b: '', puddle: '#F06595', roll: true, quiz: 'cor', tip: 'Pule na bolha da cor pedida para ganhar turbo!' },
  espaco: { emoji: '🚀', name: 'Espaço', sky: '#14213D', deco: [], ground: '', top: '', belt: '', a: '', b: '', space: true, tip: 'Suba até a Lua! Toque à esquerda ou à direita para pular de asteroide em asteroide.' },
};
const WORLD_IDS = Object.keys(WORLDS) as WorldId[];
const hill = (w: World, wx: number) => w.hills ? 55 + 35 * Math.sin(wx / 260) + 15 * Math.sin(wx / 97) : 0;
const pickKind = (r: number, w: World): Kind => w.ice ? (r < 0.35 ? 'gear' : r < 0.6 ? 'oil' : 'battery') : (r < 0.35 ? 'gear' : r < 0.6 ? 'oil' : 'battery');
type Mode = 'story' | 'skins' | 'menu' | 'play' | 'over' | 'podium' | 'lobby' | 'count';
const PCOL = ['#4CC9F0', '#FF006E', '#8338EC', '#06D6A0'];
const PNAME = ['Azul', 'Rosa', 'Roxo', 'Verde'];
// Apelidos só de uma lista pronta (sem texto livre = sem nomes reais/dados pessoais).
const NICKS = ['Raio', 'Foguete', 'Turbo', 'Faísca', 'Pipoca', 'Trovão', 'Cometa', 'Bolinha', 'Pulinho', 'Parafuso', 'Estrela', 'Biscoito'];
type Other = { dd?: number; dy?: number; v?: number; lt?: number; d: number; y: number; fin?: number; gone?: boolean; seen?: number; k?: number; z?: boolean; c?: boolean; g?: boolean; sp?: boolean };
function makeTrack(seed: number, w: World) {
  const r = rng(seed); const out: { wx: number; kind: Kind; y: number }[] = [];
  for (let wx = 700; wx < 6600; wx += 230 + r() * 300) { const kind = pickKind(r(), w); out.push({ wx, kind, y: kind === 'battery' ? (r() < 0.5 ? 20 : 130) : 0 }); if (kind === 'igloo') wx += 80; }
  return out;
}
const WORDS = ['GATO', 'BOLA', 'CASA', 'PATO', 'SAPO', 'LUA', 'SOL', 'UVA', 'MALA', 'FOCA', 'BOLO', 'DADO', 'PIPA', 'SUCO', 'MESA', 'VACA'];
const COLS: [string, string][] = [['AZUL', '#339AF0'], ['VERMELHO', '#FA5252'], ['AMARELO', '#FCC419'], ['VERDE', '#40C057'], ['ROXO', '#9775FA'], ['LARANJA', '#FD7E14'], ['ROSA', '#F783AC']];
// Desafio de quiz (mesmo resultado em todos os celulares, pois vem da semente da corrida)
function makeQuiz(kind: 'math' | 'pt' | 'cor', seed: number) {
  const r = rng(seed); const hiOk = r() < 0.5;
  if (kind === 'math') { const a = 1 + Math.floor(r() * 5), b = 1 + Math.floor(r() * 5); const ok = a + b; let bad = ok + (r() < 0.5 ? -1 : 1) * (1 + Math.floor(r() * 2)); if (bad < 0) bad = ok + 2; return { prompt: `${a} + ${b} = ?`, ok: String(ok), bad: String(bad), hiOk }; }
  if (kind === 'pt') { const w = WORDS[Math.floor(r() * WORDS.length)]; const idx = [...w].findIndex(c => 'AEIOU'.includes(c)); const ok = w[idx]; const others = 'AEIOU'.replace(ok, ''); const bad = others[Math.floor(r() * others.length)]; return { prompt: `Complete: ${w.slice(0, idx)}_${w.slice(idx + 1)}`, ok, bad, hiOk }; }
  const a = Math.floor(r() * COLS.length); let b = Math.floor(r() * (COLS.length - 1)); if (b >= a) b++;
  return { prompt: `Pule no ${COLS[a][0]}!`, ok: COLS[a][1], bad: COLS[b][1], hiOk };
}
const ROWS = 40, ROWD = 7000 / ROWS, ROWH = 120;
// Espaço: cada fileira tem 3 pistas. Sempre há caminho: ou 1 pista vazia (sem meteoro) ou 3 asteroides com 1 meteoro sonolento.
function spaceRow(seed: number, row: number, diff = 1): string[] {
  if (row <= 0) return ['p', 'p', 'p'];
  if (row >= ROWS) return ['p', 'p', 'p'];
  const r = rng(seed + row * 7919); const a = ['p', 'p', 'p'];
  if (r() < 0.25 + diff * 0.06) a[Math.floor(r() * 3)] = 'm'; else a[Math.floor(r() * 3)] = '_';
  if (r() < 0.28) { const o = [0, 1, 2].filter(i => a[i] === 'p'); a[o[Math.floor(r() * o.length)]] = 'b'; }
  return a;
}
const stormPlan = (seed: number) => { const r = rng(seed ^ 0x5eed); return { first: 7 + r() * 2, period: 9 + r() * 2 }; };
type Rival = { skin?: number; row?: number; lane?: number; hopT?: number; name: string; color: string; d: number; v: number; frozen?: number; slow?: number; cd?: number };
type Proj = { d: number; from: string; to: string; life: number };
type Puddle = { wx: number; owner: string; hit: string[] };
const POWER_CD = 8;
const FINISH = 7000;
const SPACE_PHASES = ['Big Bang', 'Terra', 'Júpiter', 'Buraco Negro', 'Lua'];
const PHASES = ['Começo', 'Aquecendo', 'Desafio', 'Turbo', 'Chefão'];
const newRivals = (): Rival[] => [
  { name: 'Bipo', color: '#FF006E', d: 0, v: 250 + Math.random() * 25 },
  { name: 'Zuca', color: '#8338EC', d: 0, v: 240 + Math.random() * 25 },
  { name: 'Tiko', color: '#06D6A0', d: 0, v: 230 + Math.random() * 25 },
];

const GROUND = 120, ROBOT = 56, GRAV = 2600, JUMP = 980;
const BEST_KEY = 'robo-corredor-best';

const store = {
  get(): number { try { return Number((globalThis as any).localStorage?.getItem(BEST_KEY)) || 0; } catch { return 0; } },
  set(v: number) { try { (globalThis as any).localStorage?.setItem(BEST_KEY, String(v)); } catch {} },
};

let ctx: any = null;
function beep(freq: number, dur = 0.12, type = 'square') {
  if (Platform.OS !== 'web') return;
  try {
    const AC = (window as any).AudioContext || (window as any).webkitAudioContext;
    if (!AC) return;
    ctx = ctx || new AC();
    const o = ctx.createOscillator(), g = ctx.createGain();
    o.type = type; o.frequency.setValueAtTime(freq, ctx.currentTime);
    o.frequency.exponentialRampToValueAtTime(freq * 1.5, ctx.currentTime + dur);
    g.gain.setValueAtTime(0.15, ctx.currentTime); g.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + dur);
    o.connect(g); g.connect(ctx.destination); o.start(); o.stop(ctx.currentTime + dur);
  } catch {}
}
function buzz(ms = 20) {
  if (Platform.OS === 'web') { try { (navigator as any).vibrate?.(ms); } catch {} }
  else Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light).catch(() => {});
}

const CONF_COLORS = ['#FF006E', '#FB5607', '#FFBE0B', '#06D6A0', '#3A86FF', '#8338EC'];
const PIECES = Array.from({ length: 36 }, (_, i) => ({ x: (i * 37) % 100, delay: (i * 0.13) % 1.6, speed: 0.6 + ((i * 7) % 5) / 10, size: 8 + (i % 3) * 4, c: CONF_COLORS[i % 6], spin: i % 2 ? 1 : -1 }));
// Lightweight confetti: 36 small views, one timer.
function Confetti({ h }: { h: number }) {
  const [t, setT] = useState(0);
  useEffect(() => { const t0 = Date.now(); const iv = setInterval(() => setT((Date.now() - t0) / 1000), 40); const stop = setTimeout(() => clearInterval(iv), 6000); return () => { clearInterval(iv); clearTimeout(stop); }; }, []);
  return (
    <View style={StyleSheet.absoluteFill as any} pointerEvents="none" testID="confetti">
      {PIECES.map((p, i) => { const k = Math.max(0, t - p.delay); const y = -20 + k * p.speed * h * 0.45; if (y > h + 20) return null; return (
        <View key={i} style={{ position: 'absolute', left: `${p.x + Math.sin(k * 3 + i) * 3}%` as any, top: y, width: p.size, height: p.size * 0.6, backgroundColor: p.c, borderRadius: 2, transform: [{ rotate: `${k * 360 * p.spin}deg` }] }} />); })}
    </View>);
}

export default function App() {
  const { width, height } = useWindowDimensions();
  const [mode, setMode] = useState<Mode>('menu');
  const loadJ = (k: string, d: any) => { try { const v = (globalThis as any).localStorage?.getItem(k); return v ? JSON.parse(v) : d; } catch { return d; } };
  const saveJ = (k: string, v: any) => { try { (globalThis as any).localStorage?.setItem(k, JSON.stringify(v)); } catch {} };
  const [done, setDone] = useState<number[]>(() => loadJ('robo-corredor-story', []));
  const [mySkin, setMySkinS] = useState<number>(() => loadJ('robo-corredor-skin', 0));
  const setMySkin = (k: number) => { setMySkinS(k); saveJ('robo-corredor-skin', k); };
  const [story, setStory] = useState<null | { w: WorldId; n: number }>(null);
  const [storyMsg, setStoryMsg] = useState('');
  const [skinInfo, setSkinInfo] = useState('');
  const [world, setWorldS] = useState<WorldId>('fabrica');
  const worldRef = useRef<WorldId>('fabrica'); worldRef.current = world;
  const setWorld = (w: WorldId) => { worldRef.current = w; setWorldS(w); };
  const [muted, setMuted] = useState(false);
  const [best, setBest] = useState(0);
  const [, force] = useState(0);
  const fresh = (race: boolean, seed = Math.floor(Math.random() * 1e9)) => ({ w: worldRef.current, seed, coat: false, frozen: 0, storm: 0, stormAt: stormPlan(seed).first, period: stormPlan(seed).period, y: 0, vy: 0, objs: [] as Obj[], score: 0, speed: 260, dist: 0, next: 1.2, id: 0, t: 0, race, slow: 0, boost: 0, rivals: newRivals().map((r, k) => ({ ...r, cd: 5 + k * 2.5 })), place: 0, projs: [] as Proj[], puddles: [] as Puddle[], cd: 2, online: false, me: 0, ids: [0] as number[], others: {} as Record<number, Other>, track: [] as ReturnType<typeof makeTrack>, myTime: 0, sendT: 0, sp: { row: 0, lane: 1, hop: 0, tl: 1, fail: false }, gotB: {} as Record<string, boolean>, diff: 2, spTheme: 0, quizAt: 3.5, quizN: 0, quiz: '', quizRes: '', prepScarf: -1, shelter: 0, prepIgloo: -1, note: '', finT: {} as Record<number, number>, pod: null as null | { order: number[]; gone: number[] } });
  // Single source of truth for the online podium: the host (or, if the host left, each phone locally) ranks by race time, ties by player number.
  const rankFrom = (s: ReturnType<typeof fresh>) => ({ order: Object.entries(s.finT).map(([i, t]) => [Number(i), t] as const).sort((a, b) => a[1] - b[1] || a[0] - b[0]).map(x => x[0]), gone: Object.entries(s.others).filter(([i, o]) => o.gone && s.finT[Number(i)] === undefined).map(([i]) => Number(i)) });
  const publish = () => { const s = g.current; if (!s.online) return; const isHost = roomRef.current?.isHost; if (!isHost && roomRef.current) return; s.pod = rankFrom(s); if (isHost) roomRef.current?.send({ t: 'podium', order: s.pod.order, gone: s.pod.gone }); force(n => n + 1); };
  const g = useRef(fresh(false));
  const roomRef = useRef<Room | null>(null);
  const [nick, setNick] = useState(() => NICKS[Math.floor(Math.random() * NICKS.length)]);
  const nickRef = useRef(nick); nickRef.current = nick;
  const nicksRef = useRef<Record<number, string>>({});
  const nameOf = (i: number) => nicksRef.current[i] ?? PNAME[i];
  const okNick = (n: any) => typeof n === 'string' && NICKS.includes(n);
  const [lv, setLv] = useState<{ view: 'choose' | 'join' | 'room' | 'wait'; code: string; err: string; ids: number[] }>({ view: 'choose', code: '', err: '', ids: [] });
  const [count, setCount] = useState(3);
  const leaveRoom = () => { roomRef.current?.close(); roomRef.current = null; };
  const beginOnline = (seed: number, ids: number[], me: number, w: WorldId) => {
    setWorld(w); const n = fresh(true, seed); n.rivals = []; n.online = true; n.me = me; n.ids = ids;
    n.track = makeTrack(seed, WORLDS[w]); n.objs = n.track.map((t, i) => ({ id: i, x: 9999, kind: t.kind, y: t.y }));
    ids.filter(i => i !== me).forEach(i => { n.others[i] = { d: 0, y: 0, seen: Date.now() + 4000 }; });
    g.current = n; setCount(3); setMode('count');
    [1, 2, 3].forEach(k => setTimeout(() => { setCount(3 - k); sfx(k === 3 ? 880 : 440, 0.15); }, k * 1000));
    setTimeout(() => setMode('play'), 3000);
  };
  const onMsg = (m: Msg) => {
    const s = g.current;
    if (m.t === 'nick') { if (okNick(m.n) && m.i >= 0 && m.i < 4) { nicksRef.current = { ...nicksRef.current, [m.i]: m.n }; if (roomRef.current?.isHost) roomRef.current.send({ t: 'nicks', map: nicksRef.current }); force(n => n + 1); } return; }
    if (m.t === 'nicks') { const c: Record<number, string> = {}; for (const [k, v] of Object.entries(m.map || {})) if (okNick(v)) c[Number(k)] = v as string; nicksRef.current = c; force(n => n + 1); return; }
    if (m.t === 'lobby') { setLv(v => ({ ...v, ids: m.ids })); if (roomRef.current?.isHost) { const keep: Record<number, string> = {}; m.ids.forEach(i => { if (nicksRef.current[i]) keep[i] = nicksRef.current[i]; }); nicksRef.current = keep; roomRef.current.send({ t: 'world', w: worldRef.current }); roomRef.current.send({ t: 'nicks', map: keep }); } }
    else if (m.t === 'world') { if (WORLDS[m.w as WorldId]) setWorld(m.w as WorldId); }
    else if (m.t === 'start') beginOnline(m.seed, m.ids, roomRef.current?.me ?? 0, (WORLDS[m.w as WorldId] ? m.w : 'fabrica') as WorldId);
    else if (s.online && m.t === 'pw' && s.others[m.i]) {
      const from = 'p' + m.i;
      if (m.k === 'rocket') s.projs.push({ d: m.at + 30, from, to: m.to < 0 ? '' : keyFor(m.to), life: 1.5 });
      else s.puddles.push({ wx: m.at, owner: from, hit: [] });
    }
    else if (s.online && m.t === 's' && s.others[m.i]) { const o = s.others[m.i]; const now = Date.now(); if (o.lt) { const dtm = (now - o.lt) / 1000; if (dtm > 0.01) o.v = Math.max(0, Math.min(500, (m.d - o.d) / dtm)); } o.lt = now; o.d = m.d; o.y = m.y; o.k = typeof m.k === 'number' && m.k >= 0 && m.k < SKINS.length ? m.k : 0; o.z = m.z; o.c = m.c; o.g = m.g; o.sp = m.sp; o.seen = Date.now(); }
    else if (s.online && m.t === 'fin' && s.others[m.i]) { s.others[m.i].fin = m.time; s.finT[m.i] = m.time; publish(); }
    else if (s.online && m.t === 'podium' && !roomRef.current?.isHost) { s.pod = { order: m.order, gone: m.gone }; force(n => n + 1); }
    else if (m.t === 'left') { if (s.online && s.others[m.i]) { s.others[m.i].gone = true; s.note = `${nameOf(m.i)} saiu`; publish(); } }
  };
  const onClose = () => {
    const s = g.current;
    if (s.online) { Object.values(s.others).forEach(o => { o.gone = true; }); s.note = 'A sala fechou. Continue correndo!'; roomRef.current = null; publish(); force(n => n + 1); return; }
    else setLv({ view: 'choose', code: '', err: 'A sala fechou.', ids: [] });
    roomRef.current = null;
  };
  const errText = (e: any) => e === 'full' ? 'Essa sala está cheia ou já começou.' : e === 'peer-unavailable' || e === 'timeout' ? 'Sala não encontrada. Confira o número.' : 'Sem conexão. Tente de novo.';
  const hostRoom = async () => { setLv({ view: 'wait', code: '', err: '', ids: [] }); try { const r = await createRoom({ onMsg, onClose }); roomRef.current = r; nicksRef.current = { 0: nickRef.current }; setLv({ view: 'room', code: r.code, err: '', ids: [0] }); } catch (e) { setLv({ view: 'choose', code: '', err: errText(e), ids: [] }); } };
  const join = async (code: string) => { setLv(v => ({ ...v, view: 'wait', err: '' })); try { const r = await joinRoom(code, { onMsg, onClose }); roomRef.current = r; r.send({ t: 'nick', i: r.me, n: nickRef.current }); setLv(v => ({ view: 'room', code, err: '', ids: v.ids.length ? v.ids : [0, r.me] })); } catch (e) { setLv({ view: 'join', code: '', err: errText(e), ids: [] }); } };
  const hostStart = () => { const r = roomRef.current; if (!r?.isHost) return; const ids = r.ids(); if (ids.length < 2) return; r.lock(); const seed = Math.floor(Math.random() * 1e9); r.send({ t: 'start', seed, ids, w: worldRef.current }); beginOnline(seed, ids, 0, worldRef.current); };
  useEffect(() => {
    const iv = setInterval(() => {
      const s = g.current; if (!s.online) return;
      if (mode === 'podium') roomRef.current?.send({ t: 's', i: s.me, k: mySkin, d: s.dist, y: 0 });
      let ch = false;
      for (const [k, o] of Object.entries(s.others)) if (!o.gone && o.fin === undefined && Date.now() - (o.seen ?? 0) > 6000) { o.gone = true; s.note = `${nameOf(Number(k))} saiu`; ch = true; }
      if (ch) publish();
    }, 700);
    const bye = () => roomRef.current?.close();
    if (Platform.OS === 'web') window.addEventListener('pagehide', bye);
    return () => { clearInterval(iv); if (Platform.OS === 'web') window.removeEventListener('pagehide', bye); };
  }, [mode]);
  const tapRef = useRef<(e?: any) => void>(() => {});
  useEffect(() => { // web: toque direto no documento (mais confiável que o Pressable com 60 quadros/s)
    if (Platform.OS !== 'web') return;
    const h = (ev: PointerEvent) => { const t = ev.target as HTMLElement | null; if (!t?.closest?.('[data-testid=game-area]') || t.closest('[data-testid^=ui-]')) return; tapRef.current({ nativeEvent: { locationX: ev.clientX } }); };
    document.addEventListener('pointerdown', h); return () => document.removeEventListener('pointerdown', h);
  }, []);
  if (Platform.OS === 'web' && typeof window !== 'undefined') (window as any).__nodex = g; // para testes automatizados
  const mutedRef = useRef(false); mutedRef.current = muted;
  const sfx = (f: number, d?: number, t?: string) => { if (!mutedRef.current) beep(f, d, t); };

  useEffect(() => {
    setBest(store.get());
    if (Platform.OS === 'web' && typeof document !== 'undefined') {
      document.title = 'Nodex: Robô Corredor';
      document.documentElement.lang = 'pt-BR';
      const add = (rel: string, href: string) => { const l = document.createElement('link'); l.rel = rel; l.href = href; document.head.appendChild(l); };
      add('manifest', '/manifest.webmanifest'); add('apple-touch-icon', '/apple-touch-icon.png');
      const m = document.createElement('meta'); m.name = 'theme-color'; m.content = '#FFB703'; document.head.appendChild(m);
      if ('serviceWorker' in navigator) navigator.serviceWorker.register('/sw.js').catch(() => {});
    }
  }, []);

  useEffect(() => {
    if (mode !== 'play') return;
    let raf = 0, last = 0;
    const loop = (ts: number) => {
      const dt = last ? Math.min((ts - last) / 1000, 0.05) : 0; last = ts;
      const s = g.current; s.t += dt; const W = WORLDS[s.w];
      s.frozen = Math.max(0, s.frozen - dt); s.shelter = Math.max(0, s.shelter - dt); s.storm = Math.max(0, s.storm - dt);
      if (W.ice && s.t >= s.stormAt) {
        s.stormAt += s.period; s.storm = 1.5;
        const inIgloo = s.objs.some(o => o.kind === 'igloo' && o.x < 60 + ROBOT - 6 && o.x + 90 > 60 + 6);
        if (inIgloo) { s.shelter = 1.6; sfx(700, 0.2, 'triangle'); } else if (s.coat) { s.coat = false; sfx(600, 0.2, 'triangle'); } else { s.frozen = 1.5; s.slow = 0; sfx(300, 0.4, 'sine'); buzz(80); }
        for (const r of s.rivals) r.frozen = Math.random() < 0.55 ? 1.5 : 0;
      }
      if (W.quiz && s.t >= s.quizAt) {
        const q = makeQuiz(W.quiz, s.seed + s.quizN * 7919); s.quizN++; s.quizAt += 6.5;
        s.quiz = q.prompt; s.quizRes = '';
        const x = width + 40; const mk = (ok: boolean, hi: boolean) => ({ id: 200000 + s.id++, x, kind: 'ans' as Kind, y: hi ? 150 : 8, dyn: true, ok, q: s.quizN, label: W.quiz === 'cor' ? '' : ok ? q.ok : q.bad, color: W.quiz === 'cor' ? (ok ? q.ok : q.bad) : '#FFFFFF' });
        s.objs = s.objs.filter(o => o.x < x - 140 || o.x > x + 140 || o.kind === 'battery');
        s.objs.push(mk(true, q.hiOk), mk(false, !q.hiOk));
      }
      if (W.ice && mode === 'play') { // antes de cada tempestade: sempre uma roupinha e um iglu no caminho
        const left = s.stormAt - s.t;
        if (left < 4.5 && s.prepScarf !== s.stormAt) { s.prepScarf = s.stormAt; s.objs.push({ id: 100000 + s.id++, x: width + 30, kind: 'coat', y: 0, dyn: true }); }
        if (left < 1.4 && s.prepIgloo !== s.stormAt) { s.prepIgloo = s.stormAt; s.objs = s.objs.filter(o => !(o.kind !== 'battery' && o.kind !== 'coat' && o.x > 0 && o.x < 60 + s.speed * 1.6 + 120)); s.objs.push({ id: 100000 + s.id++, x: 60 - 25 + Math.max(s.speed, 150) * left, kind: 'igloo', y: 0, dyn: true }); }
      }
      let target: number;
      if (s.race) {
        s.slow = Math.max(0, s.slow - dt); s.boost = Math.max(0, s.boost - dt);
        target = 285 * (s.slow > 0 ? 0.5 : 1) * (s.boost > 0 ? 1.35 : 1);
        s.cd = Math.max(0, s.cd - dt);
        s.rivals.forEach((r, k) => { r.frozen = Math.max(0, (r.frozen ?? 0) - dt); r.slow = Math.max(0, (r.slow ?? 0) - dt); if (!r.frozen && !W.space) r.d += (r.v + Math.sin(s.t * 1.3 + r.v) * 40) * (r.slow ? 0.5 : 1) * dt;
          r.cd = (r.cd ?? 6) - dt; if (r.cd <= 0) { r.cd = 7 + Math.random() * 6; const me = 'r' + k; const tgt = ahead(s, me); if (tgt && Math.random() < 0.6) s.projs.push({ d: r.d + 30, from: me, to: tgt, life: 1.5 }); else s.puddles.push({ wx: r.d - 10, owner: me, hit: [] }); } });
        for (const pj of s.projs) { pj.life -= dt; if (!pj.to) continue; pj.d += 900 * dt; if (pj.d >= posOf(s, pj.to)) { hitKey(s, pj.to); pj.life = 0; } }
        s.projs = s.projs.filter(pj => pj.life > 0);
        for (const pd of s.puddles) for (const k of racers(s)) { if (k === pd.owner || pd.hit.includes(k) || k[0] === 'p') continue; const d = posOf(s, k); if (d + ROBOT > pd.wx + 20 && d < pd.wx + 40 && !(k === 'me' && s.y > 10)) { pd.hit.push(k); hitKey(s, k); } }
        s.puddles = s.puddles.filter(pd => pd.wx > s.dist - 600);
      } else target = 260 + s.t * 6;
      if (s.frozen > 0) s.speed = 0;
      else if (W.ice) s.speed += (target - s.speed) * Math.min(1, dt * 1.5); // escorrega no gelo
      else s.speed = target;
      if (W.space) { if (spaceStep(s, dt) === 'over') { const b = Math.max(store.get(), s.score); store.set(b); setBest(b); setMode('over'); force(n => n + 1); return; } } else s.dist += s.speed * dt;
      if (s.online) for (const o of Object.values(s.others)) { // suaviza: prevê com a velocidade e aproxima devagar
        if (o.fin === undefined) o.d += (o.v ?? 0) * dt;
        o.dd = o.dd === undefined ? o.d : o.dd + (o.d - o.dd) * Math.min(1, dt * 8);
        o.dy = W.space ? o.y : o.y <= 1 ? 0 : o.dy === undefined ? o.y : o.dy + (o.y - o.dy) * Math.min(1, dt * 15);
      }
      if (s.online) {
        s.sendT -= dt; if (s.sendT <= 0) { s.sendT = 0.066; roomRef.current?.send({ t: 's', i: s.me, k: mySkin, d: s.dist, y: W.space ? s.sp.lane : s.y, z: s.frozen > 0, c: s.coat, g: s.shelter > 0, sp: s.slow > 0 }); }
        if (s.dist >= FINISH) { s.myTime = s.t; s.finT[s.me] = s.t; roomRef.current?.send({ t: 'fin', i: s.me, time: s.t }); publish(); sfx(660, 0.15, 'triangle'); setTimeout(() => sfx(990, 0.3, 'triangle'), 160); buzz(60); setMode('podium'); force(n => n + 1); return; }
      }
      if (s.race && !s.online && s.dist >= FINISH) {
        s.place = 1 + s.rivals.filter(r => r.d >= s.dist).length;
        storyFinish(s.place);
        sfx(660, 0.15, 'triangle'); setTimeout(() => sfx(990, 0.3, 'triangle'), 160); buzz(60);
        setMode('podium'); force(n => n + 1); return;
      }
      if (W.space) { force(n => n + 1); raf = requestAnimationFrame(loop); return; }
      s.vy -= GRAV * dt; s.y = Math.max(0, s.y + s.vy * dt); if (s.y === 0) s.vy = 0;
      s.next -= dt;
      if (s.online) s.next = 99;
      if (s.next <= 0) {
        const kind = pickKind(Math.random(), W);
        s.objs.push({ id: s.id++, x: width + 40, kind, y: kind === 'battery' ? (Math.random() < 0.5 ? 20 : 130) : 0 });
        s.next = (0.7 + Math.random() * 0.9) * (1.2 - 0.06 * s.diff) - Math.min(s.t / 120, 0.3);
      }
      const rx = 60;
      for (const o of s.objs) {
        const car = W.cars && (o.kind === 'gear' || o.kind === 'oil');
        if (s.online && !o.live && !o.dyn) { o.x = 60 + s.track[o.id].wx - s.dist; if (car && o.x < width) o.live = true; }
        else o.x -= (s.speed + (car ? 130 : 0)) * dt;
        const w = o.kind === 'oil' ? 60 : o.kind === 'igloo' ? 90 : 40;
        const overlapX = o.x < rx + ROBOT - 10 && o.x + w > rx + 10;
        if (!overlapX || o.taken) continue;
        if (o.kind === 'igloo') continue;
        if (o.kind === 'ans') { // decide pela altura do robô ao chegar na bolha
          const hi = s.y > 70; if ((o.y > 70) !== hi) continue;
          for (const z of s.objs) if (z.kind === 'ans' && z.q === o.q) z.taken = true;
          if (o.ok) { s.boost = 2.2; s.score += 2; s.quizRes = 'Acertou! Turbo! 🚀'; sfx(1046, 0.2, 'triangle'); setTimeout(() => sfx(1318, 0.25, 'triangle'), 150); }
          else { s.quizRes = 'Ops! Na próxima você acerta 😊'; sfx(330, 0.2, 'sine'); }
          continue;
        }
        if (W.lava && o.kind === 'gear') { const by = Math.abs(Math.sin(s.t * 3.2 + o.id)) * 70; if (!(s.y < by + 32 && s.y + ROBOT > by + 4)) continue; }
        if (o.kind === 'coat') { if (s.y < 60) { o.taken = true; s.coat = true; sfx(1000, 0.15, 'triangle'); } continue; }
        if (o.kind === 'battery') {
          if (s.y + ROBOT > o.y && s.y < o.y + 40) { o.taken = true; s.score++; s.boost = 1.2; sfx(880, 0.1, 'triangle'); }
        } else if (W.lava && o.kind === 'gear' || s.y < (o.kind === 'oil' && !W.cars ? 10 : 34)) {
          sfx(200, 0.3, 'sine'); buzz(120);
          if (s.race) { o.taken = true; s.slow = 1; continue; }
          const b = Math.max(store.get(), s.score); store.set(b); setBest(b);
          setMode('over'); force(n => n + 1); return;
        }
      }
      s.objs = s.objs.filter(o => o.x > -120 && !((o.kind === 'battery' || o.kind === 'coat' || o.kind === 'ans') && o.taken));
      if (s.quiz && !s.objs.some(o => o.kind === 'ans')) s.quiz = '';
      if (s.race && s.dist > FINISH - 400) s.next = 99;
      force(n => n + 1);
      raf = requestAnimationFrame(loop);
    };
    raf = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(raf);
  }, [mode, width]);

  const storyRef = useRef(story); storyRef.current = story;
  const gidx = (w: WorldId, n: number) => WORLD_IDS.indexOf(w) * 5 + n - 1;
  const skinOpen = (k: number, d = done) => k < FREE_SKINS || (k === SKINS.length - 1 ? d.length >= WORLD_IDS.length * 5 : d.includes(k - FREE_SKINS));
  const lockText = (k: number) => { if (k === SKINS.length - 1) return 'complete todas as 50 fases do Modo História! ✨'; const gi = k - FREE_SKINS; const w = WORLD_IDS[Math.floor(gi / 5)]; const n = gi % 5 + 1; return `ganhe na Fase ${n} (${(WORLDS[w].space ? SPACE_PHASES : PHASES)[n - 1]}) de ${WORLDS[w].emoji} ${WORLDS[w].name}`; };
  const phaseOpen = (w: WorldId, n: number) => n === 1 || done.includes(gidx(w, n - 1));
  const storyFinish = (place: number) => {
    const st = storyRef.current; if (!st) return;
    if (place > 3) { setStoryMsg('Quase! Chegue entre os 3 primeiros para passar de fase.'); return; }
    const gi = gidx(st.w, st.n);
    setDone(prev => {
      if (prev.includes(gi)) { setStoryMsg('Fase completa! ⭐'); return prev; }
      const nd = [...prev, gi]; saveJ('robo-corredor-story', nd);
      const newSkin = SKINS.findIndex((_, k) => skinOpen(k, nd) && !skinOpen(k, prev));
      setStoryMsg('Fase completa! ⭐' + (newSkin >= 0 ? ` Nova skin: ${SKINS[newSkin].name}! 🎁` : ''));
      return nd;
    });
  };
  const start = (race = g.current.race, st: null | { w: WorldId; n: number } = null) => {
    setStory(st); storyRef.current = st; setStoryMsg('');
    if (st) setWorld(st.w);
    const n = fresh(race);
    if (st) { n.w = st.w; n.diff = st.n; n.spTheme = st.n - 1; n.rivals.forEach(r => { r.v *= 0.86 + 0.05 * st.n; }); }
    n.rivals.forEach((r, k) => { r.skin = (k * 2 + 1 + Math.floor(Math.random() * 3)) % FREE_SKINS; });
    g.current = n; sfx(520); buzz(); setMode('play');
  };
  // ---- Poderes: foguetinho de confete (gira e freia quem está à frente) e poça de óleo (freia quem vem atrás)
  const posOf = (s: ReturnType<typeof fresh>, key: string) => key === 'me' ? s.dist : key[0] === 'r' ? s.rivals[Number(key.slice(1))]?.d ?? 0 : (s.others[Number(key.slice(1))]?.dd ?? s.others[Number(key.slice(1))]?.d ?? 0);
  const racers = (s: ReturnType<typeof fresh>) => [...(s.online ? Object.entries(s.others).filter(([, o]) => !o.gone && o.fin === undefined).map(([i]) => 'p' + i) : s.rivals.map((_, k) => 'r' + k)), 'me'];
  const ahead = (s: ReturnType<typeof fresh>, from: string) => { const d0 = posOf(s, from); let best = '', bd = 1e9; for (const k of racers(s)) { if (k === from) continue; const dd = posOf(s, k) - d0; if (dd > 0 && dd < 900 && dd < bd) { bd = dd; best = k; } } return best; };
  const keyFor = (pi: number) => pi === g.current.me ? 'me' : 'p' + pi;
  const usePower = (k: 'rocket' | 'oil') => {
    const s = g.current; if (!s.race || mode !== 'play' || s.cd > 0) return;
    s.cd = POWER_CD; buzz(30);
    if (k === 'rocket') { const tgt = ahead(s, 'me'); s.projs.push({ d: s.dist + 30, from: 'me', to: tgt, life: 1.5 }); sfx(900, 0.25, 'triangle');
      if (s.online) roomRef.current?.send({ t: 'pw', i: s.me, k, to: tgt[0] === 'p' ? Number(tgt.slice(1)) : -1, at: s.dist }); }
    else { s.puddles.push({ wx: s.dist - 10, owner: 'me', hit: [] }); sfx(220, 0.2, 'sine');
      if (s.online) roomRef.current?.send({ t: 'pw', i: s.me, k, to: -1, at: s.dist - 10 }); }
    force(n => n + 1);
  };
  const hitKey = (s: ReturnType<typeof fresh>, key: string) => {
    if (key === 'me') { s.slow = 1; sfx(200, 0.3, 'sine'); buzz(80); }
    else if (key[0] === 'r') { const r = s.rivals[Number(key.slice(1))]; if (r) r.slow = 1; }
  };
  const spaceStep = (s: ReturnType<typeof fresh>, dt: number): 'over' | void => {
    const sp = s.sp;
    if (sp.hop > 0) {
      const dur = (s.boost > 0 ? 0.28 : 0.42) * (s.slow > 0 ? 1.7 : 1);
      sp.hop += dt / dur;
      if (sp.hop >= 1) {
        const cell = spaceRow(s.seed, sp.row + 1, s.diff)[sp.tl];
        sp.hop = 0;
        if (cell === '_') { sfx(250, 0.25, 'sine'); buzz(60); if (!s.race) return 'over'; s.slow = 0.5; }
        else {
          sp.row++; sp.lane = sp.tl;
          if (cell === 'm') { s.slow = 1; sfx(200, 0.3, 'sine'); buzz(80); }
          if (cell === 'b' && !s.gotB[sp.row + ':' + sp.lane]) { s.gotB[sp.row + ':' + sp.lane] = true; s.score++; s.boost = 2; sfx(880, 0.1, 'triangle'); }
          if (!s.race && cell === 'm') return 'over';
        }
      }
    }
    s.dist = (sp.row + (sp.hop > 0 && spaceRow(s.seed, sp.row + 1, s.diff)[sp.tl] !== '_' ? sp.hop : 0)) * ROWD;
    s.rivals.forEach(r => {
      r.row = r.row ?? 0; r.lane = r.lane ?? 1; r.hopT = (r.hopT ?? 0.6) - dt;
      if (r.hopT <= 0 && !r.slow && !r.frozen) {
        const next = spaceRow(s.seed, r.row + 1, s.diff); const opts = [Math.max(0, r.lane - 1), Math.min(2, r.lane + 1)];
        const good = opts.filter(l => next[l] === 'p' || next[l] === 'b'); const pick = good.length && Math.random() < 0.82 ? good[Math.floor(Math.random() * good.length)] : opts[Math.floor(Math.random() * 2)];
        if (next[pick] === '_') r.hopT = 0.9; else { r.row++; r.lane = pick; if (next[pick] === 'm') r.slow = 1; r.hopT = 0.5 + Math.random() * 0.3 + (r.v < 245 ? 0.08 : 0); }
      }
      r.d = r.row * ROWD;
    });
  };
  const tap = (e?: any) => {
    if (mode !== 'play') return;
    const s = g.current; buzz(15);
    if (WORLDS[s.w].space) {
      if (s.sp.hop > 0 || s.frozen > 0) return;
      const lx = e?.nativeEvent?.locationX ?? e?.nativeEvent?.pageX ?? width;
      const dir = lx < width / 2 ? -1 : 1;
      s.sp.tl = Math.max(0, Math.min(2, s.sp.lane + dir)); s.sp.hop = 0.0001; sfx(520, 0.1); return;
    }
    if (s.y === 0 && s.frozen <= 0) { s.vy = JUMP; sfx(440, 0.12); }
  };

  tapRef.current = tap;
  const s = g.current;
  const place = s.online && s.pod?.order.includes(s.me) ? s.pod.order.indexOf(s.me) + 1 : s.online ? 1 + Object.values(s.others).filter(o => !o.gone && (o.fin !== undefined || o.d > s.dist)).length : 1 + s.rivals.filter(r => r.d > s.dist).length;
  const Picker = ({ off }: { off?: boolean }) => (
    <View style={{ flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'center', marginBottom: 12 }}>
      {WORLD_IDS.map(id => (
        <Pressable key={id} disabled={off} accessibilityLabel={'mundo ' + WORLDS[id].name} onPress={() => { setWorld(id); g.current = { ...g.current, w: id }; roomRef.current?.isHost && roomRef.current.send({ t: 'world', w: id }); buzz(10); }}
          style={[st.wbtn, world === id && st.wbtnOn, off && world !== id && { opacity: 0.35 }]}>
          <Text style={{ fontSize: 34 }}>{WORLDS[id].emoji}</Text>
        </Pressable>))}
      <Text style={st.wname}>{WORLDS[world].emoji} {WORLDS[world].name}</Text>
    </View>);
  const ord = ['1º', '2º', '3º', '4º'];
  const gearRot = `${(s.t * 360) % 360}deg`;
  const W = WORLDS[s.w];
  const gy = (wx: number) => GROUND + hill(W, wx);
  const Extras = ({ z, c, g: ig }: { z?: boolean; c?: boolean; g?: boolean }) => (<>{c && <Text style={st.scarf}>🧣</Text>}{ig && <View style={st.iglooBadge} testID="igloo-badge"><View style={st.iglooBadgeDoor} /></View>}{z && <View style={st.iceCube}><Text style={{ fontSize: 14 }}>❄️</Text></View>}</>);
  const warn = W.ice && mode === 'play' && s.stormAt - s.t < 2 && s.stormAt - s.t > 0;
  return (
    <View style={[st.root, { backgroundColor: W.sky }]}>
      <Pressable style={StyleSheet.absoluteFill} onPressIn={Platform.OS === 'web' ? undefined : tap} testID="game-area" accessibilityLabel="Toque para o Nodex pular">
        {W.space ? (() => {
          const camRow = s.sp.row + (s.sp.hop > 0 ? s.sp.hop : 0); const base = 230;
          const yOf = (rf: number) => base + (rf - camRow) * ROWH;
          const lx = (l: number) => width * (0.2 + 0.3 * l);
          const r0 = Math.max(0, Math.floor(camRow) - 2), r1 = Math.min(ROWS, Math.ceil(camRow) + 7);
          const bot = (key: string, x: number, y: number, color: string, label: string, spin: boolean, sc = 1, skinOf = 0) => (
            <View key={key} style={[st.robot, { left: x - ROBOT / 2, bottom: y, transform: [{ scale: sc }, { rotate: spin ? `${(s.t * 720) % 360}deg` : '0deg' }] }]}>
              <RobotBody color={color} skin={skinOf} t={s.t} />{!!label && <Text style={[st.tag, { color: '#fff' }]}>{label}</Text>}
            </View>);
          const theme = ['#14213D', '#0B3D91', '#5E3023', '#240046', '#1B263B'][s.spTheme ?? 0];
          const myLane = s.sp.lane + (s.sp.tl - s.sp.lane) * Math.min(1, s.sp.hop);
          return (
            <View style={[st.sky, { backgroundColor: theme }]} pointerEvents="none">
              {Array.from({ length: 40 }, (_, k) => <View key={'st' + k} style={{ position: 'absolute', left: (k * 97) % width, top: ((k * 53 + camRow * 12) % 900), width: 3, height: 3, borderRadius: 2, backgroundColor: '#fff', opacity: 0.7 }} />)}
              {(s.spTheme ?? 0) === 2 && <View style={{ position: 'absolute', right: -60, top: 120, width: 200, height: 200, borderRadius: 100, backgroundColor: '#E9C46A', opacity: 0.6 }} />}
              {(s.spTheme ?? 0) === 3 && <View style={{ position: 'absolute', left: width / 2 - 70, top: 90, width: 140, height: 140, borderRadius: 70, backgroundColor: '#000', borderWidth: 8, borderColor: '#9D4EDD' }} />}
              {(s.spTheme ?? 0) === 1 && <Text style={{ position: 'absolute', right: 20, top: 120, fontSize: 90 }}>🌍</Text>}
              {s.race && yOf(ROWS) < 1200 && <Text style={{ position: 'absolute', left: width / 2 - 70, bottom: yOf(ROWS) + 10, fontSize: 130 }}>🌕</Text>}
              {Array.from({ length: Math.max(0, r1 - r0 + 1) }, (_, k) => r0 + k).map(row => spaceRow(s.seed, row, s.diff).map((c, l) => c === '_' ? null : (
                <View key={row + '-' + l} style={{ position: 'absolute', left: lx(l) - 48, bottom: yOf(row), width: 96, height: 24, borderRadius: 12, backgroundColor: c === 'm' ? '#6C757D' : '#ADB5BD', borderWidth: 3, borderColor: '#DEE2E6' }}>
                  {c === 'm' && <Text style={{ position: 'absolute', left: 30, top: -34, fontSize: 30 }}>☄️</Text>}
                  {c === 'b' && !s.gotB[row + ':' + l] && <Text style={{ position: 'absolute', left: 32, top: -38, fontSize: 30 }}>🔋</Text>}
                </View>)))}
              {s.race && s.rivals.map((r, k) => { const y = yOf(r.row ?? 0) + 17; return y < -80 || y > 1000 ? null : bot('r' + k, lx(r.lane ?? 1) + (k - 1) * 14, y, r.color, r.name, (r.slow ?? 0) > 0, 0.75, r.skin ?? 0); })}
              {s.online && Object.entries(s.others).map(([k, o]) => { if (o.gone) return null; const i = Number(k); const y = yOf((o.dd ?? o.d) / ROWD) + 18; return y < -80 || y > 1000 ? null : bot('p' + i, lx(o.y ?? 1) + (i - s.me) * 12, y, PCOL[i], nameOf(i), !!o.sp, 0.8, o.k ?? 0); })}
              {bot('me', lx(myLane), yOf(s.sp.row) + 22 + Math.sin(Math.PI * Math.min(1, s.sp.hop)) * (spaceRow(s.seed, s.sp.row + 1, s.diff)[s.sp.tl] === '_' ? 60 : 140) * (s.sp.hop > 0 ? 1 : 0), PCOL[s.online ? s.me : 0], s.online ? 'Você' : '', s.slow > 0, 1, mySkin)}
              <Text style={st.spaceHint} pointerEvents="none">◀ toque aqui        toque aqui ▶</Text>
            </View>);
        })() : (
        <View style={[st.sky, { backgroundColor: W.sky }]}>
          {W.lava && (<>
            <View style={[st.volcano, { left: width - 260, bottom: GROUND }]} />
            <View style={[st.crater, { left: width - 160, bottom: GROUND + 210 }]} />
            {[0, 1, 2].map(k => { const ph = (s.t * 0.7 + k / 3) % 1; return <View key={'lb' + k} style={[st.lava, { width: 22, height: 22, left: width - 140 + (k - 1) * 60 * ph, bottom: GROUND + 220 + Math.sin(ph * Math.PI) * 120 }]} />; })}
          </>)}
          {[0, 1, 2, 3].map(i => (
            <View key={i} style={[st.machine, { left: ((i * 160 - s.t * 40) % (width + 160) + width + 160) % (width + 160) - 120, height: (W.cars ? 160 : 90) + (i % 2) * 60 + (W.hills ? 60 : 0), backgroundColor: W.deco[i], borderRadius: W.ice || W.hills ? 60 : undefined }]} />
          ))}
          {W.hills ? Array.from({ length: Math.ceil(width / 10) + 1 }, (_, k) => (
            <View key={'h' + k} style={{ position: 'absolute', left: k * 10, bottom: 0, width: 11, height: gy(s.dist + k * 10 - 60), backgroundColor: W.ground, borderTopWidth: 8, borderTopColor: W.top }} />
          )) : (
            <View style={[st.belt, { height: GROUND, backgroundColor: W.ground, borderTopColor: W.top }]}>
              <Text style={[st.beltText, W.cars && { color: '#FFD60A' }]}>{W.belt}</Text>
            </View>)}
          {s.objs.map(o => { if (o.x > width + 100) return null; const b = gy(s.dist + o.x - 60); return o.kind === 'oil' ? (
            W.puddle ? <View key={o.id} style={[st.oil, { left: o.x, bottom: b - 6, backgroundColor: W.puddle }]} />
              : <Text key={o.id} style={[st.gear, { left: o.x, bottom: b - 4, fontSize: W.cars ? 44 : 30 }]}>{W.b}</Text>
          ) : o.kind === 'gear' && W.lava ? (
            <View key={o.id} style={[st.lava, { left: o.x, bottom: b + Math.abs(Math.sin(s.t * 3.2 + o.id)) * 70 }]}><View style={st.lavaEye} /><View style={st.lavaEye} /></View>
          ) : o.kind === 'ans' ? (
            <View key={o.id} style={[st.bubble, { left: o.x - 4, bottom: b + o.y, backgroundColor: o.color }]}><Text style={st.bubbleText}>{o.label}</Text></View>
          ) : o.kind === 'gear' ? (
            <Text key={o.id} style={[st.gear, { left: o.x, bottom: b - 4, fontSize: W.cars ? 44 : 40, transform: W.roll ? [{ rotate: `-${gearRot}` }] : [] }]}>{W.a}</Text>
          ) : o.kind === 'coat' ? (
            <Text key={o.id} style={[st.battery, { left: o.x, bottom: b + 30 }]}>🧣</Text>
          ) : o.kind === 'igloo' ? (
            <View key={o.id} style={[st.igloo, { left: o.x, bottom: b - 2 }]}><View style={st.iglooDoor} /></View>
          ) : (
            <Text key={o.id} style={[st.battery, { left: o.x, bottom: b + o.y }]}>🔋</Text>
          ); })}
          {s.race && s.puddles.map((pd, k) => { const x = 60 + pd.wx - s.dist; return x > -80 && x < width + 40 ? <View key={'pd' + k} style={[st.oil, { left: x, bottom: gy(pd.wx) - 6, backgroundColor: '#3D348B' }]} /> : null; })}
          {s.race && s.projs.map((pj, k) => { const x = 60 + pj.d - s.dist; return x > -60 && x < width + 40 ? <Text key={'pj' + k} style={{ position: 'absolute', left: x, bottom: gy(pj.d) + 40, fontSize: 30, transform: [{ rotate: '45deg' }] }}>🎉</Text> : null; })}
          {s.race && (() => { const fx = 60 + FINISH - s.dist; return fx < width + 20 ? <View style={[st.finish, { left: fx + ROBOT, bottom: gy(FINISH) }]}><Text style={st.flag}>🏁</Text></View> : null; })()}
          {s.online && Object.entries(s.others).map(([k, o]) => { const i = Number(k); const od = o.dd ?? o.d; const x = 60 + (od - s.dist) + (i - s.me) * 26; if (o.gone || x < -80 || x > width + 80) return null; return (
            <View key={'p' + i} style={[st.robot, { left: x, bottom: gy(od + (i - s.me) * 26) + (o.y > 1 ? (o.dy ?? o.y) : 0), opacity: 0.9, transform: o.sp ? [{ rotate: `${(s.t * 720) % 360}deg` }] : [] }]}>
              <RobotBody color={PCOL[i]} skin={(o.k ?? 0)} t={s.t} /><Text style={[st.tag, { top: -40 - i * 16, color: PCOL[i] }]}>{nameOf(i)}</Text><Extras z={o.z} c={o.c} g={o.g} />
            </View>); })}
          {s.race && s.rivals.map((r, i) => { const x = 60 + (r.d - s.dist) + (i + 1) * 8; if (x < -80 || x > width + 80) return null; return (
            <View key={r.name} style={[st.robot, { left: x, bottom: gy(s.dist + x - 60), opacity: 0.9, transform: [{ scale: 0.85 }, { rotate: r.slow ? `${(1 - r.slow) * 360}deg` : '0deg' }] }]}>
              <RobotBody color={r.color} skin={(r.skin ?? 0)} t={s.t} /><Text style={st.tag}>{r.name}</Text><Extras z={(r.frozen ?? 0) > 0} />
            </View>); })}
          <View style={[st.robot, { left: 60, bottom: gy(s.dist) + s.y, transform: s.slow > 0 && s.race ? [{ rotate: `${(1 - s.slow) * 360}deg` }] : [] }]}>
            <RobotBody color={PCOL[s.online ? s.me : 0]} skin={mySkin} t={s.t} />{s.online && <Text style={[st.tag, { top: -40 - s.me * 16 }]}>Você</Text>}<Extras z={s.frozen > 0} c={s.coat} g={s.shelter > 0} />
          </View>
        </View>)}
      </Pressable>

      {W.ice && s.storm > 0 && mode === 'play' && <View style={st.snow} pointerEvents="none"><Text style={st.snowText}>❄️  ❄️  ❄️{'\n'}  ❄️  ❄️  ❄️{'\n'}❄️  ❄️  ❄️</Text></View>}
      {!!W.quiz && mode === 'play' && !!(s.quiz || s.quizRes) && <View style={st.quizBox} pointerEvents="none">{!!s.quiz && <Text style={st.quizText}>{s.quiz}</Text>}{!!s.quizRes && <Text style={st.quizRes}>{s.quizRes}</Text>}</View>}
      {warn && <Text style={st.warn} pointerEvents="none">❄️ Tempestade! {s.coat ? '🧣 Você está protegido!' : 'Pegue a 🧣 ou entre no iglu!'}</Text>}
      <View style={st.hud} pointerEvents="box-none">
        <Text style={[st.score, W.space && { color: '#fff' }]}>🔋 {s.score}</Text>
        {s.race ? (
          <View style={{ flex: 1, alignItems: 'center' }}>
            <Text style={st.place}>{ord[place - 1]} lugar</Text>
            <View style={st.bar}><View style={[st.barFill, { width: `${Math.min(100, (s.dist / FINISH) * 100)}%` }]} /></View>
          </View>
        ) : <Text style={st.best}>Recorde: {best}</Text>}
        {!!s.note && mode === 'play' && <Text style={st.note}>{s.note}</Text>}
        <Pressable style={st.mute} onPress={() => setMuted(m => !m)} accessibilityLabel={muted ? 'Ligar som' : 'Desligar som'}>
          <Text style={{ fontSize: 30 }}>{muted ? '🔇' : '🔊'}</Text>
        </Pressable>
      </View>

      {(mode === 'count' || (mode === 'play' && s.online && s.t < 0.8)) && (
        <View style={st.overlay} pointerEvents="none"><Text style={st.count}>{count > 0 ? count : 'Já!'}</Text></View>
      )}
      {mode === 'lobby' && (
        <View style={st.overlay}>
          <View style={st.card}>
            <Text style={st.title}>Corrida online 👥</Text>
            {lv.view === 'choose' && (<>
              <Text style={st.sub}>Até 4 robôs! Uma pessoa cria a sala e as outras entram com o número.</Text>
              <Text style={st.wname}>Escolha seu apelido:</Text>
              <View style={{ flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'center', marginVertical: 8 }}>
                {NICKS.map(n => <Pressable key={n} accessibilityLabel={'apelido ' + n} onPress={() => setNick(n)} style={[st.chip, nick === n && st.chipOn]}><Text style={st.chipText}>{n}</Text></Pressable>)}
              </View>
              <Pressable style={st.btn} onPress={hostRoom}><Text style={st.btnText}>➕ Criar sala</Text></Pressable>
              <Pressable style={[st.btn, { backgroundColor: '#219EBC', marginTop: 14 }]} onPress={() => setLv({ view: 'join', code: '', err: '', ids: [] })}><Text style={st.btnText}>🔢 Entrar</Text></Pressable>
            </>)}
            {lv.view === 'wait' && <Text style={st.sub}>Conectando… ⏳</Text>}
            {lv.view === 'join' && (<>
              <Text style={st.codeBox}>{(lv.code + '____').slice(0, 4).split('').join(' ')}</Text>
              <View style={st.pad}>
                {['1','2','3','4','5','6','7','8','9','⌫','0','✓'].map(k => (
                  <Pressable key={k} style={st.key} accessibilityLabel={'tecla ' + k} onPress={() => {
                    if (k === '⌫') setLv(v => ({ ...v, code: v.code.slice(0, -1) }));
                    else if (k === '✓') { if (lv.code.length === 4) join(lv.code); }
                    else if (lv.code.length < 4) setLv(v => ({ ...v, code: v.code + k }));
                  }}><Text style={st.keyText}>{k}</Text></Pressable>))}
              </View>
            </>)}
            {lv.view === 'room' && (<>
              <Text style={st.sub}>Número da sala:</Text>
              <Text style={st.codeBox}>{lv.code.split('').join(' ')}</Text>
              <View style={{ flexDirection: 'row', marginVertical: 12 }}>
                {[0, 1, 2, 3].map(i => <View key={i} style={{ alignItems: 'center', width: 72 }}><View style={[st.mini, { backgroundColor: lv.ids.includes(i) ? PCOL[i] : '#E9ECEF' }]} /><Text style={{ fontSize: 13, fontWeight: '800', color: '#023047' }} testID={'nick-' + i}>{lv.ids.includes(i) ? nameOf(i) + (i === roomRef.current?.me ? ' (você)' : '') : '—'}</Text></View>)}
              </View>
              <Text style={st.sub}>{lv.ids.length}/{MAX} robôs na sala</Text>
              <Picker off={!roomRef.current?.isHost} />
              {roomRef.current?.isHost ? (
                <Pressable style={[st.btn, lv.ids.length < 2 && { opacity: 0.4 }]} onPress={hostStart}><Text style={st.btnText}>{lv.ids.length < 2 ? 'Esperando…' : '▶ Começar'}</Text></Pressable>
              ) : <Text style={st.sub}>Esperando quem criou a sala começar…</Text>}
            </>)}
            {!!lv.err && <Text style={[st.sub, { color: '#D00000' }]}>{lv.err}</Text>}
            <Pressable style={[st.btn, { backgroundColor: '#ADB5BD', marginTop: 14 }]} onPress={() => { leaveRoom(); setMode('menu'); }}><Text style={st.btnText}>← Voltar</Text></Pressable>
          </View>
        </View>
      )}
      {mode === 'story' && (
        <View style={st.overlay}>
          <View style={[st.card, { maxHeight: height - 60, paddingHorizontal: 14 }]}>
            <Text style={st.title}>📖 Modo História</Text>
            <Text style={st.wname}>⭐ {done.length}/{WORLD_IDS.length * 5} fases · 🎭 {SKINS.filter((_, k) => skinOpen(k)).length}/50 skins</Text>
            <ScrollView style={{ width: '100%', marginVertical: 10 }} contentContainerStyle={{ paddingBottom: 6 }}>
              {WORLD_IDS.map(w => (
                <View key={w} style={st.mapRow}>
                  <Text style={{ fontSize: 30, width: 40 }}>{WORLDS[w].emoji}</Text>
                  <View style={{ flex: 1 }}>
                    <Text style={{ fontSize: 15, fontWeight: '900', color: '#023047' }}>{WORLDS[w].name}</Text>
                    <View style={{ flexDirection: 'row' }}>
                      {[1, 2, 3, 4, 5].map(n => { const ok = done.includes(gidx(w, n)); const open = phaseOpen(w, n); return (
                        <Pressable key={n} disabled={!open} accessibilityLabel={`fase ${WORLDS[w].name} ${n}`} onPress={() => start(true, { w, n })} style={[st.phase, ok ? { backgroundColor: '#FFD43B' } : open ? { backgroundColor: '#06D6A0' } : { backgroundColor: '#E9ECEF' }]}>
                          <Text style={{ fontSize: ok ? 18 : 16, fontWeight: '900', color: open ? '#023047' : '#ADB5BD' }}>{ok ? '⭐' : open ? n : '🔒'}</Text>
                        </Pressable>); })}
                    </View>
                    <Text style={{ fontSize: 11, color: '#495057' }}>{(WORLDS[w].space ? SPACE_PHASES : PHASES).join(' · ')}</Text>
                  </View>
                </View>))}
            </ScrollView>
            <Pressable style={[st.btn, { backgroundColor: '#ADB5BD' }]} onPress={() => setMode('menu')}><Text style={st.btnText}>← Voltar</Text></Pressable>
          </View>
        </View>
      )}
      {mode === 'skins' && (
        <View style={st.overlay}>
          <View style={[st.card, { maxHeight: height - 60, paddingHorizontal: 10 }]}>
            <Text style={st.title}>🎭 Skins</Text>
            <View style={st.banner}><Text style={st.bannerText}>🔒 Jogue o 📖 Modo História para ganhar novas skins!</Text></View>
            <Pressable style={[st.mbtn, { backgroundColor: '#9775FA', marginBottom: 8 }]} onPress={() => setMode('story')} accessibilityLabel="ir para modo historia"><Text style={st.btnText}>📖 Ir para o Modo História</Text></Pressable>
            {!!skinInfo && <Text style={st.skinInfo}>{skinInfo}</Text>}
            <Text style={st.wname}>{SKINS[mySkin].name} · {SKINS.filter((_, k) => skinOpen(k)).length}/50 liberadas</Text>
            <ScrollView style={{ width: '100%', marginVertical: 10 }} contentContainerStyle={{ flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'center' }}>
              {SKINS.map((k, i) => { const open = skinOpen(i); return (
                <Pressable key={i} accessibilityLabel={'skin ' + k.name} onPress={() => { if (open) { setMySkin(i); setSkinInfo(''); } else setSkinInfo(`🔒 ${k.name}: ${lockText(i)}`); }} style={[st.skinCell, mySkin === i && { borderColor: '#FB5607', backgroundColor: '#FFF3E0' }]}>
                  <View style={{ transform: [{ scale: 0.55 }], width: ROBOT, height: ROBOT, alignItems: 'center', marginTop: 4, marginBottom: -4 }}><RobotBody color={PCOL[0]} skin={i} dim={!open} t={s.t} /></View>
                  <Text style={st.skinLabel} numberOfLines={2}>{open ? k.name : '🔒 ' + k.name}</Text>
                </Pressable>); })}
            </ScrollView>
            <Pressable style={[st.btn, { backgroundColor: '#ADB5BD' }]} onPress={() => setMode('menu')}><Text style={st.btnText}>← Voltar</Text></Pressable>
          </View>
        </View>
      )}
      {mode !== 'play' && mode !== 'lobby' && mode !== 'count' && mode !== 'story' && mode !== 'skins' && (
        <View style={st.overlay} pointerEvents="box-none">
          <View style={[st.card, { maxHeight: height - 30, paddingHorizontal: 18 }]}>
          <ScrollView style={{ width: '100%' }} contentContainerStyle={{ alignItems: 'center' }}>
            {mode === 'podium' && s.online ? (() => {
              const pod = s.pod ?? { order: [], gone: [] };
              const pending = s.ids.filter(i => !pod.order.includes(i) && !pod.gone.includes(i));
              const list = [...pod.order.map((i, k) => ({ i, label: `${k + 1}º` })), ...pending.map(i => ({ i, label: '…' })), ...pod.gone.map(i => ({ i, label: 'saiu' }))];
              const vis = [list[1], list[0], list[2], list[3]]; const h = [70, 100, 50, 35];
              return (<>
              <Text style={st.title}>{pod.order[0] === s.me ? 'Você venceu! 🏆' : pod.order.length ? 'Que corrida! 🎉' : 'Chegou! 🏁'}</Text>
              <View style={st.podium}>
                {vis.map((p, k) => p && (
                    <View key={p.i} style={{ alignItems: 'center', marginHorizontal: 4 }}>
                      <Text style={{ fontSize: 14, fontWeight: '800', color: '#023047' }}>{p.i === s.me ? `Você (${nameOf(p.i)})` : nameOf(p.i)}</Text>
                      <View style={[st.mini, { backgroundColor: PCOL[p.i], opacity: p.label === 'saiu' ? 0.3 : 1 }]} />
                      <View style={[st.step, { height: h[k], width: 60 }]}><Text style={[st.stepText, p.label === 'saiu' && { fontSize: 14 }]} testID={'place-' + p.i}>{p.label}</Text></View>
                    </View>))}
              </View>
              <Text style={st.sub}>{pending.length ? 'Esperando os outros robôs chegarem…' : `Você pegou ${s.score} bateria${s.score === 1 ? '' : 's'}!`}</Text>
              </>); })() : mode === 'podium' ? (<>
              <Text style={st.title}>{s.place === 1 ? 'Nodex venceu! 🏆' : 'Que corrida! 🎉'}</Text>
              <View style={st.podium}>
                {(() => { const list = [{ name: 'Nodex', color: '#4CC9F0', d: s.dist + (s.place === 1 ? 1e6 : 0) }, ...s.rivals].sort((x, y) => y.d - x.d); const top = list.slice(0, 3); const order = [top[1], top[0], top[2]]; const h = [70, 100, 50];
                  return order.map((r, i) => r && (
                    <View key={r.name} style={{ alignItems: 'center', marginHorizontal: 6 }}>
                      <Text style={{ fontSize: 16, fontWeight: '800', color: '#023047' }}>{r.name}</Text>
                      <View style={[st.mini, { backgroundColor: r.color }]} />
                      <View style={[st.step, { height: h[i] }]}><Text style={st.stepText}>{['2º', '1º', '3º'][i]}</Text></View>
                    </View>)); })()}
              </View>
              <Text style={st.sub}>Nodex chegou em {ord[s.place - 1]} lugar e pegou {s.score} bateria{s.score === 1 ? '' : 's'}!</Text>
              {!!story && !!storyMsg && <Text style={[st.sub, { color: '#2B8A3E', fontWeight: '900', marginTop: 0 }]}>{storyMsg}</Text>}
            </>) : (<>
              <Text style={st.title}>{mode === 'menu' ? 'Nodex: Robô Corredor' : 'Tente de novo! 😄'}</Text>
              <Text style={st.sub}>{mode === 'menu' ? `Toque para o Nodex pular. ${WORLDS[world].tip} Baterias dão turbo!` : `O Nodex pegou ${s.score} bateria${s.score === 1 ? '' : 's'}! Recorde: ${best}`}</Text>
            </>)}
            {mode === 'menu' && <Picker />}
            {mode === 'podium' && !!story ? (<>
              {s.place <= 3 && (story.n < 5 || WORLD_IDS.indexOf(story.w) < WORLD_IDS.length - 1) && <Pressable style={st.btn} onPress={() => { const nx = story.n < 5 ? { w: story.w, n: story.n + 1 } : { w: WORLD_IDS[WORLD_IDS.indexOf(story.w) + 1], n: 1 }; start(true, nx); }}><Text style={st.btnText}>▶ Próxima fase</Text></Pressable>}
              <Pressable style={[st.btn, { backgroundColor: '#219EBC', marginTop: 14 }]} onPress={() => start(true, story)}><Text style={st.btnText}>↻ De novo</Text></Pressable>
              <Pressable style={[st.btn, { backgroundColor: '#FB5607', marginTop: 14 }]} onPress={() => { setStory(null); setMode('story'); }}><Text style={st.btnText}>🗺️ Mapa</Text></Pressable>
            </>) : (<>
            {mode === 'menu' && <>
              <Pressable style={[st.mbtn, { backgroundColor: '#F06595' }]} onPress={() => { setSkinInfo(''); setMode('skins'); }} accessibilityLabel="skins"><Text style={st.btnText}>🎭 Skins</Text></Pressable>
              <Pressable style={[st.mbtn, { backgroundColor: '#9775FA' }]} onPress={() => setMode('story')} accessibilityLabel="modo historia"><Text style={st.btnText}>📖 História</Text></Pressable>
            </>}
            {onlineAvailable() && <Pressable style={[st.mbtn, { backgroundColor: '#FB5607' }]} onPress={() => { leaveRoom(); g.current = fresh(false); setLv({ view: 'choose', code: '', err: '', ids: [] }); setMode('lobby'); }}><Text style={st.btnText}>👥 Online</Text></Pressable>}
            <Pressable style={[st.mbtn, { backgroundColor: '#06D6A0' }]} onPress={() => { leaveRoom(); start(true); }}><Text style={st.btnText}>🏁 Corrida</Text></Pressable>
            <Pressable style={[st.mbtn, { backgroundColor: '#219EBC' }]} onPress={() => { leaveRoom(); start(false); }}><Text style={st.btnText}>∞ Sem fim</Text></Pressable>
            </>)}
          </ScrollView>
          </View>
        </View>
      )}
      {s.race && mode === 'play' && (
        <View style={st.powers} pointerEvents="box-none">
          {s.cd > 0 ? <View style={[st.pbtn, { backgroundColor: '#CED4DA' }]}><Text style={st.pbtnText}>{Math.ceil(s.cd)}</Text></View> : (<>
            <Pressable style={st.pbtn} testID="ui-rocket" onPress={() => usePower('rocket')} accessibilityLabel="foguetinho"><Text style={st.pbtnText}>🎉</Text><Text style={st.plabel}>Foguetinho</Text></Pressable>
            <Pressable style={[st.pbtn, { backgroundColor: '#3D348B' }]} testID="ui-oil" onPress={() => usePower('oil')} accessibilityLabel="soltar oleo"><Text style={st.pbtnText}>💧</Text><Text style={st.plabel}>Óleo</Text></Pressable>
          </>)}
        </View>)}
      {mode === 'podium' && (!s.online || (s.pod?.order.length ?? 0) > 0) && <Confetti h={height} />}
    </View>
  );
}

const st = StyleSheet.create({
  root: { flex: 1, backgroundColor: '#FFE8A3', overflow: 'hidden', userSelect: 'none' } as any,
  sky: { flex: 1, backgroundColor: '#FFE8A3' },
  machine: { position: 'absolute', bottom: GROUND, width: 100, borderTopLeftRadius: 16, borderTopRightRadius: 16, opacity: 0.8 },
  belt: { position: 'absolute', bottom: 0, left: 0, right: 0, backgroundColor: '#6C757D', borderTopWidth: 10, borderTopColor: '#FB8500', overflow: 'hidden' },
  beltText: { color: '#ADB5BD', fontSize: 28, marginTop: 8 },
  oil: { position: 'absolute', width: 60, height: 14, borderRadius: 20, backgroundColor: '#1D3557' },
  gear: { position: 'absolute', fontSize: 40 },
  battery: { position: 'absolute', fontSize: 36 },
  robot: { position: 'absolute', width: ROBOT, height: ROBOT, alignItems: 'center' },
  antenna: { position: 'absolute', top: -14, width: 4, height: 14, backgroundColor: '#023047' },
  ball: { position: 'absolute', top: -22, width: 12, height: 12, borderRadius: 6, backgroundColor: '#FB5607' },
  head: { width: ROBOT, height: ROBOT, borderRadius: 14, backgroundColor: '#4CC9F0', flexDirection: 'row', justifyContent: 'space-evenly', paddingTop: 12, borderWidth: 3, borderColor: '#023047' },
  eye: { width: 12, height: 12, borderRadius: 6, backgroundColor: '#023047' },
  smile: { position: 'absolute', bottom: 12, width: 22, height: 8, borderBottomLeftRadius: 10, borderBottomRightRadius: 10, backgroundColor: '#023047' },
  hud: { position: 'absolute', top: 0, left: 0, right: 0, padding: 16, paddingTop: 40, flexDirection: 'row', alignItems: 'center' },
  score: { fontSize: 32, fontWeight: '900', color: '#023047' },
  best: { flex: 1, textAlign: 'center', fontSize: 18, fontWeight: '700', color: '#023047' },
  mute: { width: 64, height: 64, borderRadius: 32, backgroundColor: '#fff', alignItems: 'center', justifyContent: 'center' },
  overlay: { ...StyleSheet.absoluteFill as any, alignItems: 'center', justifyContent: 'center', backgroundColor: 'rgba(255,183,3,0.35)' },
  card: { backgroundColor: '#fff', borderRadius: 28, padding: 28, width: '85%', maxWidth: 420, alignItems: 'center' },
  title: { fontSize: 34, fontWeight: '900', color: '#FB5607', textAlign: 'center' },
  sub: { fontSize: 20, color: '#023047', textAlign: 'center', marginVertical: 18 },
  btn: { backgroundColor: '#06D6A0', borderRadius: 40, paddingVertical: 16, paddingHorizontal: 40, minWidth: 240, alignItems: 'center' },
  place: { fontSize: 26, fontWeight: '900', color: '#FB5607' },
  bar: { width: '80%', height: 10, borderRadius: 5, backgroundColor: '#fff', marginTop: 4, overflow: 'hidden' },
  barFill: { height: 10, backgroundColor: '#06D6A0' },
  finish: { position: 'absolute', bottom: GROUND, width: 14, height: 160, backgroundColor: '#fff', borderWidth: 3, borderColor: '#023047' },
  flag: { position: 'absolute', top: -40, left: -6, fontSize: 36 },
  tag: { position: 'absolute', top: -40, fontSize: 13, fontWeight: '800', color: '#023047' },
  podium: { flexDirection: 'row', alignItems: 'flex-end', marginTop: 16 },
  mini: { width: 34, height: 34, borderRadius: 8, borderWidth: 3, borderColor: '#023047', marginVertical: 4 },
  step: { width: 70, backgroundColor: '#FFB703', borderTopLeftRadius: 10, borderTopRightRadius: 10, alignItems: 'center', justifyContent: 'center' },
  stepText: { fontSize: 22, fontWeight: '900', color: '#fff' },
  count: { fontSize: 120, fontWeight: '900', color: '#FB5607' },
  note: { position: 'absolute', top: 100, left: 16, right: 16, textAlign: 'center', fontSize: 18, fontWeight: '800', color: '#023047' },
  codeBox: { fontSize: 44, fontWeight: '900', color: '#023047', letterSpacing: 4, marginVertical: 8 },
  pad: { flexDirection: 'row', flexWrap: 'wrap', width: 270, justifyContent: 'center' },
  key: { width: 76, height: 64, margin: 6, borderRadius: 16, backgroundColor: '#FFE8A3', alignItems: 'center', justifyContent: 'center' },
  keyText: { fontSize: 30, fontWeight: '900', color: '#023047' },
  wbtn: { width: 58, height: 58, margin: 4, borderRadius: 16, backgroundColor: '#F1F3F5', alignItems: 'center', justifyContent: 'center', borderWidth: 3, borderColor: 'transparent' },
  wbtnOn: { borderColor: '#FB5607', backgroundColor: '#FFF3E0' },
  wname: { width: '100%', textAlign: 'center', fontSize: 18, fontWeight: '800', color: '#023047', marginTop: 4 },
  igloo: { position: 'absolute', width: 90, height: 60, borderTopLeftRadius: 45, borderTopRightRadius: 45, backgroundColor: '#FFFFFF', borderWidth: 3, borderColor: '#90E0EF', alignItems: 'center', justifyContent: 'flex-end' },
  iglooDoor: { width: 30, height: 28, borderTopLeftRadius: 15, borderTopRightRadius: 15, backgroundColor: '#023047' },
  scarf: { position: 'absolute', bottom: -6, fontSize: 26 },
  iceCube: { position: 'absolute', left: -8, top: -8, width: ROBOT + 16, height: ROBOT + 16, borderRadius: 12, backgroundColor: 'rgba(173,232,244,0.65)', borderWidth: 3, borderColor: '#FFFFFF', alignItems: 'flex-end' },
  snow: { ...(StyleSheet.absoluteFill as any), backgroundColor: 'rgba(255,255,255,0.45)', alignItems: 'center', justifyContent: 'center' },
  snowText: { fontSize: 48, textAlign: 'center', lineHeight: 90 },
  warn: { position: 'absolute', top: 140, left: 16, right: 16, textAlign: 'center', fontSize: 24, fontWeight: '900', color: '#0077B6', backgroundColor: '#FFFFFFDD', borderRadius: 16, padding: 10 },
  chip: { paddingHorizontal: 12, paddingVertical: 8, margin: 3, borderRadius: 18, backgroundColor: '#F1F3F5', borderWidth: 2, borderColor: 'transparent' },
  chipOn: { borderColor: '#FB5607', backgroundColor: '#FFF3E0' },
  chipText: { fontSize: 15, fontWeight: '800', color: '#023047' },
  iglooBadge: { position: 'absolute', top: -30, right: -26, width: 30, height: 20, borderTopLeftRadius: 15, borderTopRightRadius: 15, backgroundColor: '#fff', borderWidth: 2, borderColor: '#0096C7', alignItems: 'center', justifyContent: 'flex-end' },
  iglooBadgeDoor: { width: 10, height: 9, borderTopLeftRadius: 5, borderTopRightRadius: 5, backgroundColor: '#023047' },
  powers: { position: 'absolute', right: 12, bottom: 14, flexDirection: 'row' },
  pbtn: { width: 84, height: 84, borderRadius: 42, backgroundColor: '#FB5607', alignItems: 'center', justifyContent: 'center', marginLeft: 10, borderWidth: 4, borderColor: '#fff' },
  pbtnText: { fontSize: 32, color: '#fff', fontWeight: '900' },
  plabel: { fontSize: 11, color: '#fff', fontWeight: '800' },
  lava: { position: 'absolute', width: 40, height: 36, borderRadius: 20, backgroundColor: '#FF7B00', borderWidth: 3, borderColor: '#FFD166', flexDirection: 'row', justifyContent: 'space-evenly', paddingTop: 10 },
  lavaEye: { width: 6, height: 6, borderRadius: 3, backgroundColor: '#5A189A' },
  volcano: { position: 'absolute', width: 0, height: 0, borderLeftWidth: 130, borderRightWidth: 130, borderBottomWidth: 230, borderLeftColor: 'transparent', borderRightColor: 'transparent', borderBottomColor: '#9C6644' },
  crater: { position: 'absolute', width: 60, height: 22, borderRadius: 11, backgroundColor: '#FF9F1C' },
  bubble: { position: 'absolute', width: 52, height: 52, borderRadius: 26, borderWidth: 4, borderColor: '#023047', alignItems: 'center', justifyContent: 'center' },
  bubbleText: { fontSize: 24, fontWeight: '900', color: '#023047' },
  quizBox: { position: 'absolute', top: 130, left: 20, right: 20, alignItems: 'center', backgroundColor: '#FFFFFFEE', borderRadius: 20, padding: 12 },
  quizText: { fontSize: 32, fontWeight: '900', color: '#023047' },
  quizRes: { fontSize: 20, fontWeight: '800', color: '#2B8A3E', marginTop: 4 },
  spaceHint: { position: 'absolute', bottom: 30, left: 0, right: 0, textAlign: 'center', color: '#FFFFFFAA', fontSize: 16, fontWeight: '800' },
  btn2: { borderRadius: 30, paddingVertical: 14, paddingHorizontal: 14, marginHorizontal: 5, minWidth: 130, alignItems: 'center' },
  btn2Text: { fontSize: 20, fontWeight: '900', color: '#fff' },
  mapRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: 6, borderBottomWidth: 1, borderBottomColor: '#F1F3F5' },
  phase: { width: 40, height: 40, borderRadius: 20, marginRight: 6, marginVertical: 3, alignItems: 'center', justifyContent: 'center' },
  skinCell: { width: 68, height: 92, margin: 3, borderRadius: 12, backgroundColor: '#F8F9FA', borderWidth: 3, borderColor: 'transparent', alignItems: 'center', overflow: 'hidden' },
  mbtn: { width: '100%', maxWidth: 340, height: 62, borderRadius: 31, alignItems: 'center', justifyContent: 'center', marginBottom: 10 },
  banner: { width: '100%', backgroundColor: '#FFD43B', borderRadius: 18, padding: 12, marginVertical: 8, borderWidth: 3, borderColor: '#FB5607' },
  bannerText: { fontSize: 19, fontWeight: '900', color: '#023047', textAlign: 'center' },
  skinInfo: { fontSize: 15, fontWeight: '800', color: '#9C36B5', textAlign: 'center', marginBottom: 6 },
  skinLabel: { fontSize: 9.5, lineHeight: 11, fontWeight: '800', color: '#023047', textAlign: 'center', paddingHorizontal: 2 },
  btnText: { fontSize: 28, fontWeight: '900', color: '#fff' },
});
