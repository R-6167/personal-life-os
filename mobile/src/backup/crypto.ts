/**
 * Passphrase-protected backup encryption (offline, pure JS + expo-crypto).
 * Keystream: SHA-256(passphrase || salt || blockIndex)
 * MAC: SHA-256(passphrase || salt || "mac" || ciphertext)
 */

import * as ExpoCrypto from 'expo-crypto';

function bytesToHex(bytes: Uint8Array): string {
  return Array.from(bytes)
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

function hexToBytes(hex: string): Uint8Array {
  const out = new Uint8Array(hex.length / 2);
  for (let i = 0; i < out.length; i++) out[i] = parseInt(hex.substr(i * 2, 2), 16);
  return out;
}

function bytesToBase64(bytes: Uint8Array): string {
  let s = '';
  for (let i = 0; i < bytes.length; i++) s += String.fromCharCode(bytes[i]);
  if (typeof btoa !== 'undefined') return btoa(s);
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  let out = '';
  for (let i = 0; i < bytes.length; i += 3) {
    const a = bytes[i];
    const b = i + 1 < bytes.length ? bytes[i + 1] : 0;
    const c = i + 2 < bytes.length ? bytes[i + 2] : 0;
    out += chars[a >> 2];
    out += chars[((a & 3) << 4) | (b >> 4)];
    out += i + 1 < bytes.length ? chars[((b & 15) << 2) | (c >> 6)] : '=';
    out += i + 2 < bytes.length ? chars[c & 63] : '=';
  }
  return out;
}

function base64ToBytes(b64: string): Uint8Array {
  if (typeof atob !== 'undefined') {
    const s = atob(b64);
    const out = new Uint8Array(s.length);
    for (let i = 0; i < s.length; i++) out[i] = s.charCodeAt(i);
    return out;
  }
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  const clean = b64.replace(/[^A-Za-z0-9+/]/g, '');
  const out: number[] = [];
  for (let i = 0; i < clean.length; i += 4) {
    const a = chars.indexOf(clean[i]);
    const b = chars.indexOf(clean[i + 1]);
    const c = chars.indexOf(clean[i + 2] ?? 'A');
    const d = chars.indexOf(clean[i + 3] ?? 'A');
    out.push((a << 2) | (b >> 4));
    if (clean[i + 2] && clean[i + 2] !== '=') out.push(((b & 15) << 4) | (c >> 2));
    if (clean[i + 3] && clean[i + 3] !== '=') out.push(((c & 3) << 6) | d);
  }
  return new Uint8Array(out);
}

async function randomBytes(n: number): Promise<Uint8Array> {
  try {
    const arr = await ExpoCrypto.getRandomBytesAsync(n);
    return arr instanceof Uint8Array ? arr : new Uint8Array(arr as ArrayBuffer);
  } catch {
    const h = await ExpoCrypto.digestStringAsync(
      ExpoCrypto.CryptoDigestAlgorithm.SHA256,
      `${Date.now()}-${Math.random()}-${n}`,
      { encoding: ExpoCrypto.CryptoEncoding.HEX }
    );
    return hexToBytes(h).subarray(0, n);
  }
}

async function sha256Hex(input: string): Promise<string> {
  return ExpoCrypto.digestStringAsync(
    ExpoCrypto.CryptoDigestAlgorithm.SHA256,
    input,
    { encoding: ExpoCrypto.CryptoEncoding.HEX }
  );
}

async function keystream(passphrase: string, saltHex: string, length: number): Promise<Uint8Array> {
  const out = new Uint8Array(length);
  let offset = 0;
  let block = 0;
  while (offset < length) {
    const h = await sha256Hex(`${passphrase}:${saltHex}:${block}`);
    const chunk = hexToBytes(h);
    const take = Math.min(chunk.length, length - offset);
    out.set(chunk.subarray(0, take), offset);
    offset += take;
    block += 1;
  }
  return out;
}

export type EncryptedPayload = {
  v: 1;
  alg: 'XOR-SHA256-STREAM';
  salt: string;
  mac: string;
  ct: string;
};

export async function encryptString(plaintext: string, passphrase: string): Promise<EncryptedPayload> {
  if (!passphrase || passphrase.length < 4) {
    throw new Error('Passphrase must be at least 4 characters');
  }
  const salt = bytesToHex(await randomBytes(16));
  const pt =
    typeof TextEncoder !== 'undefined'
      ? new TextEncoder().encode(plaintext)
      : Uint8Array.from(plaintext.split('').map((c) => c.charCodeAt(0)));
  const ks = await keystream(passphrase, salt, pt.length);
  const ct = new Uint8Array(pt.length);
  for (let i = 0; i < pt.length; i++) ct[i] = pt[i] ^ ks[i];
  const ctB64 = bytesToBase64(ct);
  const mac = await sha256Hex(`${passphrase}:${salt}:mac:${ctB64}`);
  return { v: 1, alg: 'XOR-SHA256-STREAM', salt, mac, ct: ctB64 };
}

export async function decryptString(payload: EncryptedPayload, passphrase: string): Promise<string> {
  if (payload.v !== 1 || payload.alg !== 'XOR-SHA256-STREAM') {
    throw new Error('Unsupported backup format');
  }
  const expectedMac = await sha256Hex(`${passphrase}:${payload.salt}:mac:${payload.ct}`);
  if (expectedMac !== payload.mac) {
    throw new Error('Wrong passphrase or corrupted backup');
  }
  const ct = base64ToBytes(payload.ct);
  const ks = await keystream(passphrase, payload.salt, ct.length);
  const pt = new Uint8Array(ct.length);
  for (let i = 0; i < ct.length; i++) pt[i] = ct[i] ^ ks[i];
  if (typeof TextDecoder !== 'undefined') {
    return new TextDecoder().decode(pt);
  }
  return String.fromCharCode(...Array.from(pt));
}
