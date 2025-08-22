## ennabl-design-data mock framework

This repo contains a declarative mock data framework to seed multi-tenant fake data into Supabase for rapid UI prototyping in `ennabl-designs` and to support `ennablux-mcp`.

### Features
- Declarative JSON schemas per table (`mock/schemas/*.json`)
- DSL for faker rules (relations, ranges, arrays/objects, dates, enums)
- Deterministic seeding by tenant (stable seed derived from `tenant_id`)
- Centralized seed/reset order configs
- Scripts: seed, reset, reseed

### Setup
1) Create `.env` with Supabase credentials:
```
SUPABASE_URL=... 
SUPABASE_KEY=...
```

2) Install deps:
```
npm install
```

3) Validate schemas:
```
npx ts-node mock/schemaValidator.ts
```

### Usage
- Seed tenant (default `design`):
```
SUPABASE_URL=... SUPABASE_KEY=... npx ts-node mock/seedTenant.ts design
```

- Reset tenant:
```
SUPABASE_URL=... SUPABASE_KEY=... npx ts-node mock/resetTenant.ts design
```

- Reseed tenant:
```
SUPABASE_URL=... SUPABASE_KEY=... npx ts-node mock/reseedTenant.ts design
```

### File layout
```
mock/
  supabaseClient.ts
  generatorEngine.ts
  schemaValidator.ts
  config/
    resetOrder.ts
    seedOrder.ts
  schemas/
    clients.json
    policies.json
    renewals.json
  seedTenant.ts
  resetTenant.ts
  reseedTenant.ts
```

### DSL Reference (examples)
- `string.uuid` → `faker.string.uuid()`
- `company.name` → `faker.company.name()`
- `number.int:10:100` → integer between 10 and 100
- `number.float:100:500:2` → float between 100 and 500 with 2 decimals
- `date.between:2024-01-01:2024-12-31` → ISO day string between dates
- `helpers.arrayElement:A:B:C` → picks one of A/B/C (supports `${...}` interpolation)
- `context.tenant_id` → inject current tenant id
- `relation.clients.id` → picks an `id` from previously generated `clients`

Array/Object columns:
```
{
  "type": "array",
  "count": 2,
  "items": { "type": "object", "properties": { "k": "company.buzzNoun" } }
}
```

### Notes
- Ensure tables in Supabase contain a `tenant_id` column.
- Seeding order must respect dependencies (configured in `mock/config/seedOrder.ts`).
- Reset order is the reverse (configured in `mock/config/resetOrder.ts`).


