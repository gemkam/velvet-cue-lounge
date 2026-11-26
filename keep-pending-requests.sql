-- ============================================================
-- Velvet Cue Lounge: walk-in requests never expire on their own
-- Supabase > SQL Editor > New query > paste all > Run (safe to run again)
--
-- A "Play now" request that is waiting for approval stays in the dashboard
-- until staff press Approve or Reject. Any automatic job that tries to cancel
-- it is ignored. Staff Reject from the dashboard still works.
-- Advance bookings keep their normal no-show auto-cancel.
-- ============================================================
create or replace function public.keep_pending_walkin()
returns trigger
language plpgsql
as $$
begin
  if old.status = 'pending'
     and new.status = 'cancelled'
     and coalesce(old.is_advance_booking, false) = false
     and current_user not in ('anon', 'authenticated') then
    new.status := old.status;   -- automatic cancel blocked, request stays pending
  end if;
  return new;
end;
$$;

drop trigger if exists keep_pending_walkin on public.bookings;
create trigger keep_pending_walkin
before update on public.bookings
for each row execute function public.keep_pending_walkin();
