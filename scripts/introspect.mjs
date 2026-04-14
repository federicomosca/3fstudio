import { createClient } from '@supabase/supabase-js';
const sb = createClient(
  'https://qndkjgagyupogaibozbw.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFuZGtqZ2FneXVwb2dhaWJvemJ3Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NjAwOTk1NywiZXhwIjoyMDkxNTg1OTU3fQ.cpF0UJSvwdNqWGCGH8myGEQ_0cSQwWJwbnf-a85BqIg',
  { auth: { autoRefreshToken: false, persistSession: false } }
);
// Probe booking_status enum values
for (const status of ['confirmed', 'cancelled', 'attended', 'completed', 'present', 'absent', 'booked', 'pending']) {
  const { data: u } = await sb.auth.admin.listUsers();
  const user = u.users[0];
  const { data: lessons } = await sb.from('lessons').select('id').limit(1).single();
  const { error } = await sb.from('bookings').insert({ user_id: user.id, lesson_id: lessons.id, status });
  if (!error) {
    console.log(`status "${status}": VALID`);
    await sb.from('bookings').delete().eq('user_id', user.id);
  } else if (error.message.includes('invalid input value for enum')) {
    console.log(`status "${status}": invalid`);
  } else {
    console.log(`status "${status}": other error - ${error.message}`);
  }
}
