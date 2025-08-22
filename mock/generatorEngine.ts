import { faker } from '@faker-js/faker';
import fs from 'fs';
import path from 'path';

export type SchemaColumnRule = string | SchemaArrayNode | SchemaObjectNode;

export interface SchemaArrayNode {
  type: 'array';
  items: SchemaColumnRule; // rule string or nested object/array
  count?: number; // fixed count
  min?: number; // variable count lower bound
  max?: number; // variable count upper bound
}

export interface SchemaObjectNode {
  type: 'object';
  properties: Record<string, SchemaColumnRule>;
}

export interface TableSchema {
  table: string;
  count: number | { min: number; max: number };
  columns: Record<string, SchemaColumnRule>;
}

export interface GenerationContext {
  tenantId: string;
  cache: Record<string, any[]>; // table -> generated rows
  seed?: number; // deterministic seed
}

export class GeneratorEngine {
  private readonly schemasDir: string;

  constructor(schemasDir: string) {
    this.schemasDir = schemasDir;
  }

  public loadSchema(table: string): TableSchema {
    const filePath = path.join(this.schemasDir, `${table}.json`);
    const content = fs.readFileSync(filePath, 'utf-8');
    const schema = JSON.parse(content) as TableSchema;
    if (!schema || schema.table !== table) {
      throw new Error(`Schema for table "${table}" is invalid or mismatched`);
    }
    return schema;
  }

  public async generateTable(schema: TableSchema, context: GenerationContext): Promise<any[]> {
    const count = typeof schema.count === 'number'
      ? schema.count
      : faker.number.int({ min: schema.count.min, max: schema.count.max });

    const rows: any[] = [];
    for (let i = 0; i < count; i += 1) {
      const row: any = {};
      for (const [columnName, rule] of Object.entries(schema.columns)) {
        row[columnName] = this.evaluateRule(rule, context, row);
      }
      rows.push(row);
    }
    // store in cache for relations
    context.cache[schema.table] = rows;
    return rows;
  }

  private evaluateRule(rule: SchemaColumnRule, context: GenerationContext, row?: Record<string, any>): any {
    if (typeof rule === 'string') {
      return this.evaluateStringRule(rule, context, row);
    }
    if ((rule as SchemaArrayNode).type === 'array') {
      const arrNode = rule as SchemaArrayNode;
      const count = typeof arrNode.count === 'number'
        ? arrNode.count
        : faker.number.int({ min: arrNode.min ?? 1, max: arrNode.max ?? 5 });
      const items: any[] = [];
      for (let i = 0; i < count; i += 1) {
        items.push(this.evaluateRule(arrNode.items, context, row));
      }
      return items;
    }
    if ((rule as SchemaObjectNode).type === 'object') {
      const objNode = rule as SchemaObjectNode;
      const obj: Record<string, any> = {};
      for (const [k, v] of Object.entries(objNode.properties)) {
        obj[k] = this.evaluateRule(v, context, row);
      }
      return obj;
    }
    throw new Error(`Unsupported rule node: ${JSON.stringify(rule)}`);
  }

