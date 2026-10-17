-- Vitrine du profil (0063) : socle et 3 cartes possédés, vus par les amis.
do $$
declare
  a uuid := tst.new_user(); b uuid := tst.new_user();
  v_cards text[]; r jsonb;
begin
  select array_agg(id order by id) into v_cards from (select id from public.album_cards order by id limit 4) c;
  insert into public.user_cards (user_id, slot, card_id, shiny, hidden) values
    (a, 0, v_cards[1], true, '{}'), (a, 0, v_cards[2], true, '{shiny}'), (a, 0, v_cards[3], false, '{}');
  insert into public.user_cards (user_id, slot, card_id) values (a, 1, v_cards[4]);
  insert into public.user_cosmetics (user_id, item_id, source) values (a, 'socle.or', 'test');
  perform tst.login(a);

  r := public.showcase_get();
  perform tst.ok(r ->> 'socle' is null and jsonb_array_length(r -> 'cards') = 0, 'vitrine vide au départ');
  perform tst.throws(format('select public.showcase_set(%L, %L)', 'neon', array[v_cards[1]]), 'socle_not_owned');
  perform tst.throws(format('select public.showcase_set(null, %L)', array[v_cards[4]]), 'card_not_owned');
  perform tst.throws(format('select public.showcase_set(null, %L)', array[v_cards[1], v_cards[1]]), 'duplicate_card');
  perform tst.throws(format('select public.showcase_set(null, %L)', array[v_cards[1], v_cards[2], v_cards[3], v_cards[1]]), 'too_many_cards');

  r := public.showcase_set('or', array[v_cards[2], v_cards[1]]);
  perform tst.ok(r ->> 'socle' = 'or', 'socle posé');
  perform tst.ok(r -> 'cards' -> 0 ->> 'card' = v_cards[2] and r -> 'cards' -> 1 ->> 'card' = v_cards[1], 'ordre gardé');
  perform tst.ok(not (r -> 'cards' -> 0 ->> 'shiny')::bool and (r -> 'cards' -> 1 ->> 'shiny')::bool, 'état masqué non affiché');

  -- Ami : voit la vitrine ; une carte perdue disparaît.
  perform public._befriend(a, b);
  perform tst.login(b);
  r := public.friend_profile(a);
  perform tst.ok(r -> 'showcase' ->> 'socle' = 'or' and jsonb_array_length(r -> 'showcase' -> 'cards') = 2, 'vitrine vue par un ami');
  delete from public.user_cards where user_id = a and card_id = v_cards[2];
  delete from public.user_cosmetics where user_id = a and item_id = 'socle.or';
  r := public.friend_profile(a);
  perform tst.ok(r -> 'showcase' ->> 'socle' is null and jsonb_array_length(r -> 'showcase' -> 'cards') = 1, 'carte et socle perdus retirés');
end $$;
