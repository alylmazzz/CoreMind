-- CoreMind / GigCore Supabase Schema + RLS
-- Supabase Dashboard > SQL Editor'da çalıştırın.
-- NOT: auth.users Supabase Auth tarafından yönetilir; profiles auth.users.id ile bağlıdır.

-- 1) profiles (auth.users ile 1:1, rol ve görünen bilgiler)
CREATE TABLE IF NOT EXISTS public.profiles (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role text NOT NULL CHECK (role IN ('dj','venue','organizer','decorator')),
  display_name text NOT NULL DEFAULT '',
  city text DEFAULT '',
  avatar_url text,
  logo_data_url text,
  cover_data_url text,
  bio text DEFAULT '',
  xp int DEFAULT 0,
  level int DEFAULT 1,
  badges text[] DEFAULT '{}',
  is_admin boolean NOT NULL DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Mevcut tabloya is_admin eklemek için (tablo zaten varsa):
-- ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_admin boolean NOT NULL DEFAULT false;

-- 2) dj_profiles, venue_profiles, organizer_profiles, decorator_profiles (rol bazlı ek bilgiler)
CREATE TABLE IF NOT EXISTS public.dj_profiles (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  genres text[] DEFAULT '{}',
  bpm_min int DEFAULT 120,
  bpm_max int DEFAULT 130,
  nightly_fee numeric DEFAULT 0,
  bio text DEFAULT '',
  logo_data_url text,
  google_drive_link text,
  tech_rider text DEFAULT '',
  equipment_provided text[] DEFAULT '{}',
  soundcloud_embed text,
  spotify_embed text,
  mixcloud_embed text,
  min_notice_days int,
  travel_radius_km int,
  profile_photo_data_url text,
  instagram text, tiktok text, x text, facebook text, whatsapp text, telegram text, soundcloud text, bandcamp text,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.venue_profiles (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  venue_name text DEFAULT '',
  city text DEFAULT '',
  capacity text DEFAULT '',
  typical_genres text[] DEFAULT '{}',
  budget_range text DEFAULT '',
  contact_prefs text DEFAULT '',
  equipment text[] DEFAULT '{}',
  ticket_price_policy text DEFAULT '',
  ticket_cut_percent numeric,
  ticket_cut_amount numeric,
  percentage_policies text DEFAULT '',
  lat numeric, lng numeric, address text DEFAULT '',
  profile_photo_data_url text,
  instagram text, tiktok text, x text, facebook text, whatsapp text, telegram text, soundcloud text, bandcamp text,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.organizer_profiles (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  organizer_name text DEFAULT '',
  city text DEFAULT '',
  network_tags text[] DEFAULT '{}',
  organization_fee numeric,
  organization_fee_percent numeric,
  requirements text[] DEFAULT '{}',
  contact_phone text DEFAULT '',
  profile_photo_data_url text,
  instagram text, tiktok text, x text, facebook text, whatsapp text, telegram text, soundcloud text, bandcamp text,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.decorator_profiles (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  business_name text DEFAULT '',
  city text DEFAULT '',
  service_area_km int,
  categories text[] DEFAULT '{}',
  portfolio_drive_links text[] DEFAULT '{}',
  profile_photo_data_url text,
  instagram text, tiktok text, x text, facebook text, whatsapp text, telegram text, soundcloud text, bandcamp text,
  created_at timestamptz DEFAULT now()
);

-- 3) common_profiles (tüm roller için ortak profil alanları)
CREATE TABLE IF NOT EXISTS public.common_profiles (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  display_name text DEFAULT '',
  avatar_data_url text,
  cover_data_url text,
  bio text DEFAULT '',
  languages text[] DEFAULT '{}',
  tags text[] DEFAULT '{}',
  working_cities text[] DEFAULT '{}',
  show_email boolean DEFAULT false,
  show_phone boolean DEFAULT false,
  allow_direct_booking boolean DEFAULT true,
  preferred_contact_method text DEFAULT 'in_app',
  last_updated bigint DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

-- 4) listings
CREATE TABLE IF NOT EXISTS public.listings (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  owner_role text NOT NULL,
  listing_type text NOT NULL,
  title text NOT NULL DEFAULT '',
  city text DEFAULT '',
  genres text[] DEFAULT '{}',
  bpm_target_min int,
  bpm_target_max int,
  hours numeric,
  date date,
  budget numeric,
  notes text DEFAULT '',
  visibility text DEFAULT 'public',
  status text DEFAULT 'active',
  -- venue/organizer/dj specific (jsonb for flexibility)
  extra jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_listings_owner ON public.listings(owner_id);
CREATE INDEX IF NOT EXISTS idx_listings_created ON public.listings(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_listings_city ON public.listings(city);
CREATE INDEX IF NOT EXISTS idx_listings_type ON public.listings(listing_type);

-- 5) message_threads
CREATE TABLE IF NOT EXISTS public.message_threads (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  created_at timestamptz DEFAULT now(),
  last_message_at timestamptz,
  last_message_text text,
  context jsonb DEFAULT '{}'
);

-- 6) thread_participants
CREATE TABLE IF NOT EXISTS public.thread_participants (
  thread_id bigint NOT NULL REFERENCES public.message_threads(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  unread_count int DEFAULT 0,
  PRIMARY KEY (thread_id, user_id)
);

-- 7) messages
CREATE TABLE IF NOT EXISTS public.messages (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  thread_id bigint NOT NULL REFERENCES public.message_threads(id) ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  text text NOT NULL,
  created_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_messages_thread ON public.messages(thread_id);
CREATE INDEX IF NOT EXISTS idx_messages_created ON public.messages(created_at);
-- Performans: thread + tarih siralama icin composite index (cok kullanicida fark eder)
CREATE INDEX IF NOT EXISTS idx_messages_thread_created ON public.messages(thread_id, created_at DESC);

-- 8) messaging_blocklist
CREATE TABLE IF NOT EXISTS public.messaging_blocklist (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  blocker_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  blocked_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  UNIQUE(blocker_id, blocked_id)
);

-- 9) applications
CREATE TABLE IF NOT EXISTS public.applications (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  listing_id bigint NOT NULL REFERENCES public.listings(id) ON DELETE CASCADE,
  applicant_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status text DEFAULT 'pending',
  created_at timestamptz DEFAULT now(),
  UNIQUE(listing_id, applicant_id)
);
CREATE INDEX IF NOT EXISTS idx_applications_listing ON public.applications(listing_id);

-- 10) deal_rooms
CREATE TABLE IF NOT EXISTS public.deal_rooms (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  listing_id bigint NOT NULL REFERENCES public.listings(id) ON DELETE CASCADE,
  applicant_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status text DEFAULT 'initiated',
  offer_terms jsonb DEFAULT '{}',
  accepted_terms_snapshot jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_deal_rooms_listing ON public.deal_rooms(listing_id);

-- 11) deal_room_messages
CREATE TABLE IF NOT EXISTS public.deal_room_messages (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  deal_room_id bigint NOT NULL REFERENCES public.deal_rooms(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  text text NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- 12) ledger
CREATE TABLE IF NOT EXISTS public.ledger (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  deal_room_id bigint NOT NULL REFERENCES public.deal_rooms(id) ON DELETE CASCADE,
  amount numeric NOT NULL,
  currency text DEFAULT 'TRY',
  payer_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  payee_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status text DEFAULT 'held',
  release_condition text DEFAULT 'event_completed',
  created_at timestamptz DEFAULT now()
);

-- 13) set_uploads, connections, reviews, reports (basit tablolar)
CREATE TABLE IF NOT EXISTS public.set_uploads (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  dj_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title text DEFAULT '',
  duration int DEFAULT 0,
  drive_url text,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.connections (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  from_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  to_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type text DEFAULT 'knowsDJ',
  message text,
  trust_level int DEFAULT 1,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.reviews (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  author_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  target_type text NOT NULL,
  target_id bigint NOT NULL,
  rating int NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment text,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.reports (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  reporter_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  target_type text NOT NULL,
  target_id bigint NOT NULL,
  reason text,
  status text DEFAULT 'pending',
  created_at timestamptz DEFAULT now()
);

-- ========== RLS ==========
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dj_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.venue_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organizer_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.decorator_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.common_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.message_threads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.thread_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messaging_blocklist ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.deal_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.deal_room_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.set_uploads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

-- profiles: herkes okuyabilir, sadece kendi satırını yazabilir
CREATE POLICY "profiles_select" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "profiles_insert" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "profiles_update" ON public.profiles FOR UPDATE USING (auth.uid() = user_id);

-- dj/venue/organizer/decorator profiles: aynı mantık
CREATE POLICY "dj_profiles_select" ON public.dj_profiles FOR SELECT USING (true);
CREATE POLICY "dj_profiles_all" ON public.dj_profiles FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "venue_profiles_select" ON public.venue_profiles FOR SELECT USING (true);
CREATE POLICY "venue_profiles_all" ON public.venue_profiles FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "organizer_profiles_select" ON public.organizer_profiles FOR SELECT USING (true);
CREATE POLICY "organizer_profiles_all" ON public.organizer_profiles FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "decorator_profiles_select" ON public.decorator_profiles FOR SELECT USING (true);
CREATE POLICY "decorator_profiles_all" ON public.decorator_profiles FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "common_profiles_select" ON public.common_profiles FOR SELECT USING (true);
CREATE POLICY "common_profiles_all" ON public.common_profiles FOR ALL USING (auth.uid() = user_id);

-- listings: herkes okuyabilir, auth kullanıcı ekleyebilir, sadece owner güncelleyebilir/silebilir
CREATE POLICY "listings_select" ON public.listings FOR SELECT USING (true);
CREATE POLICY "listings_insert" ON public.listings FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "listings_update" ON public.listings FOR UPDATE USING (auth.uid() = owner_id);
CREATE POLICY "listings_delete" ON public.listings FOR DELETE USING (auth.uid() = owner_id);

-- message_threads: participant olanlar görebilir
CREATE POLICY "threads_select" ON public.message_threads FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.thread_participants tp WHERE tp.thread_id = id AND tp.user_id = auth.uid())
);
CREATE POLICY "threads_insert" ON public.message_threads FOR INSERT WITH CHECK (true);
CREATE POLICY "thread_participants_select" ON public.thread_participants FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "thread_participants_insert" ON public.thread_participants FOR INSERT WITH CHECK (
  user_id = auth.uid() OR
  EXISTS (SELECT 1 FROM public.thread_participants tp WHERE tp.thread_id = thread_participants.thread_id AND tp.user_id = auth.uid())
);
CREATE POLICY "thread_participants_update" ON public.thread_participants FOR UPDATE USING (user_id = auth.uid());

-- messages: participant olanlar görebilir, sender insert edebilir
CREATE POLICY "messages_select" ON public.messages FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.thread_participants tp WHERE tp.thread_id = messages.thread_id AND tp.user_id = auth.uid())
);
CREATE POLICY "messages_insert" ON public.messages FOR INSERT WITH CHECK (auth.uid() = sender_id);

