// api/admin-action.js
// Vercel Serverless Function — SUPABASE_SERVICE_ROLE_KEY ile çalışır.
// Client bu key'i ASLA göremez. Tüm admin/privileged işlemler buradan yapılır.
//
// Kullanım: POST /api/admin-action  { action: "...", payload: {...} }
// Header:   Authorization: Bearer <supabase_access_token>

import { createClient } from '@supabase/supabase-js';

// --- JWT doğrulama + rol kontrolü yardımcısı ---
async function verifyAndGetUser(req) {
  const authHeader = req.headers['authorization'] || '';
  const token = authHeader.replace('Bearer ', '');
  if (!token) return null;

  // anon client ile token doğrula
  const anonClient = createClient(
    process.env.PUBLIC_SUPABASE_URL,
    process.env.PUBLIC_SUPABASE_ANON_KEY
  );
  const { data: { user }, error } = await anonClient.auth.getUser(token);
  if (error || !user) return null;

  // Kullanıcının rolünü profiles tablosundan al
  const { data: profile } = await anonClient
    .from('profiles')
    .select('role, is_admin')
    .eq('user_id', user.id)
    .single();

  return {
    ...user,
    role: profile?.role || 'unknown',
    is_admin: profile?.is_admin === true,
  };
}

// --- Yetki seviyesi tanımları ---
// Her action için gerekli minimum yetki
const ACTION_PERMISSIONS = {
  report_user: 'authenticated',  // Herkes rapor edebilir
  admin_approve: 'admin',        // Sadece admin
  ban_user: 'admin',             // Sadece admin
};

function hasPermission(user, action) {
  const required = ACTION_PERMISSIONS[action] || 'admin';
  if (required === 'authenticated') return true;  // Giriş yapmış yeterli
  if (required === 'admin') return user.is_admin === true;
  return false;
}

// --- Admin Supabase client (service_role — FULL erişim) ---
function getAdminClient() {
  return createClient(
    process.env.PUBLIC_SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY
  );
}

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  // CORS preflight
  if (req.method === 'OPTIONS') return res.status(200).end();

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  // --- Service role key kontrolü ---
  if (!process.env.SUPABASE_SERVICE_ROLE_KEY) {
    return res.status(503).json({ error: 'Service role key yapılandırılmamış.' });
  }

  // --- Kullanıcı doğrulama ---
  const user = await verifyAndGetUser(req);
  if (!user) {
    return res.status(401).json({ error: 'Yetkisiz. Geçerli bir oturum gerekli.' });
  }

  const { action, payload } = req.body || {};
  if (!action) {
    return res.status(400).json({ error: 'action alanı gerekli.' });
  }

  // --- Yetki kontrolü (admin action'lar için rol doğrulama) ---
  if (!hasPermission(user, action)) {
    return res.status(403).json({
      error: 'Yetersiz yetki. Bu işlem için admin rolü gerekli.',
      requiredRole: ACTION_PERMISSIONS[action] || 'admin',
    });
  }

  const adminClient = getAdminClient();

  try {
    switch (action) {
      // ═══════════════════════════════════════════
      // ÖRNEK: Kullanıcı raporlama (moderasyon)
      // ═══════════════════════════════════════════
      case 'report_user': {
        const { targetUserId, reason } = payload || {};
        if (!targetUserId || !reason) {
          return res.status(400).json({ error: 'targetUserId ve reason gerekli.' });
        }
        const { error } = await adminClient
          .from('reports')
          .insert({ reporter_id: user.id, target_user_id: targetUserId, reason });
        if (error) throw error;
        return res.status(200).json({ ok: true, message: 'Rapor kaydedildi.' });
      }

      // ═══════════════════════════════════════════
      // ÖRNEK: Admin onay (listing, başvuru vb.)
      // ═══════════════════════════════════════════
      case 'admin_approve': {
        const { table, recordId, statusField, newStatus } = payload || {};
        if (!table || !recordId) {
          return res.status(400).json({ error: 'table ve recordId gerekli.' });
        }
        // Güvenlik: Sadece izin verilen tablolar üzerinde işlem yapılabilir
        const ALLOWED_TABLES = ['listings', 'applications', 'deal_rooms', 'reports'];
        if (!ALLOWED_TABLES.includes(table)) {
          return res.status(400).json({ error: `İzin verilmeyen tablo: ${table}. İzin verilen: ${ALLOWED_TABLES.join(', ')}` });
        }
        // Güvenlik: statusField sadece bilinen alanlar olabilir
        const ALLOWED_STATUS_FIELDS = ['status', 'review_status', 'moderation_status'];
        const safeField = ALLOWED_STATUS_FIELDS.includes(statusField) ? statusField : 'status';
        const { error } = await adminClient
          .from(table)
          .update({ [safeField]: newStatus || 'approved' })
          .eq('id', recordId);
        if (error) throw error;
        return res.status(200).json({ ok: true, message: 'Onaylandı.' });
      }

      // ═══════════════════════════════════════════
      // ÖRNEK: Kullanıcı banla
      // ═══════════════════════════════════════════
      case 'ban_user': {
        const { targetUserId: banTarget } = payload || {};
        if (!banTarget) {
          return res.status(400).json({ error: 'targetUserId gerekli.' });
        }
        // Supabase Admin API ile kullanıcıyı devre dışı bırak
        const { error } = await adminClient.auth.admin.updateUserById(banTarget, {
          ban_duration: '876000h', // ~100 yıl
        });
        if (error) throw error;
        return res.status(200).json({ ok: true, message: 'Kullanıcı banlandı.' });
      }

      default:
        return res.status(400).json({ error: `Bilinmeyen action: ${action}` });
    }
  } catch (err) {
    console.error('[admin-action]', action, err);
    return res.status(500).json({ error: 'Sunucu hatası.', detail: err.message });
  }
}
