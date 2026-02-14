# CoreMind / GigCore — DJ · Mekan · Organizatör Eşleşme Platformu

Tek sayfa (SPA) web uygulaması: ilanlar, mesajlaşma, başvurular, teklif odaları. Supabase ile auth, veritabanı ve realtime. Vercel Serverless ile güvenli secret yönetimi.

## Repo yapısı

| Dosya / klasör | Açıklama |
|----------------|----------|
| `index.html` | Ana uygulama (HTML + CSS + JS) — key'ler runtime yüklenir |
| `api/public-config.js` | Serverless: sadece public URL + anon key döner |
| `api/admin-action.js` | Serverless: service_role ile korunan admin işlemler |
| `api/health.js` | Serverless: deploy doğrulama endpoint |
| `vercel.json` | Vercel build + routing yapılandırması |
| `assets/` | Logo, ikon, görseller |
| `supabase_schema.sql` | Supabase tabloları + RLS policy'ler |
| `.env.local` | Local secret'lar (Git'e GİTMEZ) |
| `SUPABASE_SETUP.md` | Kurulum: anon key, URL, test checklist |
| `SUPABASE_MIGRATION.md` | Geçiş planı (local → Supabase) |
| `SUPABASE_CILA_OZET.md` | Son cila: mapping, realtime, RLS test, prod fallback |
| `DEPLOYMENT_SECURITY.md` | Güvenlik mimarisi, tehdit modeli, deploy adımları |

---

## Kurulum (2 dakika)

1. **Supabase SQL çalıştır** — Dashboard → SQL Editor → `supabase_schema.sql` yapıştırıp çalıştır.
2. **Vercel Environment Variables ayarla:**
   - `PUBLIC_SUPABASE_URL` → Supabase Project URL
   - `PUBLIC_SUPABASE_ANON_KEY` → anon public (JWT) key
   - `SUPABASE_SERVICE_ROLE_KEY` → service_role key (**sadece Production/Preview**)
3. **Deploy Vercel** — Repo'yu GitHub'a at, Vercel'e bağla, deploy et.

Detay: [SUPABASE_SETUP.md](SUPABASE_SETUP.md) · [DEPLOYMENT_SECURITY.md](DEPLOYMENT_SECURITY.md).

---

## Güvenlik Mimarisi

```
Client (index.html)
  ├── /api/public-config  →  SUPABASE_URL + ANON_KEY (public, RLS korumalı)
  ├── Supabase (anon)     →  Auth, DB, Realtime (RLS filtreli)
  └── /api/admin-action   →  service_role (SECRET, client göremez)
```

- **Anon key + URL:** Client'ta görünür, bu normaldir — güvenliği **RLS** sağlar.
- **Service role key:** Sadece Vercel serverless'te, `index.html`'de **ASLA** yer almaz.
- **Üyelik/şifre:** Supabase Auth yönetir; hash'li saklanır, client'ta düz metin bulunmaz.

**Anon key repo'da ise:** Repo'yu **Public** yerine **Private** yapmanız önerilir.

Detay: [DEPLOYMENT_SECURITY.md](DEPLOYMENT_SECURITY.md).

---

## Hızlı başlangıç (local dev)

1. `.env.local` dosyasını doldur (şablon repoda mevcut).
2. `npm i -g vercel && vercel dev` ile local serverless çalıştır.
3. `http://localhost:3000` adresinde test et.

## Deploy (Vercel)

1. GitHub'a push et (aşağıdaki komutlar).
2. Vercel Dashboard → Import → Environment Variables ekle.
3. Deploy sonrası `/api/health` ile doğrula.

Detay: [DEPLOYMENT_SECURITY.md](DEPLOYMENT_SECURITY.md).

## Teknolojiler

- Vanilla HTML/CSS/JS, Tailwind CSS (CDN), Supabase JS v2 (ESM CDN)
- Vercel Serverless Functions (Node.js)
- Auth, Realtime, RLS; local fallback sadece localhost'ta

---

## GitHub'a ilk push (komutlar tek tek)

```bash
git init
git add .
git status
```

**Push öncesi kontrol:** `git status` çıktısında şunlar olmalı: `index.html`, `api/` (3 dosya), `vercel.json`, `assets/`, `supabase_schema.sql`, `SUPABASE_*.md`, `DEPLOYMENT_SECURITY.md`, `README.md`, `.gitignore`.

**Olmaması gerekenler:** `.env.local`, `.cursor/`, `node_modules/`, `*.log`.

Sonra:

```bash
git commit -m "CoreMind: SPA + serverless API + security docs"
git branch -M main
git remote add origin https://github.com/KULLANICI_ADI/REPO_ADI.git
git push -u origin main
```

`KULLANICI_ADI` ve `REPO_ADI` kısmını kendi GitHub bilgilerinizle değiştirin.

---

## .gitignore ve repo temizliği

**.gitignore sadece yeni eklemeleri engeller.** Daha önce `git add` edilmiş bir dosya ignore'a eklense bile repo'da takip edilmeye devam eder.

Yanlışlıkla eklenen dosyaları repo takibinden çıkarmak (diskte silinmez) için:

```bash
git rm -r --cached .
git add .
git commit -m "chore: apply .gitignore cleanup"
```

Bundan sonra push'ta bu dosyalar repo'dan kalkar.
