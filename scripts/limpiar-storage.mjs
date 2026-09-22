// Limpia archivos viejos de Supabase Storage (para bajar el uso).
// Uso (en la carpeta clase-6to):
//   npm i @supabase/supabase-js    (una sola vez)
//
//   # 1) Simulacro (NO borra nada, solo muestra qué borraría):
//   SUPABASE_SERVICE_KEY='tu_service_role_key' node scripts/limpiar-storage.mjs
//
//   # 2) Borrar de verdad archivos de más de 14 días en posts y photos:
//   SUPABASE_SERVICE_KEY='...' DRY_RUN=0 node scripts/limpiar-storage.mjs
//
// Opcionales:
//   MAX_AGE_DAYS=7           -> borra lo de más de 7 días (default 14)
//   BUCKETS=posts,photos     -> qué buckets limpiar (default posts,photos; NO toca avatars)
//   ONLY_EXT=mp4,mov,webm    -> borra solo esas extensiones (p.ej. solo videos)
//
// La service_role key está en: Supabase → Project Settings → API → service_role (secret).
// NO la subas al repo ni la pegues en el chat.

import { createClient } from '@supabase/supabase-js';

const URL = process.env.SUPABASE_URL || 'https://qmxugyqwgptgafitbquw.supabase.co';
const KEY = process.env.SUPABASE_SERVICE_KEY;
if (!KEY) { console.error('Falta SUPABASE_SERVICE_KEY (la service_role key).'); process.exit(1); }

const DRY_RUN      = process.env.DRY_RUN !== '0';
const MAX_AGE_DAYS = parseInt(process.env.MAX_AGE_DAYS || '14', 10);
const BUCKETS      = (process.env.BUCKETS || 'posts,photos').split(',').map(s => s.trim()).filter(Boolean);
const ONLY_EXT     = (process.env.ONLY_EXT || '').split(',').map(s => s.trim().toLowerCase()).filter(Boolean);
const CUTOFF       = Date.now() - MAX_AGE_DAYS * 86400000;

const sb = createClient(URL, KEY, { auth: { persistSession: false } });

// Lista recursiva de un bucket (Storage guarda por carpetas uid/…)
async function listAll(bucket, prefix = '') {
  const out = [];
  let offset = 0;
  for (;;) {
    const { data, error } = await sb.storage.from(bucket).list(prefix, { limit: 1000, offset, sortBy: { column: 'name', order: 'asc' } });
    if (error) throw error;
    if (!data || !data.length) break;
    for (const item of data) {
      const path = prefix ? `${prefix}/${item.name}` : item.name;
      if (item.id === null && !item.metadata) { // es carpeta
        out.push(...await listAll(bucket, path));
      } else {
        out.push({ path, size: Number(item.metadata?.size || 0), created: item.created_at || item.updated_at });
      }
    }
    if (data.length < 1000) break;
    offset += 1000;
  }
  return out;
}

const human = b => (b/1048576).toFixed(1) + ' MB';

for (const bucket of BUCKETS) {
  console.log(`\n=== bucket: ${bucket} ===`);
  let files;
  try { files = await listAll(bucket); }
  catch (e) { console.error('  error listando:', e.message); continue; }
  const total = files.reduce((s,f)=>s+f.size,0);
  const toDelete = files.filter(f => {
    const old = f.created ? (new Date(f.created).getTime() < CUTOFF) : true;
    const extOk = !ONLY_EXT.length || ONLY_EXT.includes((f.path.split('.').pop()||'').toLowerCase());
    return old && extOk;
  });
  const delSize = toDelete.reduce((s,f)=>s+f.size,0);
  console.log(`  archivos: ${files.length} (${human(total)}) · a borrar: ${toDelete.length} (${human(delSize)})`);
  if (!toDelete.length) continue;
  if (DRY_RUN) { console.log('  [DRY_RUN] no se borra nada. Corré con DRY_RUN=0 para borrar.'); continue; }
  for (let i = 0; i < toDelete.length; i += 100) {
    const batch = toDelete.slice(i, i+100).map(f => f.path);
    const { error } = await sb.storage.from(bucket).remove(batch);
    if (error) console.error('  error borrando lote:', error.message);
    else console.log(`  borrados ${Math.min(i+100, toDelete.length)}/${toDelete.length}`);
  }
}
console.log('\nListo.');
