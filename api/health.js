// api/health.js
// Vercel Serverless Function — Basit sağlık kontrolü.
// Deploy doğrulama ve uptime monitoring için kullanılır.

export default function handler(req, res) {
  res.setHeader('Cache-Control', 'no-store');

  const status = {
    ok: true,
    timestamp: new Date().toISOString(),
    env: {
      hasSupabaseUrl: !!process.env.PUBLIC_SUPABASE_URL,
      hasAnonKey: !!process.env.PUBLIC_SUPABASE_ANON_KEY,
      hasServiceRole: !!process.env.SUPABASE_SERVICE_ROLE_KEY,
    },
  };

  // Env eksikse uyar (değerleri ASLA döndürme)
  if (!status.env.hasSupabaseUrl || !status.env.hasAnonKey) {
    status.ok = false;
    status.warning = 'Public Supabase env değişkenleri eksik.';
  }

  return res.status(status.ok ? 200 : 503).json(status);
}
