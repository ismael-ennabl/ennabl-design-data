import 'dotenv/config';
import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE = process.env.SUPABASE_SERVICE_ROLE;
const SUPABASE_KEY = process.env.SUPABASE_KEY;

if (!SUPABASE_URL || (!SUPABASE_KEY && !SUPABASE_SERVICE_ROLE)) {
  throw new Error('Missing SUPABASE_URL and a key (SUPABASE_SERVICE_ROLE or SUPABASE_KEY)');
}

// Prefer service role key for seeding; fall back to anon key
export const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE || SUPABASE_KEY!);


