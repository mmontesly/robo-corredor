// Online race for 2-4 players via WebRTC (PeerJS public broker, no account/secrets). Web only.
// Star topology: host (player 0) relays messages between guests.
import { Platform } from 'react-native';

export type Msg =
  | { t: 'hello'; you: number } | { t: 'lobby'; ids: number[] } | { t: 'start'; seed: number; ids: number[]; w: string } | { t: 'world'; w: string }
  | { t: 's'; i: number; d: number; y: number; z?: boolean; c?: boolean; g?: boolean; sp?: boolean } | { t: 'fin'; i: number; time: number } | { t: 'left'; i: number } | { t: 'podium'; order: number[]; gone: number[] } | { t: 'full' } | { t: 'pw'; i: number; k: 'rocket' | 'oil'; to: number; at: number } | { t: 'nick'; i: number; n: string } | { t: 'nicks'; map: Record<number, string> };
export type Room = { code: string; me: number; isHost: boolean; send: (m: Msg) => void; close: () => void; ids: () => number[]; lock: () => void };
export type Handlers = { onMsg: (m: Msg) => void; onClose: () => void };

export const MAX = 4;
const PREFIX = 'nodex-robocorredor-v1-';
export const onlineAvailable = () => Platform.OS === 'web' && typeof window !== 'undefined' && 'RTCPeerConnection' in window;
const makePeer = async (id?: string): Promise<any> => { const { default: Peer } = await import('peerjs'); return id ? new Peer(id) : new Peer(); };

export async function createRoom(h: Handlers, tries = 5): Promise<Room> {
  const code = String(1000 + Math.floor(Math.random() * 9000));
  const peer = await makePeer(PREFIX + code);
  const conns = new Map<number, any>();
  let locked = false;
  const ids = () => [0, ...conns.keys()].sort();
  const bcast = (m: Msg, except?: number) => conns.forEach((c, i) => { if (i !== except && c.open) c.send(m); });
  return new Promise((resolve, reject) => {
    let opened = false;
    peer.on('open', () => { opened = true; resolve({ code, me: 0, isHost: true, ids, lock: () => { locked = true; }, send: m => bcast(m), close: () => { try { peer.destroy(); } catch {} } }); });
    peer.on('error', (e: any) => {
      if (opened) return;
      if (e?.type === 'unavailable-id' && tries > 0) { peer.destroy(); createRoom(h, tries - 1).then(resolve, reject); } else reject(e?.type || 'erro');
    });
    peer.on('connection', (c: any) => {
      c.on('open', () => {
        const free = [1, 2, 3].find(i => !conns.has(i));
        if (locked || free === undefined) { c.send({ t: 'full' }); setTimeout(() => c.close(), 500); return; }
        conns.set(free, c);
        c.send({ t: 'hello', you: free });
        const l: Msg = { t: 'lobby', ids: ids() }; bcast(l); h.onMsg(l);
        c.on('data', (d: any) => { h.onMsg(d); bcast(d, free); });
        const gone = () => { if (!conns.has(free)) return; conns.delete(free); const m: Msg = { t: 'left', i: free }; bcast(m); h.onMsg(m); if (!locked) { const l2: Msg = { t: 'lobby', ids: ids() }; bcast(l2); h.onMsg(l2); } };
        c.on('close', gone); c.on('error', gone);
      });
    });
    peer.on('disconnected', () => { try { peer.reconnect(); } catch {} });
  });
}

export async function joinRoom(code: string, h: Handlers): Promise<Room> {
  const peer = await makePeer();
  return new Promise((resolve, reject) => {
    const fail = (e: string) => { try { peer.destroy(); } catch {} reject(e); };
    const timer = setTimeout(() => fail('timeout'), 15000);
    peer.on('error', (e: any) => { clearTimeout(timer); fail(e?.type || 'erro'); });
    peer.on('open', () => {
      const c = peer.connect(PREFIX + code, { reliable: true });
      let me = -1, cur: number[] = [];
      c.on('data', (d: any) => {
        if (d.t === 'full') { clearTimeout(timer); return fail('full'); }
        if (d.t === 'hello') { me = d.you; clearTimeout(timer); resolve({ code, me, isHost: false, ids: () => cur, lock: () => {}, send: m => c.open && c.send(m), close: () => { try { c.close(); peer.destroy(); } catch {} } }); return; }
        if (d.t === 'lobby' || d.t === 'start') cur = d.ids;
        h.onMsg(d);
      });
      c.on('close', () => h.onClose());
    });
  });
}

export function rng(seed: number) {
  return () => { seed |= 0; seed = (seed + 0x6d2b79f5) | 0; let t = Math.imul(seed ^ (seed >>> 15), 1 | seed); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
}