-- messaging_blocklist
CREATE POLICY "blocklist_select" ON public.messaging_blocklist FOR SELECT USING (blocker_id = auth.uid());
CREATE POLICY "blocklist_insert" ON public.messaging_blocklist FOR INSERT WITH CHECK (blocker_id = auth.uid());
CREATE POLICY "blocklist_delete" ON public.messaging_blocklist FOR DELETE USING (blocker_id = auth.uid());

-- applications: applicant kendi başvurusunu, listing owner ilanına gelenleri görebilir
CREATE POLICY "applications_select" ON public.applications FOR SELECT USING (
  applicant_id = auth.uid() OR
  listing_id IN (SELECT id FROM public.listings WHERE owner_id = auth.uid())
);
CREATE POLICY "applications_insert" ON public.applications FOR INSERT WITH CHECK (applicant_id = auth.uid());
CREATE POLICY "applications_update" ON public.applications FOR UPDATE USING (
  listing_id IN (SELECT id FROM public.listings WHERE owner_id = auth.uid())
);

-- deal_rooms: owner veya applicant
CREATE POLICY "deal_rooms_select" ON public.deal_rooms FOR SELECT USING (owner_id = auth.uid() OR applicant_id = auth.uid());
CREATE POLICY "deal_rooms_insert" ON public.deal_rooms FOR INSERT WITH CHECK (owner_id = auth.uid() OR applicant_id = auth.uid());
CREATE POLICY "deal_rooms_update" ON public.deal_rooms FOR UPDATE USING (owner_id = auth.uid() OR applicant_id = auth.uid());

