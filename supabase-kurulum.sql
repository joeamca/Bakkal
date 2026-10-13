-- =====================================================================
--  Bakkal Defteri · Supabase veritabanı kurulumu
--  Supabase panelinde: SQL Editor → New query → bu dosyanın TAMAMINI
--  yapıştır → Run. Tekrar çalıştırmak zararsızdır (verileri silmez).
-- =====================================================================

create extension if not exists pgcrypto with schema extensions;

-- Kullanıcı adları bu alan adıyla e-postaya çevrilir (e-posta gönderilmez).
-- Uygulamadaki EMAIL_DOMAIN ile aynı olmalı.
create or replace function public.bd_email_domain() returns text
language sql immutable set search_path = public as $$ select 'kullanici.bakkaldefteri.app' $$;

-- ---------- Tablolar ----------
create table if not exists public.shops (
  id          uuid primary key default gen_random_uuid(),
  name        text not null check (char_length(name) between 1 and 60),
  active      boolean not null default true,
  created_at  timestamptz not null default now(),
  created_by  uuid references auth.users(id) on delete set null
);

create table if not exists public.profiles (
  user_id     uuid primary key references auth.users(id) on delete cascade,
  username    text not null unique check (username ~ '^[a-z0-9._-]{3,24}$'),
  full_name   text check (full_name is null or char_length(full_name) <= 60),
  is_admin    boolean not null default false,
  created_at  timestamptz not null default now(),
  last_seen   timestamptz
);

create table if not exists public.members (
  shop_id     uuid not null references public.shops(id) on delete cascade,
  user_id     uuid not null references auth.users(id) on delete cascade,
  role        text not null check (role in ('owner','staff')),
  created_at  timestamptz not null default now(),
  primary key (shop_id, user_id)
);
create index if not exists members_user on public.members(user_id);

-- Uygulamadaki her kayıt (ürün, fatura satırı, fire, veresiye, ayar) bir satır
create table if not exists public.docs (
  shop_id     uuid not null references public.shops(id) on delete cascade,
  kind        text not null check (kind in ('product','event','supplier','customer','settings')),
  id          text not null check (char_length(id) between 1 and 80),
  data        jsonb not null default '{}'::jsonb check (pg_column_size(data) < 200000),
  deleted     boolean not null default false,
  updated_at  timestamptz not null default now(),
  updated_by  uuid references auth.users(id) on delete set null,
  primary key (shop_id, kind, id)
);
create index if not exists docs_shop_time on public.docs(shop_id, updated_at);

-- Kayıt başvuruları: bakkal kendi başvurur, yönetici onaylar. Şifre sadece şifrelenmiş (bcrypt) saklanır.
create table if not exists public.signup_requests (
  id            uuid primary key default gen_random_uuid(),
  shop_name     text not null check (char_length(shop_name) between 1 and 60),
  full_name     text not null check (char_length(full_name) between 1 and 60),
  phone         text check (phone is null or char_length(phone) <= 30),
  note          text check (note is null or char_length(note) <= 300),
  username      text not null check (username ~ '^[a-z0-9._-]{3,24}$'),
  password_hash text not null default '',
  status        text not null default 'pending' check (status in ('pending','approved','rejected')),
  created_at    timestamptz not null default now(),
  decided_at    timestamptz,
  decided_by    uuid references auth.users(id) on delete set null,
  shop_id       uuid references public.shops(id) on delete set null
);
create unique index if not exists signup_pending_user on public.signup_requests(username) where status = 'pending';

-- ---------- Yardımcılar ----------
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select p.is_admin from profiles p where p.user_id = auth.uid()), false)
$$;

create or replace function public.is_member(s uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from members m join shops sh on sh.id = m.shop_id
                 where m.shop_id = s and m.user_id = auth.uid() and sh.active)
$$;

create or replace function public.is_owner(s uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from members m where m.shop_id = s and m.user_id = auth.uid() and m.role = 'owner')
$$;

-- Kim yazdıysa o yazsın, saat sunucudan gelsin
create or replace function public.docs_stamp() returns trigger
language plpgsql set search_path = public as $$
begin
  new.updated_at := now();
  new.updated_by := auth.uid();
  return new;
end $$;
drop trigger if exists docs_stamp on public.docs;
create trigger docs_stamp before insert or update on public.docs
  for each row execute function public.docs_stamp();

-- ---------- Güvenlik kuralları (RLS) ----------
alter table public.shops    enable row level security;
alter table public.profiles enable row level security;
alter table public.members  enable row level security;
alter table public.docs     enable row level security;
alter table public.signup_requests enable row level security; -- kural yok: tabloya sadece fonksiyonlar erişir

