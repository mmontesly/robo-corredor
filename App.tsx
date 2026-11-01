import React, { useEffect, useRef, useState } from 'react';
import { Platform, Pressable, StyleSheet, Text, View, useWindowDimensions } from 'react-native';
import * as Haptics from 'expo-haptics';
import { createRoom, joinRoom, onlineAvailable, rng, MAX, type Room, type Msg } from './online';

type Kind = 'gear' | 'oil' | 'battery' | 'coat' | 'igloo';
type Obj = { id: number; x: number; kind: Kind; y: number; taken?: boolean; live?: boolean };
type WorldId = 'fabrica' | 'gelo' | 'deserto' | 'doces' | 'cidade';
type World = { emoji: string; name: string; sky: string; deco: string[]; ground: string; top: string; belt: string; a: string; b: string; puddle?: string; roll?: boolean; hills?: boolean; cars?: boolean; ice?: boolean; tip: string };
const WORLDS: Record<WorldId, World> = {
  fabrica: { emoji: '🏭', name: 'Fábrica', sky: '#FFE8A3', deco: ['#8ECAE6', '#A0C4FF', '#BDB2FF', '#9BF6FF'], ground: '#6C757D', top: '#FB8500', belt: '▸ ▸ ▸ ▸ ▸ ▸ ▸ ▸ ▸ ▸ ▸ ▸', a: '⚙️', b: '', puddle: '#1D3557', roll: true, tip: 'Pule as engrenagens e o óleo!' },
  gelo: { emoji: '❄️', name: 'Gelo', sky: '#DFF6FF', deco: ['#FFFFFF', '#CAF0F8', '#ADE8F4', '#E9F5FF'], ground: '#BDE0FE', top: '#FFFFFF', belt: '❄  ❄  ❄  ❄  ❄  ❄  ❄  ❄', a: '⚪', b: '🧊', roll: true, ice: true, tip: 'Pule bolas de neve e gelo. Na ❄️ Tempestade, use a 🧣 roupinha ou entre no iglu!' },
  deserto: { emoji: '🏜️', name: 'Deserto', sky: '#FFE5B4', deco: ['#F4A261', '#E9C46A', '#F6BD60', '#E76F51'], ground: '#E9C46A', top: '#F4A261', belt: '', a: '🌵', b: '🪨', hills: true, tip: 'Suba e desça as dunas pulando cactos e pedras!' },
  doces: { emoji: '🍭', name: 'Doces', sky: '#FFE5EC', deco: ['#FFC8DD', '#BDE0FE', '#CDB4DB', '#FFAFCC'], ground: '#CDB4DB', top: '#FF8FAB', belt: '🍬    🍬    🍬    🍬    🍬', a: '🍩', b: '', puddle: '#FF4D8D', roll: true, tip: 'Pule as rosquinhas e a calda grudenta!' },
  cidade: { emoji: '🏙️', name: 'Cidade', sky: '#CAF0F8', deco: ['#ADB5BD', '#90E0EF', '#FFD6A5', '#CDB4DB'], ground: '#495057', top: '#ADB5BD', belt: '—   —   —   —   —   —   —', a: '🚗', b: '🚕', cars: true, tip: 'Pule os carrinhos que vêm na rua!' },
};
const WORLD_IDS = Object.keys(WORLDS) as WorldId[];
const hill = (w: World, wx: number) => w.hills ? 55 + 35 * Math.sin(wx / 260) + 15 * Math.sin(wx / 97) : 0;
const pickKind = (r: number, w: World): Kind => w.ice ? (r < 0.3 ? 'gear' : r < 0.5 ? 'oil' : r < 0.72 ? 'battery' : r < 0.85 ? 'coat' : 'igloo') : (r < 0.35 ? 'gear' : r < 0.6 ? 'oil' : 'battery');
type Mode = 'menu' | 'play' | 'over' | 'podium' | 'lobby' | 'count';
const PCOL = ['#4CC9F0', '#FF006E', '#8338EC', '#06D6A0'];
const PNAME = ['Azul', 'Rosa', 'Roxo', 'Verde'];
type Other = { d: number; y: number; fin?: number; gone?: boolean; seen?: number; z?: boolean; c?: boolean };
function makeTrack(seed: number, w: World) {
  const r = rng(seed); const out: { wx: number; kind: Kind; y: number }[] = [];
  for (let wx = 700; wx < 6600; wx += 230 + r() * 300) { const kind = pickKind(r(), w); out.push({ wx, kind, y: kind === 'battery' ? (r() < 0.5 ? 20 : 130) : 0 }); if (kind === 'igloo') wx += 80; }
  return out;
}
const stormPlan = (seed: number) => { const r = rng(seed ^ 0x5eed); return { first: 7 + r() * 2, period: 9 + r() * 2 }; };
type Rival = { name: string; color: string; d: number; v: number; frozen?: number };
const FINISH = 7000;
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
  const [world, setWorldS] = useState<WorldId>('fabrica');
  const worldRef = useRef<WorldId>('fabrica'); worldRef.current = world;
  const setWorld = (w: WorldId) => { worldRef.current = w; setWorldS(w); };
  const [muted, setMuted] = useState(false);
  const [best, setBest] = useState(0);
  const [, force] = useState(0);
  const fresh = (race: boolean, seed = Math.floor(Math.random() * 1e9)) => ({ w: worldRef.current, seed, coat: false, frozen: 0, storm: 0, stormAt: stormPlan(seed).first, period: stormPlan(seed).period, y: 0, vy: 0, objs: [] as Obj[], score: 0, speed: 260, dist: 0, next: 1.2, id: 0, t: 0, race, slow: 0, boost: 0, rivals: newRivals(), place: 0, online: false, me: 0, ids: [0] as number[], others: {} as Record<number, Other>, track: [] as ReturnType<typeof makeTrack>, myTime: 0, sendT: 0, note: '', finT: {} as Record<number, number>, pod: null as null | { order: number[]; gone: number[] } });
  // Single source of truth for the online podium: the host (or, if the host left, each phone locally) ranks by race time, ties by player number.
  const rankFrom = (s: ReturnType<typeof fresh>) => ({ order: Object.entries(s.finT).map(([i, t]) => [Number(i), t] as const).sort((a, b) => a[1] - b[1] || a[0] - b[0]).map(x => x[0]), gone: Object.entries(s.others).filter(([i, o]) => o.gone && s.finT[Number(i)] === undefined).map(([i]) => Number(i)) });
  const publish = () => { const s = g.current; if (!s.online) return; const isHost = roomRef.current?.isHost; if (!isHost && roomRef.current) return; s.pod = rankFrom(s); if (isHost) roomRef.current?.send({ t: 'podium', order: s.pod.order, gone: s.pod.gone }); force(n => n + 1); };
  const g = useRef(fresh(false));
  const roomRef = useRef<Room | null>(null);
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
    if (m.t === 'lobby') { setLv(v => ({ ...v, ids: m.ids })); if (roomRef.current?.isHost) roomRef.current.send({ t: 'world', w: worldRef.current }); }
    else if (m.t === 'world') { if (WORLDS[m.w as WorldId]) setWorld(m.w as WorldId); }
    else if (m.t === 'start') beginOnline(m.seed, m.ids, roomRef.current?.me ?? 0, (WORLDS[m.w as WorldId] ? m.w : 'fabrica') as WorldId);
    else if (s.online && m.t === 's' && s.others[m.i]) { const o = s.others[m.i]; o.d = m.d; o.y = m.y; o.z = m.z; o.c = m.c; o.seen = Date.now(); }
    else if (s.online && m.t === 'fin' && s.others[m.i]) { s.others[m.i].fin = m.time; s.finT[m.i] = m.time; publish(); }
    else if (s.online && m.t === 'podium' && !roomRef.current?.isHost) { s.pod = { order: m.order, gone: m.gone }; force(n => n + 1); }
    else if (m.t === 'left') { if (s.online && s.others[m.i]) { s.others[m.i].gone = true; s.note = `Robô ${PNAME[m.i]} saiu`; publish(); } }
  };
  const onClose = () => {
    const s = g.current;
    if (s.online) { Object.values(s.others).forEach(o => { o.gone = true; }); s.note = 'A sala fechou. Continue correndo!'; roomRef.current = null; publish(); force(n => n + 1); return; }
    else setLv({ view: 'choose', code: '', err: 'A sala fechou.', ids: [] });
    roomRef.current = null;
  };
  const errText = (e: any) => e === 'full' ? 'Essa sala está cheia ou já começou.' : e === 'peer-unavailable' || e === 'timeout' ? 'Sala não encontrada. Confira o número.' : 'Sem conexão. Tente de novo.';
  const hostRoom = async () => { setLv({ view: 'wait', code: '', err: '', ids: [] }); try { const r = await createRoom({ onMsg, onClose }); roomRef.current = r; setLv({ view: 'room', code: r.code, err: '', ids: [0] }); } catch (e) { setLv({ view: 'choose', code: '', err: errText(e), ids: [] }); } };
  const join = async (code: string) => { setLv(v => ({ ...v, view: 'wait', err: '' })); try { const r = await joinRoom(code, { onMsg, onClose }); roomRef.current = r; setLv(v => ({ view: 'room', code, err: '', ids: v.ids.length ? v.ids : [0, r.me] })); } catch (e) { setLv({ view: 'join', code: '', err: errText(e), ids: [] }); } };
  const hostStart = () => { const r = roomRef.current; if (!r?.isHost) return; const ids = r.ids(); if (ids.length < 2) return; r.lock(); const seed = Math.floor(Math.random() * 1e9); r.send({ t: 'start', seed, ids, w: worldRef.current }); beginOnline(seed, ids, 0, worldRef.current); };
  useEffect(() => {
    const iv = setInterval(() => {
      const s = g.current; if (!s.online) return;
      if (mode === 'podium') roomRef.current?.send({ t: 's', i: s.me, d: s.dist, y: 0 });
      let ch = false;
      for (const [k, o] of Object.entries(s.others)) if (!o.gone && o.fin === undefined && Date.now() - (o.seen ?? 0) > 6000) { o.gone = true; s.note = `Robô ${PNAME[Number(k)]} saiu`; ch = true; }
      if (ch) publish();
    }, 700);
    const bye = () => roomRef.current?.close();
    if (Platform.OS === 'web') window.addEventListener('pagehide', bye);
    return () => { clearInterval(iv); if (Platform.OS === 'web') window.removeEventListener('pagehide', bye); };
  }, [mode]);
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
      s.frozen = Math.max(0, s.frozen - dt); s.storm = Math.max(0, s.storm - dt);
      if (W.ice && s.t >= s.stormAt) {
        s.stormAt += s.period; s.storm = 1.5;
        const inIgloo = s.objs.some(o => o.kind === 'igloo' && o.x < 60 + ROBOT - 6 && o.x + 90 > 60 + 6);
        if (inIgloo) sfx(700, 0.2, 'triangle'); else if (s.coat) { s.coat = false; sfx(600, 0.2, 'triangle'); } else { s.frozen = 1.5; s.slow = 0; sfx(300, 0.4, 'sine'); buzz(80); }
        for (const r of s.rivals) r.frozen = Math.random() < 0.55 ? 1.5 : 0;
      }
      let target: number;
      if (s.race) {
        s.slow = Math.max(0, s.slow - dt); s.boost = Math.max(0, s.boost - dt);
        target = 285 * (s.slow > 0 ? 0.5 : 1) * (s.boost > 0 ? 1.35 : 1);
        for (const r of s.rivals) { r.frozen = Math.max(0, (r.frozen ?? 0) - dt); if (!r.frozen) r.d += (r.v + Math.sin(s.t * 1.3 + r.v) * 40) * dt; }
      } else target = 260 + s.t * 6;
      if (s.frozen > 0) s.speed = 0;
      else if (W.ice) s.speed += (target - s.speed) * Math.min(1, dt * 1.5); // escorrega no gelo
      else s.speed = target;
      s.dist += s.speed * dt;
      if (s.online) {
        s.sendT -= dt; if (s.sendT <= 0) { s.sendT = 0.066; roomRef.current?.send({ t: 's', i: s.me, d: s.dist, y: s.y, z: s.frozen > 0, c: s.coat }); }
        if (s.dist >= FINISH) { s.myTime = s.t; s.finT[s.me] = s.t; roomRef.current?.send({ t: 'fin', i: s.me, time: s.t }); publish(); sfx(660, 0.15, 'triangle'); setTimeout(() => sfx(990, 0.3, 'triangle'), 160); buzz(60); setMode('podium'); force(n => n + 1); return; }
      }
      if (s.race && !s.online && s.dist >= FINISH) {
        s.place = 1 + s.rivals.filter(r => r.d >= s.dist).length;
        sfx(660, 0.15, 'triangle'); setTimeout(() => sfx(990, 0.3, 'triangle'), 160); buzz(60);
        setMode('podium'); force(n => n + 1); return;
      }
      s.vy -= GRAV * dt; s.y = Math.max(0, s.y + s.vy * dt); if (s.y === 0) s.vy = 0;
      s.next -= dt;
      if (s.online) s.next = 99;
      if (s.next <= 0) {
        const kind = pickKind(Math.random(), W);
        s.objs.push({ id: s.id++, x: width + 40, kind, y: kind === 'battery' ? (Math.random() < 0.5 ? 20 : 130) : 0 });
        s.next = 0.7 + Math.random() * 0.9 - Math.min(s.t / 120, 0.3);
      }
      const rx = 60;
      for (const o of s.objs) {
        const car = W.cars && (o.kind === 'gear' || o.kind === 'oil');
        if (s.online && !o.live) { o.x = 60 + s.track[o.id].wx - s.dist; if (car && o.x < width) o.live = true; }
        else o.x -= (s.speed + (car ? 130 : 0)) * dt;
        const w = o.kind === 'oil' ? 60 : o.kind === 'igloo' ? 90 : 40;
        const overlapX = o.x < rx + ROBOT - 10 && o.x + w > rx + 10;
        if (!overlapX || o.taken) continue;
        if (o.kind === 'igloo') continue;
        if (o.kind === 'coat') { if (s.y < 60) { o.taken = true; s.coat = true; sfx(1000, 0.15, 'triangle'); } continue; }
        if (o.kind === 'battery') {
          if (s.y + ROBOT > o.y && s.y < o.y + 40) { o.taken = true; s.score++; s.boost = 1.2; sfx(880, 0.1, 'triangle'); }
        } else if (s.y < (o.kind === 'oil' && !W.cars ? 10 : 34)) {
          sfx(200, 0.3, 'sine'); buzz(120);
          if (s.race) { o.taken = true; s.slow = 1; continue; }
          const b = Math.max(store.get(), s.score); store.set(b); setBest(b);
          setMode('over'); force(n => n + 1); return;
        }
      }
      s.objs = s.objs.filter(o => o.x > -120 && !((o.kind === 'battery' || o.kind === 'coat') && o.taken));
      if (s.race && s.dist > FINISH - 400) s.next = 99;
      force(n => n + 1);
      raf = requestAnimationFrame(loop);
    };
    raf = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(raf);
  }, [mode, width]);

  const start = (race = g.current.race) => { g.current = fresh(race); sfx(520); buzz(); setMode('play'); };
  const tap = () => {
    if (mode !== 'play') return;
    const s = g.current; buzz(15);
    if (s.y === 0 && s.frozen <= 0) { s.vy = JUMP; sfx(440, 0.12); }
  };

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
  const Extras = ({ z, c }: { z?: boolean; c?: boolean }) => (<>{c && <Text style={st.scarf}>🧣</Text>}{z && <View style={st.iceCube}><Text style={{ fontSize: 14 }}>❄️</Text></View>}</>);
  const warn = W.ice && mode === 'play' && s.stormAt - s.t < 2 && s.stormAt - s.t > 0;
  return (
    <View style={[st.root, { backgroundColor: W.sky }]}>
      <Pressable style={StyleSheet.absoluteFill} onPressIn={tap} accessibilityLabel="Toque para o Nodex pular">
        <View style={[st.sky, { backgroundColor: W.sky }]}>
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
          ) : o.kind === 'gear' ? (
            <Text key={o.id} style={[st.gear, { left: o.x, bottom: b - 4, fontSize: W.cars ? 44 : 40, transform: W.roll ? [{ rotate: `-${gearRot}` }] : [] }]}>{W.a}</Text>
          ) : o.kind === 'coat' ? (
            <Text key={o.id} style={[st.battery, { left: o.x, bottom: b + 30 }]}>🧣</Text>
          ) : o.kind === 'igloo' ? (
            <View key={o.id} style={[st.igloo, { left: o.x, bottom: b - 2 }]}><View style={st.iglooDoor} /></View>
          ) : (
            <Text key={o.id} style={[st.battery, { left: o.x, bottom: b + o.y }]}>🔋</Text>
          ); })}
          {s.race && (() => { const fx = 60 + FINISH - s.dist; return fx < width + 20 ? <View style={[st.finish, { left: fx + ROBOT, bottom: gy(FINISH) }]}><Text style={st.flag}>🏁</Text></View> : null; })()}
          {s.online && Object.entries(s.others).map(([k, o]) => { const i = Number(k); const x = 60 + (o.d - s.dist) + (i - s.me) * 26; if (o.gone || x < -80 || x > width + 80) return null; return (
            <View key={'p' + i} style={[st.robot, { left: x, bottom: gy(o.d) + o.y + i * 5, opacity: 0.85 }]}>
              <View style={st.antenna} /><View style={[st.ball, { backgroundColor: '#FFD60A' }]} />
              <View style={[st.head, { backgroundColor: PCOL[i] }]}><View style={st.eye} /><View style={st.eye} /></View>
              <View style={st.smile} /><Text style={[st.tag, { top: -40 - i * 16, color: PCOL[i] }]}>{PNAME[i]}</Text><Extras z={o.z} c={o.c} />
            </View>); })}
          {s.race && s.rivals.map((r, i) => { const x = 60 + (r.d - s.dist); if (x < -80 || x > width + 80) return null; return (
            <View key={r.name} style={[st.robot, { left: x, bottom: gy(r.d) + 4 + i * 6, opacity: 0.9, transform: [{ scale: 0.85 }] }]}>
              <View style={st.antenna} /><View style={[st.ball, { backgroundColor: '#FFD60A' }]} />
              <View style={[st.head, { backgroundColor: r.color }]}><View style={st.eye} /><View style={st.eye} /></View>
              <View style={st.smile} /><Text style={st.tag}>{r.name}</Text><Extras z={(r.frozen ?? 0) > 0} />
            </View>); })}
          <View style={[st.robot, { left: 60, bottom: gy(s.dist) + s.y, transform: s.slow > 0 && s.race ? [{ rotate: `${(1 - s.slow) * 360}deg` }] : [] }]}>
            <View style={st.antenna} /><View style={st.ball} />
            <View style={[st.head, { backgroundColor: PCOL[s.online ? s.me : 0] }]}><View style={st.eye} /><View style={st.eye} /></View>
            <View style={st.smile} />{s.online && <Text style={[st.tag, { top: -40 - s.me * 16 }]}>Você</Text>}<Extras z={s.frozen > 0} c={s.coat} />
          </View>
        </View>
      </Pressable>

      {W.ice && s.storm > 0 && mode === 'play' && <View style={st.snow} pointerEvents="none"><Text style={st.snowText}>❄️  ❄️  ❄️{'\n'}  ❄️  ❄️  ❄️{'\n'}❄️  ❄️  ❄️</Text></View>}
      {warn && <Text style={st.warn} pointerEvents="none">❄️ Tempestade! {s.coat ? '🧣 Você está protegido!' : 'Pegue a 🧣 ou entre no iglu!'}</Text>}
      <View style={st.hud} pointerEvents="box-none">
        <Text style={st.score}>🔋 {s.score}</Text>
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
                {[0, 1, 2, 3].map(i => <View key={i} style={[st.mini, { marginHorizontal: 6, backgroundColor: lv.ids.includes(i) ? PCOL[i] : '#E9ECEF' }]} />)}
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
      {mode !== 'play' && mode !== 'lobby' && mode !== 'count' && (
        <View style={st.overlay} pointerEvents="box-none">
          <View style={st.card}>
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
                      <Text style={{ fontSize: 14, fontWeight: '800', color: '#023047' }}>{p.i === s.me ? 'Você' : PNAME[p.i]}</Text>
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
            </>) : (<>
              <Text style={st.title}>{mode === 'menu' ? 'Nodex: Robô Corredor' : 'Tente de novo! 😄'}</Text>
              <Text style={st.sub}>{mode === 'menu' ? `Toque para o Nodex pular. ${WORLDS[world].tip} Baterias dão turbo!` : `O Nodex pegou ${s.score} bateria${s.score === 1 ? '' : 's'}! Recorde: ${best}`}</Text>
            </>)}
            {mode === 'menu' && <Picker />}
            {onlineAvailable() && <Pressable style={[st.btn, { backgroundColor: '#FB5607', marginBottom: 14 }]} onPress={() => { leaveRoom(); g.current = fresh(false); setLv({ view: 'choose', code: '', err: '', ids: [] }); setMode('lobby'); }}><Text style={st.btnText}>👥 Online</Text></Pressable>}
            <Pressable style={st.btn} onPress={() => { leaveRoom(); start(true); }}><Text style={st.btnText}>🏁 Corrida</Text></Pressable>
            <Pressable style={[st.btn, { backgroundColor: '#219EBC', marginTop: 14 }]} onPress={() => { leaveRoom(); start(false); }}><Text style={st.btnText}>∞ Sem fim</Text></Pressable>
          </View>
        </View>
      )}
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
  btn: { backgroundColor: '#06D6A0', borderRadius: 40, paddingVertical: 22, paddingHorizontal: 40, minWidth: 240, alignItems: 'center' },
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
  btnText: { fontSize: 28, fontWeight: '900', color: '#fff' },
});
