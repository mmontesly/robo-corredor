import React, { useEffect, useRef, useState } from 'react';
import { Platform, Pressable, StyleSheet, Text, View, useWindowDimensions } from 'react-native';
import * as Haptics from 'expo-haptics';

type Obj = { id: number; x: number; kind: 'gear' | 'oil' | 'battery'; y: number; taken?: boolean };
type Mode = 'menu' | 'play' | 'over';

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

export default function App() {
  const { width, height } = useWindowDimensions();
  const [mode, setMode] = useState<Mode>('menu');
  const [muted, setMuted] = useState(false);
  const [best, setBest] = useState(0);
  const [, force] = useState(0);
  const g = useRef({ y: 0, vy: 0, objs: [] as Obj[], score: 0, speed: 260, dist: 0, next: 1.2, id: 0, t: 0 });
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
      const s = g.current; s.t += dt;
      s.speed = 260 + s.t * 6;
      s.vy -= GRAV * dt; s.y = Math.max(0, s.y + s.vy * dt); if (s.y === 0) s.vy = 0;
      s.next -= dt;
      if (s.next <= 0) {
        const r = Math.random();
        const kind: Obj['kind'] = r < 0.35 ? 'gear' : r < 0.6 ? 'oil' : 'battery';
        s.objs.push({ id: s.id++, x: width + 40, kind, y: kind === 'battery' ? (Math.random() < 0.5 ? 20 : 130) : 0 });
        s.next = 0.7 + Math.random() * 0.9 - Math.min(s.t / 120, 0.3);
      }
      const rx = 60;
      for (const o of s.objs) {
        o.x -= s.speed * dt;
        const w = o.kind === 'oil' ? 60 : 40;
        const overlapX = o.x < rx + ROBOT - 10 && o.x + w > rx + 10;
        if (!overlapX || o.taken) continue;
        if (o.kind === 'battery') {
          if (s.y + ROBOT > o.y && s.y < o.y + 40) { o.taken = true; s.score++; sfx(880, 0.1, 'triangle'); }
        } else if (s.y < (o.kind === 'oil' ? 10 : 34)) {
          sfx(200, 0.3, 'sine'); buzz(120);
          const b = Math.max(store.get(), s.score); store.set(b); setBest(b);
          setMode('over'); force(n => n + 1); return;
        }
      }
      s.objs = s.objs.filter(o => o.x > -80 && !(o.kind === 'battery' && o.taken));
      force(n => n + 1);
      raf = requestAnimationFrame(loop);
    };
    raf = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(raf);
  }, [mode, width]);

  const start = () => { g.current = { y: 0, vy: 0, objs: [], score: 0, speed: 260, dist: 0, next: 1.2, id: 0, t: 0 }; sfx(520); buzz(); setMode('play'); };
  const tap = () => {
    if (mode !== 'play') return start();
    const s = g.current; buzz(15);
    if (s.y === 0) { s.vy = JUMP; sfx(440, 0.12); }
  };

  const s = g.current;
  const gearRot = `${(s.t * 360) % 360}deg`;
  return (
    <View style={st.root}>
      <Pressable style={StyleSheet.absoluteFill} onPressIn={tap} accessibilityLabel="Toque para o Nodex pular">
        <View style={st.sky}>
          {[0, 1, 2, 3].map(i => (
            <View key={i} style={[st.machine, { left: ((i * 160 - s.t * 40) % (width + 160) + width + 160) % (width + 160) - 120, height: 90 + (i % 2) * 60, backgroundColor: ['#8ECAE6', '#A0C4FF', '#BDB2FF', '#9BF6FF'][i] }]} />
          ))}
          <View style={[st.belt, { height: GROUND }]}>
            <Text style={st.beltText}>▸ ▸ ▸ ▸ ▸ ▸ ▸ ▸ ▸ ▸ ▸ ▸</Text>
          </View>
          {s.objs.map(o => o.kind === 'oil' ? (
            <View key={o.id} style={[st.oil, { left: o.x, bottom: GROUND - 6 }]} />
          ) : o.kind === 'gear' ? (
            <Text key={o.id} style={[st.gear, { left: o.x, bottom: GROUND - 4, transform: [{ rotate: `-${gearRot}` }] }]}>⚙️</Text>
          ) : (
            <Text key={o.id} style={[st.battery, { left: o.x, bottom: GROUND + o.y }]}>🔋</Text>
          ))}
          <View style={[st.robot, { left: 60, bottom: GROUND + s.y }]}>
            <View style={st.antenna} /><View style={st.ball} />
            <View style={st.head}><View style={st.eye} /><View style={st.eye} /></View>
            <View style={st.smile} />
          </View>
        </View>
      </Pressable>

      <View style={st.hud} pointerEvents="box-none">
        <Text style={st.score}>🔋 {s.score}</Text>
        <Text style={st.best}>Recorde: {best}</Text>
        <Pressable style={st.mute} onPress={() => setMuted(m => !m)} accessibilityLabel={muted ? 'Ligar som' : 'Desligar som'}>
          <Text style={{ fontSize: 30 }}>{muted ? '🔇' : '🔊'}</Text>
        </Pressable>
      </View>

      {mode !== 'play' && (
        <View style={st.overlay} pointerEvents="box-none">
          <View style={st.card}>
            <Text style={st.title}>{mode === 'menu' ? 'Nodex: Robô Corredor' : 'Tente de novo! 😄'}</Text>
            <Text style={st.sub}>{mode === 'menu' ? 'Toque na tela para o Nodex pular as engrenagens e o óleo. Pegue baterias!' : `O Nodex pegou ${s.score} bateria${s.score === 1 ? '' : 's'}! Recorde: ${best}`}</Text>
            <Pressable style={st.btn} onPress={start}><Text style={st.btnText}>{mode === 'menu' ? '▶ Jogar' : '↻ Jogar de novo'}</Text></Pressable>
          </View>
        </View>
      )}
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
  btnText: { fontSize: 28, fontWeight: '900', color: '#fff' },
});
