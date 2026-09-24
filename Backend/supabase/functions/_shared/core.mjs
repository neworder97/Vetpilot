export class RequestError extends Error { constructor(message, status = 400) { super(message); this.status = status; } }
export const languages = ['Spanish', 'English', 'French', 'German', 'Portuguese', 'Italian', 'Chinese', 'Japanese', 'Korean', 'Arabic', 'Russian', 'Hindi'];
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
export function validateInput(body) {
  if (!body || typeof body !== 'object') throw new RequestError('Invalid request');
  if (body.action === 'transcribe') {
    if (typeof body.audio !== 'string' || body.audio.length < 16 || body.audio.length > 3_000_000 || !/^[A-Za-z0-9+/]*={0,2}$/.test(body.audio)) throw new RequestError('Invalid audio');
    if (!['en','es','fr','de','pt','it','zh','ja','ar','ko','ru','hi'].includes(body.language)) throw new RequestError('Unsupported language');
  } else if (body.action === 'draft') {
    if (typeof body.transcript !== 'string' || !body.transcript.trim() || body.transcript.length > 100_000 || typeof body.historyOnly !== 'boolean') throw new RequestError('Invalid transcript');
    if (!Array.isArray(body.patients) || body.patients.length < 1 || body.patients.length > 8) throw new RequestError('Invalid patients');
    const ids = new Set(), names = new Set();
    for (const patient of body.patients) {
      if (!uuid.test(patient.id) || typeof patient.name !== 'string' || !patient.name.trim() || patient.name.length > 80 || ids.has(patient.id.toLowerCase())) throw new RequestError('Invalid patient identity');
      ids.add(patient.id.toLowerCase());
      for (const name of [patient.name, ...(patient.aliases || '').split(',')].map(v=>v.trim().toLowerCase()).filter(Boolean)) {
        if (names.has(name)) throw new RequestError('Ambiguous patient names'); names.add(name);
      }
    }
  } else if (body.action === 'translate') {
    if (typeof body.text !== 'string' || !body.text.trim() || body.text.length > 100_000 || !languages.includes(body.language)) throw new RequestError('Invalid translation request');
  } else throw new RequestError('Unknown action');
  return body;
}
export function draftSchema(ids) {
  const text = {type:'string'};
  return {type:'object',additionalProperties:false,required:['notes','unassigned','warnings'],properties:{
    notes:{type:'array',items:{type:'object',additionalProperties:false,required:['patientID','subjective','objective','assessment','plan','evidence'],properties:{
      patientID:{type:'string',enum:ids},subjective:text,objective:text,assessment:text,plan:text,evidence:{type:'array',items:text}
    }}},unassigned:text,warnings:{type:'array',items:text}}};
}
export function validateDraft(result, body) {
  if (!result || !Array.isArray(result.notes) || result.notes.length !== body.patients.length || typeof result.unassigned !== 'string' || !Array.isArray(result.warnings) || !result.warnings.every(v=>typeof v==='string')) throw new RequestError('Invalid AI draft',502);
  const expected = new Set(body.patients.map(p=>p.id.toLowerCase())), seen = new Set();
  for (const note of result.notes) {
    const id = String(note.patientID).toLowerCase();
    if (!expected.has(id) || seen.has(id)) throw new RequestError('AI patient mismatch',502); seen.add(id);
    if (!['subjective','objective','assessment','plan'].every(k=>typeof note[k]==='string' && note[k].length<=100_000)) throw new RequestError('Invalid note',502);
    if (!Array.isArray(note.evidence) || !note.evidence.every(q=>typeof q==='string' && q.trim() && body.transcript.includes(q))) throw new RequestError('Unsupported source evidence',502);
    if ([note.subjective,note.objective,note.assessment,note.plan].some(Boolean) && note.evidence.length===0) throw new RequestError('Missing source evidence',502);
    if (body.historyOnly) { note.objective=''; note.assessment=''; note.plan=''; }
  }
  result.warnings.push('AI draft: verify source evidence, patient attribution, negations, numbers and units before finalizing.');
  return result;
}
export async function readJSON(request, maxBytes = 4_000_000) {
  if (!request.body) throw new RequestError('Missing body');
  const reader=request.body.getReader(); let length=0; const chunks=[];
  for (;;) { const {done,value}=await reader.read(); if(done)break; length+=value.byteLength; if(length>maxBytes){await reader.cancel();throw new RequestError('Request too large',413);} chunks.push(value); }
  const bytes=new Uint8Array(length); let offset=0; for(const chunk of chunks){bytes.set(chunk,offset);offset+=chunk.length;}
  try{return JSON.parse(new TextDecoder().decode(bytes));}catch{throw new RequestError('Invalid JSON');}
}

export function audioFormat(bytes) {
  if (!(bytes instanceof Uint8Array) || bytes.length < 16) throw new RequestError('Invalid audio');
  const ascii = (start, end) => new TextDecoder().decode(bytes.slice(start, end));
  if (ascii(4,8) === 'ftyp') return {type:'audio/mp4',name:'consultation.m4a'};
  if (ascii(0,4) === 'RIFF' && ascii(8,12) === 'WAVE') return {type:'audio/wav',name:'consultation.wav'};
  if ([0x1a,0x45,0xdf,0xa3].every((value,index)=>bytes[index]===value)) return {type:'audio/webm',name:'consultation.webm'};
  throw new RequestError('Unsupported audio container');
}
