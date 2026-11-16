# Roblox VR — combat à l'arme de mêlée

Une arène d'entraînement VR : huit armes chinoises et un bouclier sur un râtelier, quatre mannequins à frapper, des vagues de bandits.
Les dégâts dépendent de la vitesse réelle de la lame.

## Lancer le jeu

1. Ouvre `RobloxVR-Melee.rbxlx` dans Roblox Studio (double-clic).
2. Pour jouer en VR : branche le casque, puis active **Fichier → Paramètres de Studio → Rendering → VR Mode** (un redémarrage de Studio peut être nécessaire).
3. Appuie sur **Play**.

L'arène (sol, râtelier, mannequins) et les armes sont créées par le script au lancement : le Workspace est vide tant que le jeu ne tourne pas.

## Commandes

| Action | VR | Clavier / souris (sans casque) |
| --- | --- | --- |
| Saisir une arme | Maintenir la gâchette de préhension (grip) près du manche | `E` (main droite), `Q` (main gauche) |
| Lâcher | Relâcher le grip | `E` / `Q` à nouveau |
| Frapper | Bouger réellement la main | Clic gauche |
| Tenir à deux mains | Grip de la seconde main sur le manche (épée longue, hache) | — |
| Se déplacer | Joystick gauche | `ZQSD` / flèches |

Un contour blanc indique l'arme que la main peut saisir.

## Armes

| Arme | Modèle chinois | Dégâts de base | Vitesse minimale | Deux mains |
| --- | --- | --- | --- | --- |
| Dague | bishou (匕首) : lame droite à deux tranchants, pommeau en anneau | 12 | 8 | non |
| Épée | jian (剑) : lame droite à arête centrale, garde de bronze, pommeau de jade, pompon de soie rouge | 25 | 11 | non |
| Épée longue | changdao (长刀) : long sabre à un tranchant, garde ronde en laiton, poignée tressée noire | 40 | 9 | oui |
| Hache | fu (斧) : fer en croissant, pique au sommet, manche laqué rouge et houppe de soie | 35 | 10 | oui |
| Sabre | dao (刀) : lame à un tranchant qui s'élargit vers la pointe, garde ronde, foulard de soie rouge | 28 | 10 | non |
| Lance | qiang (枪) : longue hampe de bois clair, fer en feuille de saule, houppe de crin rouge | 30 | 9 | oui |
| Guandao | guandao (偃月刀) : lourde lame en croissant sur une hampe, crochet au dos, contrepoids au talon | 45 | 8 | oui |
| Bâton | gun (棍) : long bâton ferré aux deux bouts | 18 | 8 | oui |

La lance, le guandao et le bâton sont des armes d'hast : elles frappent de loin, et la seconde main sur la hampe les rend bien plus faciles à diriger. Seule la partie métallique touche : le fer de la lance, la lame du guandao, les deux embouts du bâton. La hampe ne blesse pas et ne pare pas.

Les armes sont assemblées à partir de pièces simples (blocs, biseaux, cylindres) décrites dans `Config.Weapons` : lames brillantes à pointe effilée, gardes, pommeaux et ornements. Les bandits portent les mêmes modèles. Les pompons et cordons sont rigides et ne heurtent rien.

Les dégâts sont proportionnels à la vitesse de pointe du coup : dégâts = dégâts de base × (vitesse / 25 studs/s), entre ×0,3 et ×2,5. Un coup deux fois plus rapide fait deux fois plus mal, et un coup sous la vitesse minimale ne compte pas.

## Avatar

Ton avatar Roblox est visible à la première personne : en baissant les yeux tu vois ton torse, tes bras et tes jambes. La tête et les accessoires (chapeau, cheveux) restent cachés pour toi, sinon ils boucheraient la vue ; les autres joueurs voient l'avatar complet.

Les bras de l'avatar suivent les manettes et tiennent les armes, à la place des mains en forme de bloc. Cela demande un avatar R15 (le réglage par défaut) ; avec un avatar R6, les blocs restent affichés. Si la manette est plus loin que la longueur du bras, le bras se tend au maximum et l'arme le dépasse.