drop policy if exists shops_read on public.shops;
create policy shops_read on public.shops for select to authenticated
  using (public.is_admin() or exists (select 1 from public.members m where m.shop_id = shops.id and m.user_id = auth.uid()));

drop policy if exists profiles_read on public.profiles;
create policy profiles_read on public.profiles for select to authenticated
  using (user_id = auth.uid() or public.is_admin());

drop policy if exists members_read on public.members;
create policy members_read on public.members for select to authenticated
  using (user_id = auth.uid() or public.is_member(shop_id) or public.is_admin());

drop policy if exists docs_read on public.docs;
create policy docs_read on public.docs for select to authenticated using (public.is_member(shop_id));
drop policy if exists docs_insert on public.docs;
create policy docs_insert on public.docs for insert to authenticated with check (public.is_member(shop_id));
drop policy if exists docs_update on public.docs;
create policy docs_update on public.docs for update to authenticated
  using (public.is_member(shop_id)) with check (public.is_member(shop_id));
-- Silme yok: kayıtlar "deleted" işaretiyle silinir ki diğer telefonlar da öğrensin.

-- Girişsiz ziyaretçi hiçbir tabloya dokunamaz; tablolara doğrudan yazma da kapalı
revoke all on public.shops, public.profiles, public.members, public.docs from anon;
revoke all on public.signup_requests from anon, authenticated;
revoke insert, update, delete on public.shops, public.profiles, public.members from authenticated;
grant select on public.shops, public.profiles, public.members to authenticated;
grant select, insert, update on public.docs to authenticated;

-- ---------- Hesap açma (iç fonksiyon, dışarıdan çağrılamaz) ----------
create or replace function public.bd_create_user_hashed(p_username text, p_hash text, p_full_name text)
returns uuid language plpgsql security definer set search_path = public, extensions as $$
declare
  u text := lower(trim(p_username));
  uid uuid := gen_random_uuid();
  em text;
begin
  if u !~ '^[a-z0-9._-]{3,24}$' then
    raise exception 'Kullanıcı adı 3-24 karakter olmalı; sadece İngilizce harf, rakam, nokta, tire.' using errcode = 'P0001';
  end if;
  if coalesce(p_hash,'') !~ '^\$2[aby]\$' then
    raise exception 'Şifre bilgisi eksik.' using errcode = 'P0001';
  end if;
  if exists (select 1 from profiles where username = u) then
    raise exception 'Bu kullanıcı adı alınmış: %', u using errcode = 'P0001';
  end if;
  em := u || '@' || bd_email_domain();
  if exists (select 1 from auth.users where email = em) then
    raise exception 'Bu kullanıcı adı alınmış: %', u using errcode = 'P0001';
  end if;
  insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
      confirmation_token, recovery_token, email_change_token_new, email_change,
      email_change_token_current, phone_change, phone_change_token, reauthentication_token)
  values ('00000000-0000-0000-0000-000000000000', uid, 'authenticated', 'authenticated', em,
      p_hash, now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      jsonb_build_object('username', u, 'full_name', p_full_name), now(), now(),
      '', '', '', '', '', '', '', '');
  insert into auth.identities (provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
  values (uid::text, uid, jsonb_build_object('sub', uid::text, 'email', em, 'email_verified', true), 'email', now(), now(), now());
  insert into profiles (user_id, username, full_name) values (uid, u, nullif(trim(p_full_name), ''));
  return uid;
end $$;
revoke all on function public.bd_create_user_hashed(text, text, text) from public, anon, authenticated;

create or replace function public.bd_create_user(p_username text, p_password text, p_full_name text)
returns uuid language plpgsql security definer set search_path = public, extensions as $$
begin
  if char_length(coalesce(p_password,'')) < 6 then
    raise exception 'Şifre en az 6 karakter olmalı.' using errcode = 'P0001';
  end if;
  if exists (select 1 from signup_requests where username = lower(trim(p_username)) and status = 'pending') then
    raise exception 'Bu kullanıcı adıyla bekleyen bir başvuru var: %', lower(trim(p_username)) using errcode = 'P0001';
  end if;
  return bd_create_user_hashed(p_username, crypt(p_password, gen_salt('bf')), p_full_name);
end $$;
revoke all on function public.bd_create_user(text, text, text) from public, anon, authenticated;

-- ---------- İlk yönetici (sadece SQL Editor'den, bir kez) ----------
-- Kullanım:  select public.bootstrap_admin('berk', 'güçlü-şifre', 'Berk', 'Berk''in dükkânı');
create or replace function public.bootstrap_admin(p_username text, p_password text, p_full_name text, p_shop_name text default null)
returns text language plpgsql security definer set search_path = public as $$
declare uid uuid; sid uuid;
begin
  if exists (select 1 from profiles where is_admin) then
    raise exception 'Yönetici zaten var.' using errcode = 'P0001';
  end if;
  uid := bd_create_user(p_username, p_password, p_full_name);
  update profiles set is_admin = true where user_id = uid;
  if p_shop_name is not null then
    insert into shops (name, created_by) values (p_shop_name, uid) returning id into sid;
    insert into members (shop_id, user_id, role) values (sid, uid, 'owner');
  end if;
  return 'Yönetici hazır: ' || lower(p_username);
end $$;
revoke all on function public.bootstrap_admin(text, text, text, text) from public, anon, authenticated;

-- ---------- Uygulamanın çağırdığı fonksiyonlar ----------
-- Giriş yapan kişi: profil + dükkânları
create or replace function public.my_context() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'user_id', p.user_id, 'username', p.username, 'full_name', p.full_name, 'is_admin', p.is_admin,
    'pending_signups', case when p.is_admin then (select count(*) from signup_requests r where r.status = 'pending') else 0 end,
    'shops', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'name', s.name, 'role', m.role, 'active', s.active) order by s.name)
                        from members m join shops s on s.id = m.shop_id where m.user_id = p.user_id), '[]'::jsonb))
  from profiles p where p.user_id = auth.uid()
