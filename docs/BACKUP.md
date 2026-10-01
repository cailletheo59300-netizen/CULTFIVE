# Sauvegardes de la base

Le plan gratuit de Supabase ne propose pas de sauvegarde restaurable. Une tâche GitHub (`.github/workflows/backup.yml`)
copie donc chaque nuit (2 h 23 UTC) les schémas `public` (tout le jeu) et `auth` (comptes), chiffre la copie en AES-256
et la garde **30 jours** dans l'onglet Actions du dépôt (« Sauvegarde de la base » → une exécution → *Artifacts*).

## Mise en place (une fois)

1. **Chaîne de connexion** : Supabase → projet → bouton **Connect** → onglet *Connection string* → **Session pooler**
   (pas « Direct connection » : les machines GitHub n'ont pas d'IPv6). Copier l'URI et remplacer `[YOUR-PASSWORD]`
   par le mot de passe de la base (Project Settings → Database → *Reset database password* si oublié).
2. **Phrase de chiffrement** : une longue phrase inventée, notée dans un gestionnaire de mots de passe.
   Sans elle, aucune sauvegarde ne peut être relue.
3. GitHub → dépôt → **Settings → Secrets and variables → Actions → New repository secret** :
   `SUPABASE_DB_URL` (l'URI) et `BACKUP_PASSPHRASE` (la phrase).
4. Onglet **Actions → Sauvegarde de la base → Run workflow** pour un premier essai.

Ne jamais coller ces deux valeurs ailleurs (messages, code, captures).

## Restaurer

Sur un ordinateur avec PostgreSQL 17 et GnuPG :

```sh
gpg --decrypt brainlix-AAAA-MM-JJ.dump.gpg > brainlix.dump          # demande la phrase de chiffrement
pg_restore --list brainlix.dump | head                              # vérifier le contenu
# Dans un projet Supabase NEUF (jamais par-dessus la prod sans être sûr) :
pg_restore --no-owner --no-privileges --clean --if-exists -d "URI_SESSION_POOLER_DU_NOUVEAU_PROJET" brainlix.dump
```

Puis rejouer les réglages hors base : fonctions Edge (`admob-ssv`, `push-send`) et leurs secrets, tâches pg_cron
(recréées par les migrations), URL du projet dans l'app (`ios/Config/App.xcconfig`).