Les deux réglages `SHOW_AVATAR` et `AVATAR_ARMS_FOLLOW_HANDS` sont dans `src/shared/Config.luau`.

## Barres de vie et d'XP

Un petit panneau flotte au-dessus de ta main gauche et reste tourné vers tes yeux : lève la main pour le lire. Il montre trois barres :

- la vie (« 85 / 110 »), verte, qui vire au rouge quand elle baisse ;
- le Qi (« Qi 70 / 100 »), turquoise, qui alimente les techniques actives ;
- l'expérience (« Niv. 3 · 140 / 200 XP »), bleue.

Le panneau est dessiné dans le monde et non sur l'écran, ce qui le rend lisible dans le casque ; il passe par-dessus les armes et le bouclier. Pour le garder en permanence en bas du champ de vision, mets `Config.HUD.ANCHOR = "Head"` (`src/shared/Config.luau`) ; la taille et la position se règlent au même endroit. Le code est dans `src/client/Hud.client.luau`.

## Niveau du joueur

Tuer un bandit donne de l'expérience au joueur qui l'a blessé en dernier : 30 XP × le niveau du bandit. Les mannequins n'en donnent pas. Le gain s'affiche au-dessus du bandit, avec la progression vers le niveau suivant (« +60 XP (140 / 200) »).

Passer du niveau N au suivant demande 100 × N XP (100 pour le niveau 2, 200 pour le niveau 3, etc.), jusqu'au niveau 20. Chaque niveau donne :

- +10 points de vie maximaux (100 au niveau 1, 290 au niveau 20) ;
- +8 % de dégâts sur tous les coups (×2,52 au niveau 20).

Monter de niveau soigne complètement, et s'annonce par un texte devant le joueur, un halo doré, une gerbe de particules et un son. Le niveau et l'XP apparaissent aussi dans le tableau des scores (hors casque).

Le niveau et l'XP sont sauvegardés quand le joueur quitte, toutes les deux minutes et à la fermeture du serveur, puis retrouvés à la partie suivante. Pour que cela fonctionne dans Studio :

1. publie le jeu (**Fichier → Publier sur Roblox**) ;
2. active **Paramètres du jeu → Sécurité → Autoriser l'accès de Studio aux services d'API**.

Sans cela le jeu fonctionne normalement, mais un avertissement apparaît dans la fenêtre Sortie et les niveaux repartent de 1. Si la lecture de la sauvegarde échoue, rien n'est écrit pour ce joueur, afin de ne pas écraser sa progression. Pour remettre tout le monde à zéro, change `DATASTORE_NAME`. Les réglages sont dans `Config.PlayerLevel` (`src/shared/Config.luau`).

## Cultivation (arbre de techniques)

Chaque niveau gagné donne 1 point de Qi, à dépenser sur la **stèle de cultivation** : une grande dalle de pierre à gauche du point d'apparition, derrière la rangée de mannequins. Chaque technique y est une orbe, reliée par un trait d'or à celle qu'elle demande :

- grise : conditions non remplies ;
- dorée et palpitante : tu peux la débloquer ;
- verte : acquise.

Approche la main d'une orbe pour lire sa fiche (effet, coût, ce qui manque), puis serre la gâchette de préhension pour la débloquer (`E` ou `Q` sans casque). Les points restants s'affichent sur la barre d'XP (« · 2 pt »).