$$;

create or replace function public.touch() returns void
language sql security definer set search_path = public as $$
  update profiles set last_seen = now() where user_id = auth.uid()
$$;

-- Yönetici: yeni dükkân + sahibinin hesabı
create or replace function public.admin_create_shop(p_shop_name text, p_username text, p_password text, p_full_name text)
returns uuid language plpgsql security definer set search_path = public as $$
declare uid uuid; sid uuid;
begin
  if not is_admin() then raise exception 'Bu işlem için yönetici olmalısın.' using errcode = '42501'; end if;
  if char_length(trim(coalesce(p_shop_name,''))) = 0 then raise exception 'Dükkân adını yaz.' using errcode = 'P0001'; end if;
  insert into shops (name, created_by) values (trim(p_shop_name), auth.uid()) returning id into sid;
  uid := bd_create_user(p_username, p_password, p_full_name);
  insert into members (shop_id, user_id, role) values (sid, uid, 'owner');
  return sid;
end $$;

-- Dükkân sahibi ya da yönetici: çalışan ekler (rol: staff ya da owner)
create or replace function public.add_member(p_shop uuid, p_username text, p_password text, p_full_name text, p_role text default 'staff')
returns uuid language plpgsql security definer set search_path = public as $$
declare uid uuid;
begin
  if not (is_owner(p_shop) or is_admin()) then raise exception 'Bu dükkâna kişi ekleme yetkin yok.' using errcode = '42501'; end if;
  if p_role not in ('owner','staff') then raise exception 'Rol hatalı.' using errcode = 'P0001'; end if;
  uid := bd_create_user(p_username, p_password, p_full_name);
  insert into members (shop_id, user_id, role) values (p_shop, uid, p_role);
  return uid;
end $$;

-- Dükkândaki kişiler (dükkânın her üyesi görebilir: kim ne girdi gösterimi için)
create or replace function public.shop_members(p_shop uuid)
returns table (user_id uuid, username text, full_name text, role text, last_seen timestamptz)
language sql stable security definer set search_path = public as $$
  select p.user_id, p.username, p.full_name, m.role, p.last_seen
  from members m join profiles p on p.user_id = m.user_id
  where m.shop_id = p_shop and (is_member(p_shop) or is_admin())
  order by m.role, p.username
$$;

-- Şifre yenileme: yönetici herkesinkini; dükkân sahibi kendi dükkânındaki çalışanınkini
create or replace function public.reset_password(p_user uuid, p_password text)
returns void language plpgsql security definer set search_path = public, extensions as $$
begin
  if char_length(coalesce(p_password,'')) < 6 then raise exception 'Şifre en az 6 karakter olmalı.' using errcode = 'P0001'; end if;
  if not (is_admin() or exists (
      select 1 from members o join members t on t.shop_id = o.shop_id
      where o.user_id = auth.uid() and o.role = 'owner' and t.user_id = p_user and t.role = 'staff')) then
    raise exception 'Bu kişinin şifresini değiştirme yetkin yok.' using errcode = '42501';
  end if;
  if exists (select 1 from profiles where user_id = p_user and is_admin) and p_user <> auth.uid() then
    raise exception 'Yöneticinin şifresi buradan değiştirilemez.' using errcode = '42501';
  end if;
  update auth.users set encrypted_password = crypt(p_password, gen_salt('bf')), updated_at = now() where id = p_user;
