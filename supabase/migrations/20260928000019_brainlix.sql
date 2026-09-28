-- Brainlix — 0019 Nouveau nom de l'app : texte du succès « premier ami » et nom de la tâche planifiée
update public.achievements set description = 'Avoir un premier ami sur Brainlix.' where id = 'first_friend';

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    if exists (select 1 from cron.job where jobname = 'cultfive-daily-maintenance') then
      perform cron.unschedule('cultfive-daily-maintenance');
    end if;
    perform cron.schedule('brainlix-daily-maintenance', '*/15 * * * *', 'select public.cron_daily_maintenance()');
  end if;
exception when others then
  raise notice 'pg_cron indisponible : tâche non renommée (%)', sqlerrm;
end $$;