| Technique | Voie | Coût | Niveau | Effet |
| --- | --- | --- | --- | --- |
| Éveil du Qi (气感) | racine | 1 | 2 | +10 PV, +5 % de dégâts ; ouvre les trois voies |
| Chemise de fer (铁布衫) | Corps | 1 | 2 | -15 % de dégâts reçus |
| Corps de jade (玉体) | Corps | 2 | 5 | +40 PV |
| Corps de diamant (金刚不坏) | Corps | 3 | 9 | -15 % de dégâts reçus en plus, +2 PV par seconde |
| Intention de l'épée (剑意) | Lame | 1 | 2 | +15 % de dégâts |
| Riposte du dragon (龙反击) | Lame | 2 | 5 | riposte ×3 au lieu de ×2 sur un bandit vulnérable |
| Cœur d'épée (剑心) | Lame | 3 | 9 | parade parfaite : +25 dégâts renvoyés, bandit sonné 1 s de plus |
| Pas léger (轻功) | Souffle | 1 | 2 | +20 % de vitesse, +30 % de hauteur de saut |
| Méditation (打坐) | Souffle | 2 | 5 | +25 % d'expérience |
| Absorption du Qi (吸星大法) | Souffle | 3 | 9 | chaque bandit tué rend 15 % des PV |
| Onde de Qi (剑气) | Arts | 1 | 2 | technique active (voir plus bas) |
| Rugissement du lion (狮子吼) | Arts | 2 | 5 | technique active |
| Pas de l'éclair (闪电步) | Arts | 3 | 9 | technique active |

Chaque voie se débloque de bas en haut. L'arbre complet coûte 25 points pour 19 disponibles au niveau 20 : il faut choisir ses voies.

### Techniques actives (voie des Arts)

Elles se déclenchent avec un bouton et consomment du Qi, une réserve de 100 points qui se régénère de 6 par seconde et s'affiche sur la barre turquoise.

| Technique | Commande VR | Clavier | Qi | Délai | Effet |
| --- | --- | --- | --- | --- | --- |
| Onde de Qi | gâchette de la main armée | `F` | 30 | 1,5 s | une lame d'énergie part de la pointe de l'arme, dans l'axe de la lame, sur 45 studs ; 30 dégâts à chaque cible traversée |
| Rugissement du lion | bouton `Y` (manette gauche) | `R` | 50 | 8 s | repousse et sonne 2 s les bandits à moins de 14 studs, 12 dégâts |
| Pas de l'éclair | bouton `B` (manette droite) | `C` | 25 | 3 s | déplacement instantané de 16 studs dans la direction du regard, arrêté par les murs |

Les dégâts des techniques profitent des bonus de niveau et de cultivation, et comptent pour l'expérience. L'Onde de Qi demande une arme à lame en main (pas le bouclier) : pointe l'arme vers la cible avant de tirer. Les réglages sont dans le champ `Active` de chaque technique (`src/shared/Skills.luau`), le code dans `src/server/Techniques.luau` et `src/client/Techniques.client.luau`. Les techniques sont sauvegardées avec le niveau, et il n'y a pas de remise à zéro des points.

Le niveau donne aussi un **royaume de cultivation**, annoncé quand on y entre : Raffinement du Qi (炼气, niveau 1), Établissement des fondations (筑基, 5), Noyau d'or (金丹, 9), Âme naissante (元婴, 13), Transformation divine (化神, 17).

L'arbre est décrit dans `src/shared/Skills.luau` (techniques, coûts, effets, royaumes), la stèle dans `src/server/SkillTree.luau` et l'interaction dans `src/client/Skills.client.luau`.

## Bouclier

Deux boucliers ronds sont posés au début du râtelier et se saisissent comme une arme. Le plateau fait face à la direction pointée par la manette.

Un coup de bandit est bloqué si, au moment où il part, le bouclier est tenu du côté du bandit et près de son sabre : aucun dégât, un bruit sourd, une vibration dans la main, et le bandit est repoussé une demi-seconde. Un bouclier tenu dans le dos ou baissé ne protège pas.

Par rapport à la parade à l'épée, le bouclier est plus tolérant sur le placement, mais sonne le bandit moins longtemps (0,5 s contre 1,2 s). Il ne fait pas de dégâts.

## Parade parfaite

Juste avant de s'abattre, la lame du bandit passe de l'orange au blanc pendant 0,15 seconde. Si tu frappes activement son sabre avec ta lame à ce moment-là (au moins 12 studs/s), au lieu de simplement la laisser sur la trajectoire, la parade est parfaite :

