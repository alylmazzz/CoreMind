# Supabase Son Cila — Değişiklik Özeti

## 1) index.html'de Değişen Bloklar

- **Config / Cache sonrası (yeni):**
  - `SupabaseModelMap`: DB row ↔ UI model tek katman (mapListingRowToModel, mapListingModelToInsert, mapMessageRowToModel, mapMessageModelToInsert, mapApplicationRowToModel, mapApplicationModelToInsert).
  - `showSupabaseError(err, context)`: Supabase hatalarında console.error + kullanıcıya toast/alert; anon key / URL / RLS mesajları ayrıştırılıyor.

- **SupabaseDataService:**
  - `rowToListing` / `listingToRow` artık `SupabaseModelMap` üzerinden.
  - `loadListings`, `loadMessages`, `loadAll` (applications) hata durumunda `showSupabaseError` çağrılıyor.
  - Mesaj cache’i `SupabaseModelMap.mapMessageRowToModel` ile dolduruluyor; applications `mapApplicationRowToModel` ile.

- **Bootstrap (DOMContentLoaded):**
  - Realtime için tek instance: `app._realtime = app._realtime || {}`.
  - `app._realtime.listings` ve `app._realtime.messages` yoksa bir kez channel oluşturulup subscribe ediliyor (duplicate event önlenir).
  - Bootstrap catch’te `showSupabaseError(e, 'bootstrap')` çağrılıyor.

- **Auth / Form:**
  - Login: hata durumunda `showSupabaseError(error, 'signIn')`.
  - Register: `showSupabaseError(error, 'signUp')`.
  - Listing insert (dekor + normal): hata durumunda `showSupabaseError(error, 'listing insert')`.

- **Ayarlar (Settings) view:**
  - Supabase açıksa: “Supabase RLS Self Test” bölümü, “RLS SELF TEST çalıştır” butonu ve sonuç alanı `#rlsTestResult`.

- **Yeni API:**
  - `RLSAPI.runSelfTest()`: listings / messages / applications select + başka kullanıcı thread’ine yetkisiz erişim testi; sonuçları dizi olarak döner.

---

## 2) Realtime Kanallar (app._realtime)

| Kanal            | Key       | Tablo      | Amaç                                      |
|------------------|-----------|------------|-------------------------------------------|
| `listings-rt`    | `listings`| `listings` | İlan ekleme/güncelleme/silme → cache + liste yenileme |
| `messages-rt`    | `messages`| `messages` | Yeni mesaj → loadMessages + mesajlar view yenileme    |

- Her kanal yalnızca **bir kez** subscribe edilir; referanslar `app._realtime.listings` ve `app._realtime.messages` içinde tutulur.

---

## 3) Mapping Fonksiyonları (SupabaseModelMap)

| Fonksiyon                     | Yön       | Açıklama |
|------------------------------|-----------|----------|
| `mapListingRowToModel(r)`    | DB → UI   | `owner_id` → `createdByUserId`, `owner_role` → `ownerRole`, `created_at` → `createdAt` vb. |
| `mapListingModelToInsert(o)` | UI → DB   | Insert için `owner_id`, `owner_role`, `listing_type`, `extra` vb. |
| `mapMessageRowToModel(m)`    | DB → UI   | `thread_id` → `threadId`, `sender_id` → `senderId`, `created_at` → `createdAt` |
| `mapMessageModelToInsert(m)` | UI → DB   | Mesaj insert: `thread_id`, `sender_id`, `text` |
| `mapApplicationRowToModel(a)`| DB → UI   | `applicant_id` → `userId`, `listing_id` → `listingId` |
| `mapApplicationModelToInsert(a)` | UI → DB | Başvuru insert: `listing_id`, `applicant_id`, `status` |

- Legacy alanlar (`createdByUserId` vb.) yalnızca bu map’lerde üretilir; UI tarafında tek shape kullanılır.

---

## 4) RLS Self Test (Ayarlar)

- **Konum:** Ayarlar sayfası, “Supabase RLS Self Test” bölümü (sadece Supabase açıksa görünür).
- **Buton:** “RLS SELF TEST çalıştır”.
- **Kontroller:**
  - `listings` select (1 satır).
  - `messages` select (1 satır).
  - `applications` select (1 satır).
  - Mümkünse başka kullanıcıya ait bir thread’in mesajlarına erişim denemesi (RLS’in reddetmesi beklenir).
- Sonuçlar `#rlsTestResult` içinde yeşil (OK) / kırmızı (hata) listelenir.

---

## 5) Prod: Local Fallback Kapalı + Offline UI Kilidi

- `ALLOW_LOCAL_FALLBACK`: Sadece `localhost` / `127.0.0.1` ise `true`. Prod’da Supabase hata verirse localStorage’a düşülmez.
- Prod’da bootstrap hatası: `app._supabaseOffline = true`, `#offlineBanner` gösterilir (“Sunucu bağlantısı kurulamadı” + **Yenile** butonu). Store.set yazmayı kabul etmez, Store.get cache (boş olabilir) döner.
- **Offline iken UI:** İlan Aç (nav + dashboard) ve Mesaj Gönder (mesajlar + deal room) butonları **disabled**, `opacity-50 cursor-not-allowed`; tıklanırsa “Sunucu bağlantısı yok.” toast. İlan form submit’te de aynı kontrol.

## 6) Realtime Cache Refresh

- Listings event: `await loadListings()` → sonra `app.router('listings')` (cache önce dolar, sonra UI güncellenir).
- Messages event: `await loadMessages()` → sonra `app.router('messages', ...)`.

## 7) RLS Self Test Anlamlı Yetkisiz Erişim

- **Yetkisiz thread:** `messages` için `thread_id = 999999999` ile select; beklenen: hata **veya** 0 row (RLS filtreledi). Row dönerse test kırmızı.
- **Yetkisiz deal_room:** `deal_room_messages` için `deal_room_id = 999999999` ile select; aynı mantık.
- Sonuçta 0 row gelirse etiket: **"0 row (expected)"** (debug kalitesi).

## 8) Mesaj Throttle + Index

- Client-side: 1 saniyede 1 mesaj (`Messaging._lastMessageSentAt`, 1000 ms kontrol).
- Şema: `idx_messages_thread_created ON messages(thread_id, created_at DESC)` performans için eklendi.

---

## 9) Kısa Test Kontrol Listesi

1. **SUPABASE_ANON_KEY** içine anon public key (eyJ...) yapıştır.
2. Vercel’e push → deploy.
3. İki tarayıcı (Chrome + Firefox) ile:
   - Tarayıcı 1’de ilan ekle → Tarayıcı 2’de refresh yapmadan ilan görünsün.
   - A → B mesaj atınca B’de anında düşsün.
   - B başvursun → A panelinde anında görünsün; A kabul edince B’de status anında değişsin.
   - C (3. kullanıcı) A–B thread/messages/deal_room verilerini göremesin.
4. Ayarlar → “RLS SELF TEST çalıştır”: “RLS: yetkisiz thread mesajı” ve “yetkisiz deal_room” yeşil (OK) olmalı.
5. Prod’da Supabase çökerse: local fallback yok, banner + Yenile görünmeli.
