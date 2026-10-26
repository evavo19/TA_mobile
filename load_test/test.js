import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = { vus: 10, duration: '30s' };

export default function () {
  const res = http.get(
    `${__ENV.SUPABASE_URL}/rest/v1/wisata?select=*`,
    {
      headers: {
        apikey: __ENV.SUPABASE_KEY,
        Authorization: `Bearer ${__ENV.SUPABASE_KEY}`,
      },
    }
  );
  check(res, { 'status 200': (r) => r.status === 200 });
  sleep(1);
}