- le bandit prend 20 points de dégâts et son sabre est rejeté en arrière ;
- il reste sonné 2,5 secondes, entouré d'un halo doré ;
- pendant ce temps, tes coups lui font le double de dégâts (riposte) ;
- une gerbe d'étincelles, une onde de choc lumineuse, un éclair de lumière, un tintement aigu et une longue vibration le signalent.

Une lame immobile sur la trajectoire donne toujours une parade normale. Le bouclier ne permet pas de parade parfaite. Les réglages sont en haut de `src/server/Enemies.luau`, et le multiplicateur de riposte dans `src/shared/Config.luau`.

## Ennemis

Les bandits arrivent par vagues dès qu'un joueur saisit une arme : un bandit à la première vague, un de plus à chaque vague, cinq au maximum. Ils apparaissent devant la grande salle et poursuivent le joueur le plus proche.

Avant de frapper, un bandit lève son sabre et la lame devient orange pendant 0,6 seconde. C'est le moment de reculer, ou de parer en plaçant ta propre lame contre la sienne : une parade réussie fait une étincelle et sonne le bandit un instant.

Chaque bandit porte l'une des huit armes du jeu, affichée au-dessus de sa tête, et se comporte en conséquence :

| Arme du bandit | Dégâts | Temps d'armement | Portée | Vitesse de marche |
| --- | --- | --- | --- | --- |
| Dague | 7 | 0,4 s | courte | 14 (rapide) |
| Épée | 12 | 0,6 s | moyenne | 11 |
| Épée longue | 20 | 0,85 s | longue | 9 |
| Hache | 24 | 1 s | moyenne | 8,5 (lent) |
| Sabre | 13 | 0,55 s | moyenne | 11,5 |
| Lance | 16 | 0,7 s | très longue | 10 |
| Guandao | 28 | 1,1 s | très longue | 8 (lent) |
| Bâton | 9 | 0,5 s | longue | 12 |

Le lancier pique surtout, de plus loin que toutes les autres armes ; le porteur de guandao donne de grands coups de taille très lents ; le bâton frappe vite et faiblement.

Les bandits varient leurs coups, et la pose d'armement annonce d'où le coup viendra (directions vues du bandit) :

| Coup | Trajectoire | Particularité |
| --- | --- | --- |
| Fendant | vertical, de haut en bas | — |
| Diagonale droite / gauche | de l'épaule vers la hanche opposée | — |
| Fauchage | horizontal, de sa droite vers sa gauche | dégâts ×0,9 |
| Revers | horizontal, de sa gauche vers sa droite | dégâts ×0,9 |
| Montant | vertical, de bas en haut | dégâts ×0,8, part un peu plus vite |
| Estoc | pointe en avant, le bras se détend | dégâts ×0,85, part plus vite, +1,5 stud de portée |

La dague pique surtout, l'épée connaît tous les coups, l'épée longue tous sauf le montant, et la hache ne donne ni estoc ni montant. Pour parer ou bloquer, ta lame ou ton bouclier doit se trouver sur la trajectoire du coup : une garde haute n'arrête pas un fauchage.

À partir de la vague 2, un bandit à la dague, à l'épée ou au sabre a 40 % de chances de porter une seconde arme (dague, épée ou sabre) dans la main gauche ; son nom l'indique (« Bandit · Épée + Dague »). Il frappe d'une main puis de l'autre, chaque arme gardant ses dégâts, sa portée et ses coups, et il enchaîne plus vite (temps entre deux attaques ×0,65). Les coups de la main gauche sont en miroir. Les armes à deux mains (épée longue, hache, lance, guandao, bâton) ne se portent jamais par paire.

### Mouvements

Les bandits bougent de façon souple plutôt que mécanique :

- **Approche :** chacun vise un point décalé autour du joueur, donc ils arrivent en arc et l'encerclent au lieu de s'empiler. Chacun a sa propre allure (±8 %).
- **Pivotement :** le corps tourne progressivement vers sa cible, sans se retourner d'un coup, y compris pendant qu'il arme une attaque.
- **Jeu de jambes :** entre deux attaques, un bandit tourne lentement autour du joueur, de côté, sans le quitter des yeux.
- **Corps :** les jambes suivent la vitesse réelle de marche, le bras libre balance, le buste se penche et rebondit, la poitrine respire à l'arrêt, la tête se tourne vers le joueur, et le buste recule quand un coup porte.

