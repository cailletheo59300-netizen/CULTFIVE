-- Journal d'usage des pubs (0062) : raison d'une pub qui ne s'affiche pas, choix de confidentialité.
do $$
declare u uuid := tst.new_user(); r jsonb;
begin
  perform tst.login(u);
  r := public.track_events('[{"name":"ad_fail","props":{"kind":"boost_chest","reason":"load com.google.admob 1"}},{"name":"ad_privacy"}]');
  perform tst.ok((r ->> 'recorded')::int = 2, 'ad_fail et ad_privacy enregistrés');
  perform tst.ok(exists (select 1 from public.app_events where user_id = u and name = 'ad_fail'
                          and props ->> 'reason' = 'load com.google.admob 1'), 'raison gardée');
end $$;
