import test from 'node:test';
import assert from 'node:assert/strict';
import {audioFormat} from '../supabase/functions/_shared/core.mjs';
test('audio container detection supports native and browser recordings, rejects text',()=>{
 const bytes=new Uint8Array(32);const write=(offset,s)=>bytes.set(new TextEncoder().encode(s),offset);
 write(4,'ftyp');assert.equal(audioFormat(bytes).type,'audio/mp4');bytes.fill(0);write(0,'RIFF');write(8,'WAVE');assert.equal(audioFormat(bytes).type,'audio/wav');bytes.fill(0);bytes.set([0x1a,0x45,0xdf,0xa3]);assert.equal(audioFormat(bytes).type,'audio/webm');bytes.fill(0);assert.throws(()=>audioFormat(bytes));assert.throws(()=>audioFormat(new Uint8Array(4)));
});
