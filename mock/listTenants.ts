import 'dotenv/config';
import { supabase } from './supabaseClient';

async function listDistinct(table: string): Promise<string[]> {
  const { data, error } = await supabase
    .from(table)
    .select('tenant_id', { count: 'exact', head: false })
    .neq('tenant_id', null);
  if (error) throw new Error(`${table}: ${error.message}`);
  const set = new Set<string>();
  for (const row of (data as any[])) {
    if (row.tenant_id) set.add(row.tenant_id);
  }
  return Array.from(set);
}

async function main(): Promise<void> {
  const tables = ['clients', 'policies', 'renewals'];
  const perTable: Record<string, string[]> = {};
  const all = new Set<string>();

  for (const t of tables) {
    try {
      const tenants = await listDistinct(t);
      perTable[t] = tenants;
      tenants.forEach((x) => all.add(x));
    } catch (e: any) {
      perTable[t] = [];
      console.error(`Error reading ${t}: ${e.message}`);
    }
  }

  console.log('Distinct tenants across tables:', Array.from(all));
  for (const t of tables) {
    console.log(`${t}:`, perTable[t]);
  }
}

if (require.main === module) {
  main().catch((e) => {
    console.error(e);
    process.exit(1);
  });
}