- **Attaques :** un coup se déroule en cinq temps enchaînés sans à-coup. Le bras monte pendant tout l'armement, le poignet cassé vers l'arrière et le buste en retrait ; il recule encore un peu quand la lame vire au blanc ; il s'abat en accélérant jusqu'à l'impact, le poignet fouettant vers l'avant et le buste plongeant ; il dépasse sa cible, emporté par l'élan ; puis il revient en garde en douceur. Un coup paré ou bloqué fait rebondir le bras, qui dépasse puis se stabilise.

Les durées d'un coup (armement, fenêtre de parade parfaite) n'ont pas changé : seule la façon dont le bras les parcourt est différente. Les réglages des gestes (`STRIKE_TIME`, `WRIST_COCK`, `FOLLOW_THROUGH`, `GUARD_RETURN_TIME`) sont en haut de `src/server/Enemies.luau`.

L'animation du corps est calculée par chaque joueur à chaque image (`src/client/EnemyAnimator.client.luau`) ; le serveur ne pilote que les bras armés, qui comptent pour la parade. Les réglages d'allure (`TURN_SPEED`, `FLANK_ANGLE`, `CIRCLE_SPEED`…) sont en haut de `src/server/Enemies.luau`, ceux de l'animation en haut du script client.

### Boss

Toutes les cinq vagues (après les vagues 5, 10, 15…), une fois le dernier bandit tombé, le **Seigneur de guerre** (首领) entre dans la cour : un géant 1,6 fois plus grand qu'un bandit, armé d'un guandao à sa taille, cerné d'un contour rouge. La vague suivante ne commence qu'après sa mort.

- **Points de vie :** 600 pour le premier, +50 % à chaque boss suivant (900, 1200…).
- **Coups d'arme :** 26 dégâts avant le bonus de niveau, avec la longue allonge du guandao géant. Ils se parent, se bloquent et se parent parfaitement comme ceux des bandits : la parade parfaite reste le meilleur moyen de le rendre vulnérable.
- **Frappe au sol :** toutes les 9 secondes, il lève son arme et un disque rouge s'étend sous lui pendant 1,4 seconde. À la fin, tous les joueurs restés au sol dans le disque (13 studs de rayon) prennent 30 dégâts. On l'évite en sortant du disque ou en sautant au moment de l'impact ; ni la parade ni le bouclier ne l'arrêtent.
- **Renforts :** à la moitié de sa vie, il appelle deux bandits.
- **Rage :** sous 30 % de vie, il attaque 35 % plus vite, marche plus vite et frappe le sol plus souvent, et son corps rougeoie.
- **Résistance :** le Rugissement du lion le blesse et le repousse, mais ne le sonne pas.
- **Récompense :** l'expérience de six bandits de son niveau.

Les réglages (`BOSS_EVERY`, `BOSS_HEALTH`, `BOSS_SLAM_…`, etc.) sont en haut de `src/server/Enemies.luau`.

### Tenues

Les bandits portent des tenues du catalogue Roblox, tirées au hasard : rônin noir, robe blanche, brigand masqué, puis ombre (niveau 2 et plus), assassin rouge (niveau 4 et plus) et capitaine casqué (niveau 6 et plus). Ceux qui n'ont ni masque ni casque gardent le chapeau de paille.

Les vêtements sont téléchargés au lancement du serveur. Tant qu'ils ne sont pas arrivés, ou si l'un d'eux a été retiré du catalogue, les bandits concernés apparaissent avec l'ancien corps en blocs, et un avertissement s'affiche dans la fenêtre Sortie.

Pour changer une tenue, ouvre la page d'un vêtement sur le catalogue Roblox et copie le nombre de son adresse dans la table `OUTFITS`, en haut de `src/server/Enemies.luau`. `USE_CATALOG_OUTFITS = false` revient aux bandits en blocs.

