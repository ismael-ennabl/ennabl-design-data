import { supabase } from './supabaseClient';
import { RESET_ORDER } from './config/resetOrder';

export async function resetTenant(tenantId: string): Promise<void> {
  for (const table of RESET_ORDER) {
    const { error } = await supabase
      .from(table)
      .delete()
      .eq('tenant_id', tenantId);
    if (error) {
      throw new Error(`Reset failed for ${table}: ${error.message}`);
    }
    console.log(`Deleted rows from ${table} for tenant ${tenantId}`);
  }
}

if (require.main === module) {
  const tenantId = process.argv[2] || 'design';
  resetTenant(tenantId)
    .then(() => console.log(`Reset tenant ${tenantId}`))
    .catch((e) => {
      console.error(e);
      process.exit(1);
    });
}


