---
name: ouvrir-tirages
description: "Utilise ce skill pour ouvrir les tirages du Père Noël mystère : ferme les participations et les révélations, puis ouvre les tirages."
---

# Ouvrir les tirages

Configure l’application pour la phase des tirages individuels : les participations et les révélations sont fermées, et le tirage est ouvert.

## Procédure

1. Applique ce changement à la base Supabase du projet, dans son éditeur SQL authentifié. Cette table n’autorise pas les mises à jour anonymes via l’API publique.
2. Exécute cette mise à jour atomique :

   ```sql
   update public.draw_settings
   set submissions_open = false,
       is_open = true,
       reveal_open = false
   where id = 1
   returning id, submissions_open, is_open, reveal_open;
   ```

3. Vérifie que la ligne retournée indique `false, true, false`, dans cet ordre. Si aucune ligne n’est retournée, ne prétends pas que les tirages sont ouverts : vérifie que `supabase.sql` a été appliqué et que la ligne de configuration `id = 1` existe.
4. Si tu n’as pas accès à l’éditeur SQL authentifié ou si le projet Supabase actif n’est pas certain, fournis la requête à l’utilisateur et demande-lui de l’exécuter sur le bon projet. Ne demande ni n’utilise de clé `service_role` dans le navigateur ou `config.js`.