### Niveaux

Chaque bandit a un niveau de 1 à 10, affiché devant son nom (« Niv. 4 · Bandit · Épée »). Le niveau suit le numéro de la vague, à un niveau près ; la première vague est toujours au niveau 1.

| Niveau | Points de vie | Vitesse d'attaque | Dégâts |
| --- | --- | --- | --- |
| 1 | 50 | ×1 | ×1 |
| 3 | 65 | ×1,14 | ×1,2 |
| 5 | 80 | ×1,28 | ×1,4 |
| 10 | 118 | ×1,63 | ×1,9 |

La vitesse d'attaque divise le temps d'armement et le temps entre deux attaques : un bandit de niveau 10 à l'épée arme son coup en 0,37 s au lieu de 0,6 s. Le temps d'armement ne descend jamais sous 0,25 s. Les dégâts de l'arme augmentent de 10 % par niveau : une hache de niveau 10 inflige 46 points au lieu de 24, sur les 100 points de vie du joueur. Les réglages (`MAX_LEVEL`, `LEVEL_SPREAD`, `HEALTH_PER_LEVEL`, `ATTACK_SPEED_PER_LEVEL`, `DAMAGE_PER_LEVEL`) sont en haut de `src/server/Enemies.luau`.

Les vagues 1 à 8 ajoutent une arme chacune (épée, puis dague, sabre, hache, lance, épée longue, bâton, guandao) : le premier bandit de la vague porte la nouvelle arme. Ensuite les armes sont tirées au hasard.

Les réglages (équipement par arme, délais, nombre maximal) sont en haut de `src/server/Enemies.luau`.

## Collisions et sons

Une arme tenue est solide : elle s'arrête contre les murs, le sol, le décor et les autres armes, et la manette vibre au contact. Elle traverse en revanche les corps (joueurs, bandits, mannequins), pour que les coups passent au travers au lieu de bousculer la cible.

Chaque choc, coup porté, parade, blocage et saisie joue un son, tiré de la bibliothèque audio Roblox (catalogue ProSoundEffects). Pour en changer un, ouvre la Toolbox de Studio (onglet Audio), choisis un son et colle son numéro dans `Config.Sounds` (`src/shared/Config.luau`) sous la forme `"rbxassetid://NUMERO"`.

## Traînées

Chaque lame (les tiennes et celles des bandits) laisse une traînée claire quand elle bouge. Sa longueur suit la vitesse : à peine visible sur un geste lent, large sur un vrai coup. Elle aide aussi à lire l'angle d'attaque d'un bandit. La durée et la couleur se règlent avec `Config.TRAIL_LIFETIME` et `Config.TRAIL_COLOR` (`src/shared/Config.luau`).

## Modifier le jeu

- `src/shared/Config.luau` — armes (formes, dégâts), réglages de saisie, PvP, inclinaison de la lame dans la main.
- `src/server/Arena.luau` — sol, râtelier, mannequins.
- `src/server/Main.server.luau` — mains VR, saisie, validation des coups.
- `src/client/VRClient.client.luau` — suivi des manettes, détection des coups, mode clavier/souris.

Après une modification, régénère le fichier de place :

```bash
pwsh ./build.ps1
```

Le script écrase `RobloxVR-Melee.rbxlx` : ce que tu ajoutes à la main dans Studio (décors, modèles) doit être enregistré sous un autre nom, sinon ce sera perdu.

## Synchronisation en direct avec Rojo

[Rojo](https://rojo.space) 7.7.1 est installé dans `tools/rojo`, et son plugin dans le dossier de plugins de Studio. Il envoie chaque script enregistré dans `src` vers Studio, sans régénérer ni rouvrir le fichier.

1. Lance le serveur depuis ce dossier :

   ```bash
   & '.\tools\rojo\rojo.exe' serve
   ```

2. Dans Studio, onglet **Plugins → Rojo → Connect**.

Avec Rojo, `build.ps1` n'est plus nécessaire : enregistre la place depuis Studio, sous le nom que tu veux.