end $$;

-- Dükkândan çıkar (başka dükkânı yoksa hesabı tamamen kapatır)
create or replace function public.remove_member(p_shop uuid, p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
declare r text;
begin
  select role into r from members where shop_id = p_shop and user_id = p_user;
  if r is null then return; end if;
  if p_user = auth.uid() then raise exception 'Kendini çıkaramazsın.' using errcode = 'P0001'; end if;
  if not (is_admin() or (is_owner(p_shop) and r = 'staff')) then
    raise exception 'Bu kişiyi çıkarma yetkin yok.' using errcode = '42501';
  end if;
  delete from members where shop_id = p_shop and user_id = p_user;
  if not exists (select 1 from members where user_id = p_user)
     and not exists (select 1 from profiles where user_id = p_user and is_admin) then
    delete from auth.users where id = p_user;
  end if;
end $$;

-- Yönetici: dükkânı durdur / aç (ör. ödeme yapılmadıysa). Durdurulan dükkânın verisi silinmez.
create or replace function public.admin_set_shop_active(p_shop uuid, p_active boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_admin() then raise exception 'Bu işlem için yönetici olmalısın.' using errcode = '42501'; end if;
  update shops set active = p_active where id = p_shop;
end $$;

create or replace function public.rename_shop(p_shop uuid, p_name text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not (is_owner(p_shop) or is_admin()) then raise exception 'Yetkin yok.' using errcode = '42501'; end if;
  if char_length(trim(coalesce(p_name,''))) = 0 then raise exception 'Dükkân adını yaz.' using errcode = 'P0001'; end if;
  update shops set name = trim(p_name) where id = p_shop;
end $$;

-- Yönetici paneli: dükkânlar, kişiler, son hareket. Dükkânın kayıtlarının İÇERİĞİ gösterilmez.
create or replace function public.admin_overview() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_admin() then raise exception 'Bu işlem için yönetici olmalısın.' using errcode = '42501'; end if;
  return coalesce((select jsonb_agg(x order by x->>'name') from (
    select jsonb_build_object(
      'id', s.id, 'name', s.name, 'active', s.active, 'created_at', s.created_at,
      'products', (select count(*) from docs d where d.shop_id = s.id and d.kind = 'product' and not d.deleted),
      'events', (select count(*) from docs d where d.shop_id = s.id and d.kind = 'event' and not d.deleted),
      'last_write', (select max(updated_at) from docs d where d.shop_id = s.id),
      'members', coalesce((select jsonb_agg(jsonb_build_object('user_id', p.user_id, 'username', p.username, 'full_name', p.full_name, 'role', m.role, 'last_seen', p.last_seen) order by m.role, p.username)
                  from members m join profiles p on p.user_id = m.user_id where m.shop_id = s.id), '[]'::jsonb)
    ) as x from shops s) t), '[]'::jsonb);
end $$;

-- ---------- Kayıt başvurusu ----------
-- Herkes (girişsiz) başvurabilir. Sahte başvuru yağmuruna karşı sınır var.
create or replace function public.request_signup(p_shop_name text, p_full_name text, p_phone text, p_username text, p_password text, p_note text default null)
returns text language plpgsql security definer set search_path = public, extensions as $$
declare u text := lower(trim(coalesce(p_username,'')));
begin
  if char_length(trim(coalesce(p_shop_name,''))) = 0 then raise exception 'Dükkânının adını yaz.' using errcode = 'P0001'; end if;
  if char_length(trim(coalesce(p_full_name,''))) = 0 then raise exception 'Adını soyadını yaz.' using errcode = 'P0001'; end if;
  if char_length(trim(coalesce(p_shop_name,''))) > 60 or char_length(trim(p_full_name)) > 60 then raise exception 'Ad çok uzun.' using errcode = 'P0001'; end if;
  if char_length(regexp_replace(coalesce(p_phone,''), '[^0-9]', '', 'g')) < 10 then raise exception 'Telefon numaranı yaz (onaylanınca sana haber verilecek).' using errcode = 'P0001'; end if;
  if u !~ '^[a-z0-9._-]{3,24}$' then raise exception 'Kullanıcı adı 3-24 karakter olmalı; sadece İngilizce harf, rakam, nokta, tire.' using errcode = 'P0001'; end if;
  if char_length(coalesce(p_password,'')) < 6 then raise exception 'Şifre en az 6 karakter olmalı.' using errcode = 'P0001'; end if;
  if exists (select 1 from profiles where username = u) or exists (select 1 from signup_requests where username = u and status = 'pending') then
    raise exception 'Bu kullanıcı adı alınmış: %. Başka bir ad seç.', u using errcode = 'P0001';
  end if;
  if (select count(*) from signup_requests where created_at > now() - interval '10 minutes') >= 20
     or (select count(*) from signup_requests where status = 'pending') >= 300 then
    raise exception 'Şu an çok fazla başvuru var. Biraz sonra tekrar dene.' using errcode = 'P0001';
  end if;
  insert into signup_requests (shop_name, full_name, phone, note, username, password_hash)
  values (trim(p_shop_name), trim(p_full_name), left(trim(p_phone), 30), nullif(left(trim(coalesce(p_note,'')), 300), ''), u, crypt(p_password, gen_salt('bf')));
  return 'ok';
end $$;

-- Giriş olmadıysa: "başvurun onay bekliyor" diyebilmek için
create or replace function public.signup_status(p_username text) returns text
language sql stable security definer set search_path = public as $$
  select r.status from signup_requests r
  where r.username = lower(trim(coalesce(p_username,''))) and r.status in ('pending','rejected')
    and not exists (select 1 from profiles p where p.username = r.username)
  order by r.created_at desc limit 1
$$;

-- Yönetici: bekleyen başvurular
create or replace function public.admin_signups() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_admin() then raise exception 'Bu işlem için yönetici olmalısın.' using errcode = '42501'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'shop_name', r.shop_name, 'full_name', r.full_name, 'phone', r.phone,
      'note', r.note, 'username', r.username, 'created_at', r.created_at) order by r.created_at)
    from signup_requests r where r.status = 'pending'), '[]'::jsonb);
