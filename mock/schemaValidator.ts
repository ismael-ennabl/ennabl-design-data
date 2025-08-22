import fs from 'fs';
import path from 'path';

type SchemaNode = any;

const KNOWN_PREFIXES = [
  'context.',
  'relation.',
  'helpers.arrayElement:',
  'number.int:',
  'number.float:',
  'finance.amount:',
  'date.between:'
  , 'date.afterColumn:'
];

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function validateRule(rule: SchemaNode, table: string, errors: string[], pathStr: string): void {
  if (typeof rule === 'string') {
    // Accept bare faker paths like company.name, person.fullName, etc.
    const isKnown = KNOWN_PREFIXES.some((p) => rule.startsWith(p));
    if (!isKnown && rule.includes(':') && !rule.includes('${')) {
      // Looks like a DSL but not a known prefix
      errors.push(`${pathStr}: Unknown DSL rule "${rule}"`);
    }
    // relation validation shape
    if (rule.startsWith('relation.')) {
      const parts = rule.split('.');
      if (parts.length !== 3) {
        errors.push(`${pathStr}: Invalid relation rule "${rule}"`);
      }
    }
    return;
  }

  if (isObject(rule)) {
    // array node
    if ((rule as any).type === 'array') {
      const arr = rule as any;
      if (!('items' in arr)) {
        errors.push(`${pathStr}: array must contain "items"`);
      } else {
        validateRule(arr.items, table, errors, `${pathStr}.items`);
      }
      if ('count' in arr && typeof arr.count !== 'number') {
        errors.push(`${pathStr}: array.count must be number if provided`);
      }
      if (('min' in arr) !== ('max' in arr)) {
        errors.push(`${pathStr}: array min and max must be provided together`);
      }
      return;
    }

    // object node
    if ((rule as any).type === 'object') {
      const obj = rule as any;
      if (!isObject(obj.properties)) {
        errors.push(`${pathStr}: object.properties must be an object`);
        return;
      }
      for (const [k, v] of Object.entries(obj.properties)) {
        validateRule(v, table, errors, `${pathStr}.properties.${k}`);
      }
      return;
    }

    errors.push(`${pathStr}: Unknown node type in object`);
    return;
  }

  errors.push(`${pathStr}: Unsupported rule node type`);
}

export function validateSchemaFile(filePath: string): string[] {
  const errors: string[] = [];
  const raw = fs.readFileSync(filePath, 'utf-8');
  const json = JSON.parse(raw);

  if (!json.table || typeof json.table !== 'string') {
    errors.push('$.table must be a non-empty string');
  }
  const table = json.table ?? 'unknown';

  if (!('count' in json)) {
    errors.push('$.count is required');
  } else if (typeof json.count !== 'number' && !('min' in json.count && 'max' in json.count)) {
    errors.push('$.count must be a number or an object with min and max');
  }

  if (!isObject(json.columns)) {
    errors.push('$.columns must be an object');
  } else {
    for (const [col, rule] of Object.entries(json.columns)) {
      validateRule(rule, table, errors, `$.columns.${col}`);
    }
  }

  return errors;
}

if (require.main === module) {
  const schemasDir = path.join(process.cwd(), 'mock', 'schemas');
  const entries = fs.existsSync(schemasDir) ? fs.readdirSync(schemasDir) : [];
  const jsonFiles = entries.filter((f) => f.endsWith('.json'));

  let hasErrors = false;
  for (const f of jsonFiles) {
    const full = path.join(schemasDir, f);
    const errs = validateSchemaFile(full);
    if (errs.length > 0) {
      hasErrors = true;
      console.error(`Schema validation errors in ${f}:`);
      for (const e of errs) console.error(` - ${e}`);
    } else {
      console.log(`OK: ${f}`);
    }
  }
  if (hasErrors) process.exit(1);
}


