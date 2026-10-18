-- Tickets d'aide (D-076) : 5 au plus par sorte (50/50, Indice). Au-delà, le ticket gagné est perdu (pas de neurones,
-- décision du propriétaire). Les joueurs qui en avaient plus redescendent à 5.
create or replace function public._give_item(p_user uuid, p_item text, p_qty integer default 1) returns void
language plpgsql set search_path = public, extensions, pg_temp as $$
declare v_ticket bool := (select kind from public.items where id = p_item) = 'ticket';
begin
  insert into public.user_items as ui (user_id, item_id, qty, acquired_at)
  values (p_user, p_item, case when v_ticket then least(p_qty, 5) else p_qty end, public._now())
  on conflict (user_id, item_id) do update set qty = case
    when v_ticket then least(ui.qty + excluded.qty, 5) else ui.qty end;
end $$;

update public.user_items ui set qty = 5
from public.items i
where i.id = ui.item_id and i.kind = 'ticket' and ui.qty > 5;
