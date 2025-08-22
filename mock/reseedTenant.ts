import { resetTenant } from './resetTenant';
import { seedTenant } from './seedTenant';

export async function reseedTenant(tenantId: string): Promise<void> {
  await resetTenant(tenantId);
  await seedTenant(tenantId);
}

if (require.main === module) {
  const tenantId = process.argv[2] || 'design';
  reseedTenant(tenantId)
    .then(() => console.log(`Reseeded tenant ${tenantId}`))
    .catch((e) => {
      console.error(e);
      process.exit(1);
    });
}