CREATE POLICY "deal_room_messages_select" ON public.deal_room_messages FOR SELECT USING (
  deal_room_id IN (SELECT id FROM public.deal_rooms WHERE owner_id = auth.uid() OR applicant_id = auth.uid())
);
CREATE POLICY "deal_room_messages_insert" ON public.deal_room_messages FOR INSERT WITH CHECK (
  deal_room_id IN (SELECT id FROM public.deal_rooms WHERE owner_id = auth.uid() OR applicant_id = auth.uid())
);

CREATE POLICY "ledger_select" ON public.ledger FOR SELECT USING (
  deal_room_id IN (SELECT id FROM public.deal_rooms WHERE owner_id = auth.uid() OR applicant_id = auth.uid())
);
CREATE POLICY "ledger_insert" ON public.ledger FOR INSERT WITH CHECK (
  deal_room_id IN (SELECT id FROM public.deal_rooms WHERE owner_id = auth.uid() OR applicant_id = auth.uid())
);

-- set_uploads, connections, reviews, reports: basit politikalar
CREATE POLICY "set_uploads_all" ON public.set_uploads FOR ALL USING (dj_user_id = auth.uid());
CREATE POLICY "connections_select" ON public.connections FOR SELECT USING (from_user_id = auth.uid() OR to_user_id = auth.uid());
CREATE POLICY "connections_insert" ON public.connections FOR INSERT WITH CHECK (from_user_id = auth.uid());
CREATE POLICY "reviews_select" ON public.reviews FOR SELECT USING (true);
CREATE POLICY "reviews_insert" ON public.reviews FOR INSERT WITH CHECK (author_user_id = auth.uid());
CREATE POLICY "reports_select" ON public.reports FOR SELECT USING (true);
CREATE POLICY "reports_insert" ON public.reports FOR INSERT WITH CHECK (reporter_user_id = auth.uid());

-- Realtime (Supabase Dashboard > Database > Replication'tan listings ve messages eklenebilir)
