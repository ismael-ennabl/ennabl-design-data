import fs from 'fs';
import path from 'path';
import { faker } from '@faker-js/faker';

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
  , 'string.numeric:'
];

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function validateRule(rule: SchemaNode, table: string, errors: string[], pathStr: string): void {
  if (typeof rule === 'string') {
    validateStringRule(rule, errors, pathStr);
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

    // object node (support both properties and fields)
    if ((rule as any).type === 'object') {
      const obj = rule as any;
      const props = isObject(obj.properties) ? obj.properties : (isObject(obj.fields) ? obj.fields : undefined);
      const label = isObject(obj.properties) ? 'properties' : (isObject(obj.fields) ? 'fields' : undefined);
      if (!props || !label) {
        errors.push(`${pathStr}: object must define either properties or fields object`);
        return;
      }
      for (const [k, v] of Object.entries(props)) {
        validateRule(v, table, errors, `${pathStr}.${label}.${k}`);
      }
      return;
    }

    errors.push(`${pathStr}: Unknown node type in object`);
    return;
  }

  errors.push(`${pathStr}: Unsupported rule node type`);
}

function validateStringRule(rule: string, errors: string[], pathStr: string) {
  const isKnown = KNOWN_PREFIXES.some((p) => rule.startsWith(p));
  if (!isKnown && rule.includes(':') && !rule.includes('${')) {
    const [methodPath] = rule.split(':');
    const fn = methodPath.split('.').reduce<any>((acc, k) => (acc ? acc[k] : undefined), faker);
    if (typeof fn !== 'function') {
      errors.push(`${pathStr}: Unknown DSL rule or faker path "${rule}"`);
    }
  }

  if (rule.startsWith('relation.')) {
    const parts = rule.split('.');
    if (parts.length !== 3) {
      errors.push(`${pathStr}: Invalid relation rule "${rule}"`);
    }
  }

  if (rule.startsWith('helpers.arrayElement:')) {
    const args = rule.split(':').slice(1);
    if (args.length === 0) {
      errors.push(`${pathStr}: helpers.arrayElement requires values`);
    }
  }

  if (rule.startsWith('number.int:')) {
    const [, minStr, maxStr] = rule.split(':');
    if (isNaN(Number(minStr)) || isNaN(Number(maxStr))) {
      errors.push(`${pathStr}: number.int requires numeric min and max`);
    }
  }

  if (rule.startsWith('number.float:')) {
    const [, minStr, maxStr, decStr] = rule.split(':');
    if (isNaN(Number(minStr)) || isNaN(Number(maxStr)) || (decStr && isNaN(Number(decStr)))) {
      errors.push(`${pathStr}: number.float requires numeric min, max, and optional decimals`);
    }
  }

  if (rule.startsWith('string.numeric:')) {
    const [, lenStr] = rule.split(':');
    if (isNaN(Number(lenStr))) {
      errors.push(`${pathStr}: string.numeric requires a numeric length`);
    }
  }

  if (rule.startsWith('date.between:')) {
    const [, startStr, endStr] = rule.split(':');
    if (!isValidDate(startStr) || !isValidDate(endStr)) {
      errors.push(`${pathStr}: date.between requires valid ISO dates`);
    }
  }

  if (rule.startsWith('date.afterColumn:')) {
    const [, column, minStr, maxStr] = rule.split(':');
    if (!column) {
      errors.push(`${pathStr}: date.afterColumn requires a base column name`);
    }
    if ((minStr && isNaN(Number(minStr))) || (maxStr && isNaN(Number(maxStr)))) {
      errors.push(`${pathStr}: date.afterColumn min/max must be numeric if provided`);
    }
  }
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

function isValidDate(s: string | undefined): boolean {
  if (!s) return false;
  const d = new Date(s);
  return !Number.isNaN(d.getTime());
}


