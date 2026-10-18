-- Çalışan (staff) yetki sınırı + değişiklik geçmişi.
-- Supabase panelinde SQL Editor'a yapıştırıp çalıştır. Mevcut kayıtlara dokunmaz.

-- 1) Eski halleri saklayan geçmiş tablosu (sadece dükkân sahibi okur)
create table if not exists public.docs_log (
  id bigint generated always as identity primary key,
  shop_id uuid not null,
  kind text not null,
  doc_id text not null,
  old_data jsonb,
  old_deleted boolean,
  old_by uuid,
  old_at timestamptz,
  new_deleted boolean,
  changed_by uuid,
  changed_at timestamptz not null default now()
);
create index if not exists docs_log_shop_at on public.docs_log (shop_id, changed_at desc);
alter table public.docs_log enable row level security;
drop policy if exists docs_log_read on public.docs_log;
create policy docs_log_read on public.docs_log for select to authenticated
  using (is_owner(shop_id) or is_admin());
revoke all on public.docs_log from anon, authenticated;
grant select on public.docs_log to authenticated;

create or replace function public.docs_log_fn() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'UPDATE' and (old.data is distinct from new.data or old.deleted is distinct from new.deleted) then
    insert into docs_log (shop_id, kind, doc_id, old_data, old_deleted, old_by, old_at, new_deleted, changed_by)
    values (old.shop_id, old.kind, old.id, old.data, old.deleted, old.updated_by, old.updated_at, new.deleted, auth.uid());
  end if;
  return new;
end $$;
drop trigger if exists docs_zlog on public.docs;
create trigger docs_zlog after update on public.docs for each row execute function public.docs_log_fn();

-- 2) Çalışan sınırı
--  * kasa kaydı yazamaz
--  * yeni satış/stok/ürün kaydı ekleyebilir
--  * başkasının kaydını değiştiremez/silemez; kendi kaydını 15 dk içinde geri alabilir
--  * ürün, müşteri, tedarikçi, ayar bilgisini düzenleyebilir ama silemez
create or replace function public.docs_guard() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  o public.docs;
  win interval := interval '15 minutes';
begin
  if me is null then return new; end if;                      -- servis / cron
  if is_owner(new.shop_id) or is_admin() then return new; end if;
  if new.kind = 'cash' then
    raise exception 'YETKI: kasa kaydını sadece dükkân sahibi değiştirebilir' using errcode = 'P0001';
  end if;
  select * into o from docs where shop_id = new.shop_id and kind = new.kind and id = new.id;
  if not found then return new; end if;                       -- yeni kayıt serbest
  if o.updated_by = me and o.updated_at > now() - win then return new; end if;
  if new.kind in ('product','customer','supplier','settings') and new.deleted = false then return new; end if;
  raise exception 'YETKI: bu kaydı değiştirme ya da silme yetkin yok' using errcode = 'P0001';
end $$;
drop trigger if exists docs_guard on public.docs;
create trigger docs_guard before insert or update on public.docs for each row execute function public.docs_guard();
