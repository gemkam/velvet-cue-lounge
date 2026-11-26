-- ============================================================
-- Velvet Cue Lounge: Settings + Canteen setup (run ONCE)
-- Supabase > SQL Editor > New query > paste all > Run
-- Safe to run again: it skips anything that already exists.
-- ============================================================

-- 1) Settings (prices, offer banner, announcement bar)
create table if not exists public.cafe_settings (
  key        text primary key,
  value      jsonb not null,
  updated_at timestamptz not null default now()
);

-- 2) Canteen menu
create table if not exists public.canteen_items (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  price_omr  numeric(8,3) not null default 0,
  category   text not null default 'Snacks',
  photo_url  text,
  in_stock   boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

-- 3) Access rules
-- Everyone can READ (the public pages show the menu, prices and banners).
-- Editing is allowed from the dashboard. NOTE: the dashboard currently uses the
-- same public key as the website (no real staff login yet), so these write rules
-- must be tightened when the proper staff login is switched on.
alter table public.cafe_settings enable row level security;
alter table public.canteen_items enable row level security;

drop policy if exists "settings read"  on public.cafe_settings;
drop policy if exists "settings write" on public.cafe_settings;
create policy "settings read"  on public.cafe_settings for select using (true);
create policy "settings write" on public.cafe_settings for all using (true) with check (true);

drop policy if exists "canteen read"  on public.canteen_items;
drop policy if exists "canteen write" on public.canteen_items;
create policy "canteen read"  on public.canteen_items for select using (true);
create policy "canteen write" on public.canteen_items for all using (true) with check (true);

-- 4) Photo storage for canteen items (public images)
insert into storage.buckets (id, name, public)
values ('canteen', 'canteen', true)
on conflict (id) do nothing;

drop policy if exists "canteen photos read"   on storage.objects;
drop policy if exists "canteen photos upload" on storage.objects;
drop policy if exists "canteen photos change" on storage.objects;
drop policy if exists "canteen photos delete" on storage.objects;
create policy "canteen photos read"   on storage.objects for select using (bucket_id = 'canteen');
create policy "canteen photos upload" on storage.objects for insert with check (bucket_id = 'canteen');
create policy "canteen photos change" on storage.objects for update using (bucket_id = 'canteen');
create policy "canteen photos delete" on storage.objects for delete using (bucket_id = 'canteen');

-- 5) Live updates (menu and banners change on the website instantly)
do $$
begin
  begin alter publication supabase_realtime add table public.cafe_settings; exception when others then null; end;
  begin alter publication supabase_realtime add table public.canteen_items; exception when others then null; end;
end $$;

-- 6) Starter menu from the real canteen stock. Prices are GUESSES, so items start
--    HIDDEN (in_stock = false). The owner sets the real price and switches each one on.
insert into public.canteen_items (name, price_omr, category, sort_order, in_stock)
select name, price_omr, category, sort_order, false from (values
  ('Karak chai',    0.200, 'Hot drinks', 1),
  ('Coffee',        0.300, 'Hot drinks', 2),
  ('Cappuccino',    0.500, 'Hot drinks', 3),
  ('Alsi Cola',     0.200, 'Cold drinks', 4),
  ('Leemo',         0.200, 'Cold drinks', 5),
  ('Stream',        0.200, 'Cold drinks', 6),
  ('Lilac water',   0.100, 'Cold drinks', 7),
  ('Muscat Chips',  0.100, 'Snacks', 8),
  ('Big Break wafer', 0.200, 'Snacks', 9),
  ('Glace ice cream', 0.300, 'Snacks', 10)
) as v(name, price_omr, category, sort_order)
where not exists (select 1 from public.canteen_items);
