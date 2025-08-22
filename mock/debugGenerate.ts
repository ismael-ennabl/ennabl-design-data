import path from 'path';
import { faker } from '@faker-js/faker';
import { GeneratorEngine, stableSeedFromTenant, type GenerationContext } from './generatorEngine';

async function main() {
  const schemasDir = path.join(process.cwd(), 'mock', 'schemas');
  const engine = new GeneratorEngine(schemasDir);
  const tenantId = 'design';
  const context: GenerationContext = { tenantId, cache: {}, seed: stableSeedFromTenant(tenantId) };
  faker.seed(context.seed);
  const clients = engine.loadSchema('clients');
  const rows = await engine.generateTable({ ...clients, count: 5 }, context);
  console.log(rows.map(r => r.phone));
}

main().catch((e) => { console.error(e); process.exit(1); });


