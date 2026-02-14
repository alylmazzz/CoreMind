# CoreMind / GigCore — Güvenlik & Deployment Kılavuzu

## Mimari Özet

```
┌──────────────────────────────────────────────────────────────┐
│  CLIENT (index.html)                                         │
│  ─────────────────────                                       │
│  1) /api/public-config → SUPABASE_URL + ANON_KEY alır       │
│  2) createClient(url, anonKey) → RLS korumalı Supabase      │
│  3) Admin/privilege işlemler → /api/admin-action              │
│     (Authorization: Bearer <token>)                          │
└────────────────┬──────────────────────┬──────────────────────┘
                 │                      │
         ┌───────▼───────┐     ┌────────▼────────┐
         │  Supabase      │     │  Vercel API      │
         │  (anon + RLS)  │     │  (serverless)    │
         │  Auth, DB,     │     │  service_role    │
         │  Realtime      │     │  SECRET key      │
         └────────────────┘     └──────────────────┘
```

---

## 1. Değişken Sınıflandırması

| Değişken | Tür | Nerede kullanılır | Client görür mü? |
|----------|-----|-------------------|-------------------|
| `PUBLIC_SUPABASE_URL` | Public | `/api/public-config` → client | Evet (zorunlu) |
| `PUBLIC_SUPABASE_ANON_KEY` | Public | `/api/public-config` → client | Evet (zorunlu) |
| `SUPABASE_SERVICE_ROLE_KEY` | **SECRET** | Sadece `/api/admin-action.js` | **HAYIR** |
| `STRIPE_SECRET_KEY` | **SECRET** | Sadece serverless | **HAYIR** |
| `OPENAI_API_KEY` | **SECRET** | Sadece serverless | **HAYIR** |

**Kural:** `PUBLIC_` öneki olmayan her key **sadece serverless fonksiyonlarda** kullanılır.

---

## 2. Local Geliştirme

### .env.local (Git'e GİTMEZ)

```env
PUBLIC_SUPABASE_URL=https://xxxx.supabase.co
PUBLIC_SUPABASE_ANON_KEY=eyJ...
SUPABASE_SERVICE_ROLE_KEY=eyJ...
```

### Local'de Vercel Dev kullanımı

```bash
npm i -g vercel
vercel dev
```

Bu komut `.env.local` dosyasını okur ve `/api/*` endpoint'lerini çalıştırır.

---

## 3. Vercel'e Deploy

### Adım 1: GitHub repo oluştur (Private önerilir)

```bash
git init
git add .
git status
git commit -m "CoreMind: initial deploy with serverless API"
git branch -M main
git remote add origin https://github.com/KULLANICI/REPO.git
git push -u origin main
```

### Adım 2: Vercel Environment Variables

Vercel Dashboard → Project → **Settings** → **Environment Variables**:

| Key | Value | Environment |
|-----|-------|-------------|
| `PUBLIC_SUPABASE_URL` | `https://xxxx.supabase.co` | Production, Preview, Development |
| `PUBLIC_SUPABASE_ANON_KEY` | `eyJ...` (anon) | Production, Preview, Development |
| `SUPABASE_SERVICE_ROLE_KEY` | `eyJ...` (service_role) | Production, Preview |

> **ASLA** service_role key'i Development'a eklemeyin (local'de `.env.local` yeterli).

### Adım 3: Deploy doğrulama

Deploy sonrası kontrol edin:

```
https://your-app.vercel.app/api/health
```

Beklenen yanıt:
```json
{
  "ok": true,
  "timestamp": "2026-02-08T...",
  "env": {
    "hasSupabaseUrl": true,
    "hasAnonKey": true,
    "hasServiceRole": true
  }
}
```

---

## 4. Güvenlik Kontrol Listesi

- [ ] `index.html` içinde hardcoded key **YOK** ✓
- [ ] `.env.local` dosyası `.gitignore`'da ✓
- [ ] `SUPABASE_SERVICE_ROLE_KEY` sadece `api/admin-action.js`'de kullanılıyor ✓
- [ ] `/api/admin-action` JWT doğrulaması yapıyor ✓
- [ ] Prod'da `ALLOW_LOCAL_FALLBACK` sadece localhost'ta aktif ✓
- [ ] RLS policy'ler aktif ve test edilmiş ✓
- [ ] GitHub repo **Private** ✓

---

## 5. Tehdit Modeli & Risk Tablosu

| Tehdit | Risk | Mevcut Koruma | Durum |
|--------|------|---------------|-------|
| Anon key sızması | Düşük | RLS her sorguyu filtreler. Key public kabul edilir. | ✅ Kabul edilebilir |
| Service role sızması | **KRİTİK** | Sadece Vercel env'de, asla client'a gitmez. | ✅ Korunuyor |
| XSS ile token çalma | Orta | Supabase httpOnly cookie (PKCE), CSP header önerilir | ⚠️ CSP eklenebilir |
| Unauthorized admin | Yüksek | JWT doğrulaması + RLS | ✅ Korunuyor |
| Brute force login | Orta | Supabase Auth rate limiting | ✅ Otomatik |
| localStorage veri sızması | Düşük | Prod'da localStorage kullanılmıyor (Supabase aktif) | ✅ Korunuyor |

---

## 6. Secret Rotation (Anahtar Yenileme)

### Anon key sızarsa:
1. Supabase Dashboard → Settings → API → **Generate new anon key**
2. Vercel → Environment Variables → `PUBLIC_SUPABASE_ANON_KEY` güncelle
3. Redeploy

### Service role sızarsa (ACİL):
1. **Derhal** Supabase Dashboard → Settings → API → **Generate new service_role key**
2. Vercel → Environment Variables → `SUPABASE_SERVICE_ROLE_KEY` güncelle
3. Redeploy
4. Supabase loglarını kontrol et (yetkisiz erişim var mı?)
5. Tüm kullanıcı oturumlarını sonlandır: `supabase.auth.admin.signOut('global')`

---

## 7. Dosya Yapısı (güncel)

```
DjPlatformu/
├── api/
│   ├── public-config.js    ← Public env döner (URL + anon key)
│   ├── admin-action.js     ← Secret işlemler (service_role)
│   └── health.js           ← Deploy doğrulama
├── assets/                 ← Görseller
├── index.html              ← SPA (key'ler runtime yüklenir)
├── vercel.json             ← Vercel build + routing config
├── supabase_schema.sql     ← DB şeması + RLS
├── .env.local              ← Local secrets (Git'e GİTMEZ)
├── .gitignore              ← .env.* hariç tutar
├── SUPABASE_SETUP.md
├── SUPABASE_MIGRATION.md
├── SUPABASE_CILA_OZET.md
├── DEPLOYMENT_SECURITY.md  ← Bu dosya
└── README.md
```

---

## 8. Önemli Notlar

1. **Anon key "saklanamaz":** Client tarayıcıda Network/DevTools ile her zaman görülebilir. Bu tasarım gereğidir — güvenliği **RLS** sağlar, key'i gizlemek değil.

2. **Service role key client'a ASLA gitmemeli:** Bu key RLS'i bypass eder. Sadece serverless fonksiyonlarda kullanılır.

3. **Vercel Dev local'de API'yi simüle eder:** `vercel dev` komutu `.env.local`'i okur ve `/api/*` endpoint'lerini local'de çalıştırır.

4. **Prod'da localStorage kullanılmaz:** `USE_SUPABASE=true` olduğunda tüm veri Supabase'den gelir, localStorage'a düşmez.