  private evaluateStringRule(rule: string, context: GenerationContext, row?: Record<string, any>): any {
    // Generic template interpolation across entire string
    if (rule.includes('${')) {
      return this.interpolateToken(rule, context, row);
    }
    // context.
    if (rule === 'context.tenant_id') {
      return context.tenantId;
    }

    // relation.table.column
    if (rule.startsWith('relation.')) {
      const parts = rule.split('.');
      if (parts.length !== 3) throw new Error(`Invalid relation rule: ${rule}`);
      const [, table, column] = parts;
      const rows = context.cache[table];
      if (!rows || rows.length === 0) {
        throw new Error(`Relation requested before table generated: ${table}`);
      }
      const picked = faker.helpers.arrayElement(rows);
      return picked[column];
    }

    // helpers.arrayElement:val1:val2:val3 (with interpolation support)
    if (rule.startsWith('helpers.arrayElement:')) {
      const rawVals = rule.replace('helpers.arrayElement:', '').split(':');
      const resolvedVals = rawVals.map((t) => this.interpolateToken(t, context, row));
      return faker.helpers.arrayElement(resolvedVals);
    }

    // number.int:min:max
    if (rule.startsWith('number.int:')) {
      const [, minStr, maxStr] = rule.split(':');
      return faker.number.int({ min: Number(minStr), max: Number(maxStr) });
    }

    // number.int (no args)
    if (rule === 'number.int') {
      return faker.number.int();
    }

    // number.float:min:max:decimals
    if (rule.startsWith('number.float:')) {
      const [, minStr, maxStr, decStr] = rule.split(':');
      const min = Number(minStr);
      const max = Number(maxStr);
      const decimals = Number(decStr ?? '2');
      const value = faker.number.float({ min, max });
      return Number(value.toFixed(decimals));
    }

    // number.float (no args)
    if (rule === 'number.float') {
      return faker.number.float();
    }

    // finance.amount:min:max:decimals
    if (rule.startsWith('finance.amount:')) {
      const [, minStr, maxStr, decStr] = rule.split(':');
      const min = Number(minStr);
      const max = Number(maxStr);
      const decimals = Number(decStr ?? '2');
      return Number(faker.finance.amount({ min, max, dec: decimals }));
    }

    // date.between:start:end
    if (rule.startsWith('date.between:')) {
      const [, startStr, endStr] = rule.split(':');
      const start = new Date(startStr);
      const end = new Date(endStr);
      return faker.date.between({ from: start, to: end }).toISOString().slice(0, 10);
    }

    // date.afterColumn:columnName:minDays:maxDays
    if (rule.startsWith('date.afterColumn:')) {
      const [, col, minStr, maxStr] = rule.split(':');
      const base = row && row[col];
      if (!base) {
        // fallback: today
        const today = new Date();
        const days = faker.number.int({ min: Number(minStr ?? 1), max: Number(maxStr ?? 365) });
        today.setDate(today.getDate() + days);
        return today.toISOString().slice(0, 10);
      }
      const from = new Date(base);
      const days = faker.number.int({ min: Number(minStr ?? 1), max: Number(maxStr ?? 365) });
      from.setDate(from.getDate() + days);
      return from.toISOString().slice(0, 10);
    }

    // string.numeric:length
    if (rule.startsWith('string.numeric:')) {
      const [, lenStr] = rule.split(':');
      const length = Number(lenStr);
      return faker.string.numeric({ length, allowLeadingZeros: false });
    }

    // Dynamic faker method by path e.g., company.name, person.fullName
    const value = this.invokeFakerByPath(rule);
    if (value !== undefined) return value;

    // Fallback: treat as literal
    return rule;
  }

  private interpolateToken(token: string, context: GenerationContext, row?: Record<string, any>): string {
    // Replace ${...} with evaluated rules
    const regex = /\$\{([^}]+)\}/g;
    return token.replace(regex, (_match, inner) => {
      // if inner references a row column directly, return it
      if (row && inner in row) {
        return String(row[inner as keyof typeof row]);
      }
      const val = this.evaluateStringRule(inner, context, row);
      return String(val);
    });
  }

  private invokeFakerByPath(pathStr: string): any {
    const segments = pathStr.split('.');
    let current: any = faker as any;
    for (const seg of segments) {
      if (current && seg in current) {
        current = current[seg];
      } else {
        return undefined;
      }
    }
    if (typeof current === 'function') {
      try {
        return current();
      } catch {
        return undefined;
      }
    }
    return current;
  }
}

export function stableSeedFromTenant(tenantId: string): number {
  // simple string hash to int32 for seeding
  let hash = 0;
  for (let i = 0; i < tenantId.length; i += 1) {
    hash = ((hash << 5) - hash) + tenantId.charCodeAt(i);
    hash |= 0; // to 32bit int
  }
  return Math.abs(hash);
}