end $$;

-- Yönetici: onayla (dükkân + hesap açılır) ya da reddet
create or replace function public.admin_decide_signup(p_id uuid, p_approve boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare r signup_requests; uid uuid; sid uuid;
begin
  if not is_admin() then raise exception 'Bu işlem için yönetici olmalısın.' using errcode = '42501'; end if;
  select * into r from signup_requests where id = p_id for update;
  if r.id is null then raise exception 'Başvuru bulunamadı.' using errcode = 'P0001'; end if;
  if r.status <> 'pending' then raise exception 'Bu başvuru zaten sonuçlanmış.' using errcode = 'P0001'; end if;
  if p_approve then
    uid := bd_create_user_hashed(r.username, r.password_hash, r.full_name);
    insert into shops (name, created_by) values (r.shop_name, auth.uid()) returning id into sid;
    insert into members (shop_id, user_id, role) values (sid, uid, 'owner');
  end if;
  update signup_requests set status = case when p_approve then 'approved' else 'rejected' end,
    decided_at = now(), decided_by = auth.uid(), shop_id = sid, password_hash = '' where id = p_id;
  return jsonb_build_object('status', case when p_approve then 'approved' else 'rejected' end,
    'username', r.username, 'full_name', r.full_name, 'shop_name', r.shop_name, 'phone', r.phone, 'shop_id', sid);
end $$;

do $$
declare f text;
begin
  foreach f in array array['public.request_signup(text,text,text,text,text,text)', 'public.signup_status(text)'] loop
    execute format('revoke all on function %s from public', f);
    execute format('grant execute on function %s to anon, authenticated', f);
  end loop;
end $$;

-- Fonksiyon izinleri: girişsiz ziyaretçi hiçbirini çağıramaz
do $$
declare f text;
begin
  foreach f in array array[
    'public.my_context()', 'public.touch()',
    'public.admin_create_shop(text,text,text,text)', 'public.add_member(uuid,text,text,text,text)',
    'public.shop_members(uuid)', 'public.reset_password(uuid,text)', 'public.remove_member(uuid,uuid)',
    'public.admin_set_shop_active(uuid,boolean)', 'public.rename_shop(uuid,text)', 'public.admin_overview()',
    'public.is_admin()', 'public.is_member(uuid)', 'public.is_owner(uuid)',
    'public.admin_signups()', 'public.admin_decide_signup(uuid,boolean)'] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $$;

-- Supabase'in "otomatik RLS" ayarının yardımcı fonksiyonu dışarıdan çağrılmasın
do $$ begin
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'rls_auto_enable') then
    execute 'revoke execute on function public.rls_auto_enable() from public, anon, authenticated';
  end if;
end $$;

-- ---------- Canlı eşitleme: bir telefonda girilen diğerinde hemen görünsün ----------
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'docs') then
    alter publication supabase_realtime add table public.docs;
  end if;
end $$;

select 'Bakkal Defteri veritabanı hazır.' as sonuc;
