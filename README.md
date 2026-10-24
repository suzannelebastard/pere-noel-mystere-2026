# Père Noël mystère

Deux pages statiques pour déposer anonymement un mot-clé et en tirer un seul. Un mot provisoire reste réservable pendant 15 minutes; le bouton de relance libère ce mot et en réserve un autre. La validation supprime le mot de la base et empêche un second tirage confirmé depuis le même navigateur.

## Configuration

1. Créez un projet Supabase et exécutez le contenu de `supabase.sql` dans l’éditeur SQL.
2. Dans `config.js`, remplacez `YOUR_PROJECT` par l’identifiant du projet et `YOUR_SUPABASE_ANON_KEY` par sa clé publique `anon`.
3. N’utilisez jamais la clé `service_role` dans le navigateur.
4. Pour un test local, lancez `python -m http.server 8000` depuis ce dossier puis ouvrez `http://localhost:8000`.

La limite d’un tirage confirmé repose sur un identifiant conservé dans le navigateur et en base. Sans compte ni code d’accès, elle ne peut pas identifier une personne qui change de navigateur ou efface ses données. Le projet Supabase et le site doivent être partagés avec l’équipe pour utiliser la même liste.