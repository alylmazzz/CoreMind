# CoreMind Supabase Kurulumu

## Access Token vs Anon Key (3 Madde)

1. **Access Token (sb_publishable_... / sbp_...)** – Supabase’in yeni API token formatı. Bu projede **KULLANILMAZ**. Client tarafında sadece JWT anon key kullanılır.
2. **Anon Key (JWT, eyJ... ile başlar)** – Supabase Dashboard → Project Settings → API → **anon public** key. Bu projede `SUPABASE_ANON_KEY` olarak kullanılır. RLS ile güvenlik sağlanır.
3. **service_role** – Sunucu tarafı işlemler için. Client’a **asla** konmaz.

## 1. Supabase Projesi

1. [Supabase Dashboard](https://supabase.com/dashboard) → Projenizi seçin
2. **SQL Editor** → `supabase_schema.sql` dosyasının içeriğini yapıştırıp çalıştırın
3. **Project Settings** → **API** → **Project URL** ve **anon public** (JWT) key'i kopyalayın

## 2. API Anahtarları

- **SUPABASE_URL**: `https://xxxxx.supabase.co`
- **SUPABASE_ANON_KEY**: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...` (JWT formatında, ~200 karakter)

⚠️ **Önemli**: `anon` key client-side'da kullanılır; güvenlik RLS (Row Level Security) ile sağlanır. `service_role` key asla client'a konmamalıdır.

## 3. index.html İçinde

`index.html` içinde şu satırları bulun ve kendi değerlerinizle değiştirin:

```javascript
const SUPABASE_URL = 'https://zdrywlqyljiipnihzbor.supabase.co';
const SUPABASE_ANON_KEY = ''; // Project Settings > API > anon public (JWT) key buraya
```

**Saf HTML'de**: Vercel env otomatik gelmez. `index.html` içinde yukarıdaki değişkenlere doğrudan değer yazın. Alternatif: build tool (Vite vb.) kullanıyorsanız `import.meta.env` veya `process.env` ile okuyabilirsiniz.

## 4. Vercel Environment Variables (Opsiyonel)

Vercel’de environment variable kullanmak için:

1. Vercel Dashboard → Proje → Settings → Environment Variables
2. `SUPABASE_URL` ve `SUPABASE_ANON_KEY` ekleyin
3. **Not**: Saf HTML projede build-time env kullanılır; Vite/Next gibi bir build tool kullanıyorsanız `process.env` ile okunur.

## 5. İlk Kullanıcı

- Mevcut "demo" kullanıcılar (dj@test.com vb.) artık çalışmaz
- Yeni kullanıcılar **Üye ol** ile Supabase Auth üzerinden kayıt olmalı
- İlk kayıt sonrası `profiles` tablosuna otomatik satır eklenir

## 6. Test Checklist

- [ ] **2 tarayıcı login**: Chrome (User A), Firefox (User B) ile giriş yap
- [ ] Tarayıcı 1’de ilan ekle → Tarayıcı 2’de anında görünsün
- [ ] **Mesaj realtime**: B mesaj atar → A anında görür
- [ ] **Başvuru**: A ilan açar, B başvurur, A kabul eder → B anında status değişir
- [ ] **RLS**: C (3. kullanıcı) A–B konuşmasını göremez
