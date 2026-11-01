// 50 skins desenhadas no código (acessórios divertidos). Desbloqueio só jogando o Modo História.
import React from 'react';
import { Text, View } from 'react-native';

export type Skin = { name: string; top?: string; face?: string; hand?: string; feet?: string; color?: string; special?: 'moto' | 'guerreiro' | 'pirata' | 'bigode' | 'listras' | 'rainbow' | 'gold' | 'prata' };
export const SKINS: Skin[] = [
  { name: 'Clássico' }, { name: 'Boné', top: '🧢' }, { name: 'Óculos escuros', face: '🕶️' }, { name: 'Tênis', feet: '👟' }, { name: 'Sorvete', hand: '🍦' },
  { name: 'Capacete de moto', special: 'moto' }, { name: 'Capacete de guerreiro', special: 'guerreiro' }, { name: 'Coroa', top: '👑' }, { name: 'Chapéu de pirata', special: 'pirata' }, { name: 'Cartola', top: '🎩' },
  { name: 'Formatura', top: '🎓' }, { name: 'Chapéu de sol', top: '👒' }, { name: 'Laço', top: '🎀' }, { name: 'Fones', top: '🎧' }, { name: 'Balão', hand: '🎈' },
  { name: 'Pirulito', hand: '🍭' }, { name: 'Pizza', hand: '🍕' }, { name: 'Flor', top: '🌸' }, { name: 'Estrela', top: '⭐' }, { name: 'Arco-íris', top: '🌈' },
  { name: 'Mergulhador', face: '🤿' }, { name: 'Óculos de nerd', face: '👓' }, { name: 'Coração', top: '💖' }, { name: 'Bigodão', special: 'bigode' }, { name: 'Patins', feet: '🛼' },
  { name: 'Botas', feet: '🥾' }, { name: 'Chinelos', feet: '🩴' }, { name: 'Skate', feet: '🛹' }, { name: 'Guitarra', hand: '🎸' }, { name: 'Bola', hand: '⚽' },
  { name: 'Pipoca', hand: '🍿' }, { name: 'Cupcake', hand: '🧁' }, { name: 'Dino amigo', top: '🦖' }, { name: 'Gatinho', top: '🐱' }, { name: 'Pintinho', top: '🐥' },
  { name: 'Polvo', top: '🐙' }, { name: 'Unicórnio', top: '🦄' }, { name: 'Abacaxi', top: '🍍' }, { name: 'Cogumelo', top: '🍄' }, { name: 'Planeta', top: '🪐' },
  { name: 'Foguete', hand: '🚀' }, { name: 'Raio', top: '⚡' }, { name: 'Floco de neve', top: '❄️' }, { name: 'Azul-bebê', color: '#A0E7E5' }, { name: 'Menta', color: '#B9FBC0' },
  { name: 'Lilás', color: '#CDB4DB' }, { name: 'Listrado', special: 'listras' }, { name: 'Arco-íris', special: 'rainbow' }, { name: 'Prata', color: '#DEE2E6', special: 'prata' }, { name: 'Dourado brilhante', color: '#FFD60A', special: 'gold' },
];
export const FREE_SKINS = 5;
const R = 56;
const P = { position: 'absolute' as const };

export function RobotBody({ color, skin = 0, t = 0, ball = '#FB5607', dim }: { color: string; skin?: number; t?: number; ball?: string; dim?: boolean }) {
  const k = SKINS[skin] ?? SKINS[0];
  const body = k.color ?? color;
  const shine = k.special === 'gold' || k.special === 'prata';
  return (
    <>
      <View style={{ ...P, top: -14, width: 4, height: 14, backgroundColor: '#023047' }} />
      <View style={{ ...P, top: -22, width: 12, height: 12, borderRadius: 6, backgroundColor: shine ? '#FFF3B0' : ball }} />
      <View style={{ width: R, height: R, borderRadius: 14, backgroundColor: dim ? '#000' : body, flexDirection: 'row', justifyContent: 'space-evenly', paddingTop: 12, borderWidth: 3, borderColor: k.special === 'gold' ? '#E09F3E' : '#023047', overflow: 'hidden' }}>
        {k.special === 'listras' && [0, 1, 2].map(i => <View key={i} style={{ ...P, left: 0, right: 0, top: 6 + i * 16, height: 7, backgroundColor: '#FFFFFF88' }} />)}
        {k.special === 'rainbow' && ['#FF595E', '#FFCA3A', '#8AC926', '#1982C4', '#6A4C93'].map((c, i) => <View key={c} style={{ ...P, left: 0, right: 0, top: i * 11, height: 11, backgroundColor: c }} />)}
        {shine && <View style={{ ...P, left: 6 + ((t * 60) % 60) - 10, top: -10, width: 10, height: 80, backgroundColor: '#FFFFFFAA', transform: [{ rotate: '25deg' }] }} />}
        <View style={{ width: 12, height: 12, borderRadius: 6, backgroundColor: '#023047' }} /><View style={{ width: 12, height: 12, borderRadius: 6, backgroundColor: '#023047' }} />
      </View>
      <View style={{ ...P, bottom: 12, width: 22, height: 8, borderBottomLeftRadius: 10, borderBottomRightRadius: 10, backgroundColor: '#023047' }} />
      {!dim && <Acc k={k} />}
    </>
  );
}

function Acc({ k }: { k: Skin }) {
  const e = (s: string, st: object) => <Text style={{ ...P, ...st }}>{s}</Text>;
  return (
    <>
      {k.special === 'moto' && <View style={{ ...P, top: -10, left: -6, width: R + 12, height: 36, borderTopLeftRadius: 30, borderTopRightRadius: 30, backgroundColor: '#E63946', borderWidth: 3, borderColor: '#023047' }}><View style={{ ...P, top: 14, left: 8, right: 8, height: 10, borderRadius: 5, backgroundColor: '#90E0EF' }} /></View>}
      {k.special === 'guerreiro' && <>
        <View style={{ ...P, top: -12, left: -4, width: R + 8, height: 26, borderTopLeftRadius: 26, borderTopRightRadius: 26, backgroundColor: '#ADB5BD', borderWidth: 3, borderColor: '#023047' }} />
        <View style={{ ...P, top: -26, left: -10, width: 14, height: 22, borderTopLeftRadius: 14, backgroundColor: '#FFF3B0', borderWidth: 2, borderColor: '#023047', transform: [{ rotate: '-20deg' }] }} />
        <View style={{ ...P, top: -26, right: -10, width: 14, height: 22, borderTopRightRadius: 14, backgroundColor: '#FFF3B0', borderWidth: 2, borderColor: '#023047', transform: [{ rotate: '20deg' }] }} />
      </>}
      {k.special === 'pirata' && <View style={{ ...P, top: -24, left: -10, width: R + 20, height: 24, borderTopLeftRadius: 36, borderTopRightRadius: 36, backgroundColor: '#212529' }}><Text style={{ textAlign: 'center', color: '#fff', fontSize: 12, marginTop: 4 }}>☠︎</Text></View>}
      {k.special === 'bigode' && <View style={{ ...P, top: 30, width: 34, height: 9, borderRadius: 6, backgroundColor: '#6F4518' }} />}
      {k.special === 'gold' && e('✨', { top: -36, right: -16, fontSize: 22 })}
      {k.top && e(k.top, { top: -40, fontSize: 30 })}
      {k.face && e(k.face, { top: 4, fontSize: 30 })}
      {k.hand && e(k.hand, { top: 18, right: -24, fontSize: 26 })}
      {k.feet && e(k.feet, { bottom: -16, fontSize: 22 })}
    </>
  );
}
