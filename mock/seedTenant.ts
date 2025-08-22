import path from 'path';
import { supabase } from './supabaseClient';
import { GeneratorEngine, stableSeedFromTenant, type GenerationContext } from './generatorEngine';
import { SEED_ORDER } from './config/seedOrder';
import { validateSchemaFile } from './schemaValidator';
import fs from 'fs';
import { faker } from '@faker-js/faker';

export async function seedTenant(tenantId: string): Promise<void> {
  const schemasDir = path.join(process.cwd(), 'mock', 'schemas');
  const engine = new GeneratorEngine(schemasDir);
  const context: GenerationContext = {
    tenantId,
    cache: {} as Record<string, any[]>,
    seed: stableSeedFromTenant(tenantId)
  };
  faker.seed(context.seed);

  // Validate schemas referenced by seed order
  for (const table of SEED_ORDER) {
    const file = path.join(schemasDir, `${table}.json`);
    if (!fs.existsSync(file)) throw new Error(`Missing schema file: ${file}`);
    const errs = validateSchemaFile(file);
    if (errs.length) {
      throw new Error(`Schema ${table}.json invalid:\n${errs.map((e) => ` - ${e}`).join('\n')}`);
    }
  }

  // Generate and insert
  for (const table of SEED_ORDER) {
    const schema = engine.loadSchema(table);
    const rows = await engine.generateTable(schema, context);
    if (rows.length === 0) continue;
    // Insert and fetch generated rows (e.g., identity bigint ids)
    const { data, error } = await supabase.from(schema.table).insert(rows).select();
    if (error) {
      throw new Error(`Insert failed for ${schema.table}: ${error.message}`);
    }
    // Replace cache with DB-returned rows to get real IDs for relations
    if (Array.isArray(data)) {
      context.cache[schema.table] = data as any[];
    }
    console.log(`Inserted ${rows.length} rows into ${schema.table} for tenant ${tenantId}`);
  }
}

if (require.main === module) {
  const tenantId = process.argv[2] || 'design';
  seedTenant(tenantId)
    .then(() => console.log(`Seeded tenant ${tenantId}`))
    .catch((e) => {
      console.error(e);
      process.exit(1);
    });
}


