// api/public-config.js
// Vercel Serverless Function — Sadece PUBLIC bilgileri döner.
// Secret'lar (service_role vb.) burada ASLA expose edilmez.

export default function handler(req, res) {
  // CORS — aynı origin'den gelir ama güvenlik için explicit
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET');
  res.setHeader('Cache-Control', 'public, max-age=300'); // 5 dk cache

  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const config = {
    SUPABASE_URL: process.env.PUBLIC_SUPABASE_URL || '',
    SUPABASE_ANON_KEY: process.env.PUBLIC_SUPABASE_ANON_KEY || '',
  };

  // Eksik config kontrolü
  if (!config.SUPABASE_URL || !config.SUPABASE_ANON_KEY) {
    return res.status(503).json({
      error: 'Supabase yapılandırması eksik. Vercel Environment Variables kontrol edin.',
    });
  }

  return res.status(200).json(config);
}
