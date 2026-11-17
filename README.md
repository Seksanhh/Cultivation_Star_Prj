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

L'arme tenue suit la manette sur ses 6 degrés de liberté : les 3 axes de position et les 3 axes de rotation, sans retard ni ballant. À chaque image, la main est placée exactement sur la manette. Elle reçoit aussi la vitesse réelle du geste, pour que les coups et les chocs restent justes. En contrepartie, une arme tenue peut traverser un mur. Si tu préfères qu'elle bute contre les murs, quitte à traîner un peu sur les gestes rapides, mets `Config.HAND_TRACKING = "Physique"` dans `src/shared/Config.luau`.

## Armes

| Arme | Modèle chinois | Dégâts de base | Vitesse minimale | Deux mains |
| --- | --- | --- | --- | --- |
| Dague | bishou (匕首) : lame droite à deux tranchants, pommeau en anneau | 12 | 8 | non |
| Épée | jian (剑) : lame droite à arête centrale, garde de bronze, pommeau de jade, pompon de soie rouge | 25 | 11 | non |
| Épée longue | changdao (长刀) : long sabre légèrement courbe à un tranchant, garde ronde en laiton, poignée tressée noire | 40 | 9 | oui |
| Hache | fu (斧) : fer en croissant, pique au sommet, manche laqué rouge et houppe de soie | 35 | 10 | oui |
| Sabre | dao (刀) : lame courbe à un tranchant qui s'élargit vers la pointe, garde ronde, pommeau en anneau, foulard de soie rouge | 28 | 10 | non |
| Lance | qiang (枪) : longue hampe de bois clair, fer en feuille de saule, houppe de crin rouge | 30 | 9 | oui |
| Guandao | guandao (偃月刀) : lourde lame en croissant sur une hampe, crochet au dos, contrepoids au talon | 45 | 8 | oui |
| Bâton | gun (棍) : long bâton ferré aux deux bouts | 18 | 8 | oui |

La lance, le guandao et le bâton sont des armes d'hast : elles frappent de loin, et la seconde main sur la hampe les rend bien plus faciles à diriger. Seule la partie métallique touche : le fer de la lance, la lame du guandao, les deux embouts du bâton. La hampe ne blesse pas et ne pare pas.

Les armes sont des modèles détaillés, construits par code dans `src/shared/Config.luau`. Ils n'utilisent aucun modèle de la Toolbox, donc rien ne peut disparaître ni contenir de script caché. Détails :

- **Lames :**
  - Les lames ont une vraie section : en losange avec une arête centrale pour la dague, l'épée et la lance ; dos épais, plat de lame et gorge sombre pour le sabre, l'épée longue et le guandao. Un biseau poli, plus clair, descend jusqu'au fil.
  - Les sabres sont courbes : 12° pour le dao, 8° pour l'épée longue et 24° pour le croissant du guandao. Leur pointe remonte vers le dos.
  - Les fonctions `blade`, `bevel`, `point` et `clipPoint` construisent les lames. Les réglages de chaque arme (longueur, largeurs, épaisseur, courbure, gorge) sont dans sa ligne `blade(...)`.
- **Montures :**
  - Les manches sont ronds. Les poignées sont tressées de cordon en losanges.
  - Les pommeaux en anneau sont faits de segments ; le pommeau de l'épée porte un cabochon de jade.
  - Gardes : en « montagne » pour l'épée, en disque pour le sabre et l'épée longue. Le fer de la hache est riveté.
  - Les houppes de crin sont faites de brins qui s'écartent.
- **Bouclier :** rotin en spirale, cerclé de clous de laiton.
- **Zones de frappe :** elles sont restées les boîtes d'avant, rendues invisibles (champ `Hidden`). Le modèle visible ne heurte rien (`Decor`). La détection des coups et des parades est donc exactement la même qu'avant.
- **Bandits :** ils portent les mêmes modèles. Quand un bandit arme son coup, tout l'acier visible de sa lame s'illumine (champ `Glow`), plus seulement une pièce.
- Les pompons et cordons sont rigides et ne heurtent rien.

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

Chaque niveau gagné donne 1 point de Qi, à dépenser dans l'**arbre de cultivation**.

**Ouvrir l'arbre :** appuie sur **`K`** (en VR : clic du joystick gauche). La même touche le referme, tout comme la croix en haut à droite. Pendant que l'arbre est ouvert, la souris est libérée pour cliquer.

**Lecture de l'arbre :** chaque voie est une colonne, avec la racine en bas au centre. Chaque technique est une case, reliée par un trait d'or à celle qu'elle demande :

- grise : conditions non remplies ;
- dorée : tu peux la débloquer ;
- verte : acquise.

**Débloquer :** survole ou clique une case pour lire sa fiche en bas du panneau (effet, coût, niveau, ce qui manque). Le bouton **Débloquer** apparaît quand la technique est disponible.

Les points restants s'affichent sur la barre d'XP (« · 2 pt (K) »).

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
| Épée volante (御剑术) | Arts | 4 | 13 | technique active |

Chaque voie se débloque de bas en haut. L'arbre complet coûte 29 points pour 19 disponibles au niveau 20 : il faut choisir ses voies.

### Techniques actives (voie des Arts)

Elles se déclenchent avec un bouton et consomment du Qi, une réserve de 100 points qui se régénère de 6 par seconde et s'affiche sur la barre turquoise.

| Technique | Commande VR | Clavier | Qi | Délai | Effet |
| --- | --- | --- | --- | --- | --- |
| Onde de Qi | gâchette de la main armée | `F` | 30 | 1,5 s | une lame d'énergie part de la pointe de l'arme, dans l'axe de la lame, sur 45 studs ; 30 dégâts à chaque cible traversée |
| Rugissement du lion | bouton `Y` (manette gauche) | `R` | 50 | 8 s | repousse et sonne 2 s les bandits à moins de 14 studs, 12 dégâts |
| Pas de l'éclair | bouton `B` (manette droite) | `C` | 25 | 3 s | déplacement instantané de 16 studs dans la direction du regard, arrêté par les murs |
| Épée volante | bouton `X` (manette gauche), maintenu | `V`, maintenu | 20, puis 2/s (6/s guidée) | 1 s | une épée de Qi qui vole où tu vises (voir ci-dessous) |

**Épée volante (御剑术) :**

- **Invocation :** un premier appui sur `X` fait apparaître une épée de Qi spectrale (le jian du jeu, lumineux, avec traînée et étincelles). Elle flotte derrière ton épaule gauche.
- **Guidage :** tant que tu maintiens `X`, l'épée vole vers le point que vise ta main gauche, dans l'axe de la manette, comme le « doigt d'épée » des films wuxia. Une petite sphère bleue, visible de toi seul, marque le point visé. Sans casque, on vise avec le regard en maintenant `V`.
- **Retour :** quand tu relâches le bouton, l'épée revient à ton épaule.
- **Dégâts :** l'épée blesse selon sa vitesse. Arrêtée sur une cible, elle ne fait rien : balaie la main pour qu'elle traverse les bandits. Elle fait 22 dégâts à 40 studs/s, de ×0,5 à ×1,5 selon la vitesse, et ne blesse pas sous 14 studs/s. Une même cible ne peut être touchée qu'une fois toutes les 0,4 seconde.
- **Portée :** l'épée ne s'éloigne pas à plus de 55 studs de toi.
- **Qi :** invoquer l'épée coûte 20 Qi. Ensuite elle consomme 2 Qi par seconde au repos et 6 Qi par seconde guidée. Le Qi ne se régénère pas tant qu'elle est là, et elle se dissipe quand il est épuisé.
- **Congédier :** un double appui rapide sur `X` ou `V` dissipe l'épée.

Les dégâts des techniques profitent des bonus de niveau et de cultivation, et comptent pour l'expérience. L'Onde de Qi demande une arme à lame en main (pas le bouclier) : pointe l'arme vers la cible avant de tirer. Les réglages sont dans le champ `Active` de chaque technique (`src/shared/Skills.luau`), le code dans `src/server/Techniques.luau` et `src/client/Techniques.client.luau`. Les techniques sont sauvegardées avec le niveau, et il n'y a pas de remise à zéro des points.

Le niveau donne aussi un **royaume de cultivation**, annoncé quand on y entre : Raffinement du Qi (炼气, niveau 1), Établissement des fondations (筑基, 5), Noyau d'or (金丹, 9), Âme naissante (元婴, 13), Transformation divine (化神, 17).

L'arbre est décrit dans `src/shared/Skills.luau` (techniques, coûts, effets, royaumes). L'interface de l'arbre est dans `src/client/Skills.client.luau`, avec ses touches dans `TOGGLE_KEYS`.

## Bouclier

Deux boucliers ronds sont posés au début du râtelier et se saisissent comme une arme. Le plateau fait face à la direction pointée par la manette.

Un coup de bandit est bloqué si, au moment où il part, le bouclier est tenu du côté du bandit et près de son sabre : aucun dégât, un bruit sourd, une vibration dans la main, et le bandit est repoussé une demi-seconde. Un bouclier tenu dans le dos ou baissé ne protège pas.

Chaque coup bloqué ou paré fait aussi trembler légèrement l'écran : un peu au bouclier, moins à la parade, un peu plus à la parade parfaite. Le tremblement dure 0,18 seconde. Il ne touche que la vue : les mains et les armes restent exactement sur les manettes. En VR, il est atténué (`VR_SCALE`), car une vue qui bouge sans la tête peut donner la nausée. Les réglages (amplitude, durée, intensité selon le blocage, `ENABLED` pour le couper) sont dans `Config.CAMERA_SHAKE` (`src/shared/Config.luau`), le code dans `src/client/CameraShake.client.luau`.

Par rapport à la parade à l'épée, le bouclier est plus tolérant sur le placement, mais sonne le bandit moins longtemps (0,5 s contre 1,2 s). Il ne fait pas de dégâts.

## Parade parfaite

Juste avant de s'abattre, la lame du bandit passe de l'orange au blanc pendant 0,15 seconde. Si tu frappes activement son sabre avec ta lame à ce moment-là (au moins 12 studs/s), au lieu de simplement la laisser sur la trajectoire, la parade est parfaite :

- le bandit prend 20 points de dégâts et son sabre est rejeté en arrière ;
- il reste sonné 0,6 seconde, entouré d'un halo doré ;
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

À partir de la vague 2, un combattant à l'épée ou au sabre a 40 % de chances de porter une seconde arme (épée ou sabre) dans la main gauche, et un assassin 75 % de chances de porter une seconde dague ; son nom l'indique (« Combattant · Épée + Sabre »). Il frappe d'une main puis de l'autre, chaque arme gardant ses dégâts, sa portée et ses coups, et il enchaîne plus vite (temps entre deux attaques ×0,65). Les coups de la main gauche sont en miroir. Les armes à deux mains (épée longue, hache, lance, guandao, bâton) ne se portent jamais par paire.

### Mouvements

Les bandits bougent de façon souple plutôt que mécanique :

- **Approche :** chacun vise un point décalé autour du joueur, donc ils arrivent en arc et l'encerclent au lieu de s'empiler. Chacun a sa propre allure (±8 %).
- **Pivotement :** le corps tourne progressivement vers sa cible, sans se retourner d'un coup, y compris pendant qu'il arme une attaque.
- **Jeu de jambes :** entre deux attaques, un bandit tourne lentement autour du joueur, de côté, sans le quitter des yeux.
- **Corps :** les jambes suivent la vitesse réelle de marche, le bras libre balance, le buste se penche et rebondit, la poitrine respire à l'arrêt, la tête se tourne vers le joueur, et le buste recule quand un coup porte.

- **Attaques :** un coup se déroule en cinq temps enchaînés sans à-coup. Le bras monte pendant tout l'armement, le poignet cassé vers l'arrière et le buste en retrait ; il recule encore un peu quand la lame vire au blanc ; il s'abat en accélérant jusqu'à l'impact, le poignet fouettant vers l'avant et le buste plongeant ; il dépasse sa cible, emporté par l'élan ; puis il revient en garde en douceur. Un coup paré ou bloqué fait rebondir le bras, qui dépasse puis se stabilise.

Les durées d'un coup (armement, fenêtre de parade parfaite) n'ont pas changé : seule la façon dont le bras les parcourt est différente. Les réglages des gestes (`STRIKE_TIME`, `WRIST_COCK`, `FOLLOW_THROUGH`, `GUARD_RETURN_TIME`) sont en haut de `src/server/Enemies.luau`.

L'animation du corps est calculée par chaque joueur à chaque image (`src/client/EnemyAnimator.client.luau`) ; le serveur ne pilote que les bras armés, qui comptent pour la parade. Les réglages d'allure (`TURN_SPEED`, `FLANK_ANGLE`, `CIRCLE_SPEED`…) sont en haut de `src/server/Enemies.luau`, ceux de l'animation en haut du script client.

### Dash

Les bandits font de brusques dashs au ras du sol, sur quelques mètres. Chaque dash soulève un nuage de poussière et fait un bruit de fente, ce qui permet de le voir et de l'entendre venir. Le corps laisse aussi derrière lui une traînée claire, de la tête aux genoux, qui s'efface en 0,3 seconde. Sa durée et sa couleur se règlent avec `DASH_TRAIL_LIFETIME` et `DASH_TRAIL_COLOR`. Il y a trois sortes de dash :

- **Ruée :** encore loin, le bandit comble la distance d'un coup. Il s'arrête à sa portée, sans te foncer dedans, puis attaque normalement avec la lame qui s'illumine.
- **Esquive :** juste après avoir été touché, il bondit parfois en arrière, en biais, pour reprendre ses distances.
- **Pas chassé :** pendant qu'il tourne autour de toi, il fait parfois un brusque écart de côté. Jamais juste avant d'attaquer.
- **Esquive réflexe (latérale) :** quand ta lame arrive vite tout près de lui (plus de 18 studs/s, à moins de 8 studs), il peut s'écarter d'un dash de côté, du côté opposé à ta lame. Il ne tente sa chance qu'une fois par coup, et jamais pendant sa propre attaque : un coup qui suit sa parade ou son attaque reste le meilleur moment pour frapper.
- **Zigzag (latéral) :** en approchant, quand il n'est plus très loin, il fait des écarts de côté tout en avançant.

Un temps de recharge sépare deux dashs. Un dash est raccourci devant un mur et annulé s'il finirait hors de l'arène. Le bandit ne dashe pas quand il est sonné ou vulnérable.

La fréquence dépend de la classe (champ `DashRate`) :

| Classe | Fréquence des dashs |
| --- | --- |
| Fermier | ×0,35 |
| Combattant | ×1 |
| Moine | ×1,2 |
| Assassin | ×2 |
| Boss | ×0,5 |

Les réglages (vitesse, distances, chances, recharge) sont dans les constantes `DASH_*` en haut de `src/server/Enemies.luau`. Le son est `Config.Sounds.Dash`.

### Mort et ragdoll

À sa mort, un bandit s'effondre de façon physique au lieu de tomber en morceaux :

- **Articulations :**
  - Chaque articulation devient une rotule limitée comme celles d'un vrai corps : le genou plie sans se tordre, la tête bascule sans faire le tour du cou.
  - Une légère friction évite l'effet pantin.
- **Chute :** le corps part dans le sens du coup fatal, à l'opposé du joueur qui l'a tué. Ses armes lui tombent des mains et restent au sol.
- **Disparition :** le nom et la barre de vie disparaissent aussitôt. Le corps reste 6 secondes (10 pour le boss), puis s'efface en fondu.

Le code est dans `src/server/Ragdoll.luau` : limites de chaque articulation, force de projection. Les durées sont dans `CORPSE_TIME` et `BOSS_CORPSE_TIME`, en bas de `src/server/Enemies.luau`. Le ragdoll fonctionne avec les corps R15 et R6.

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

### Classes

Chaque bandit appartient à une classe, affichée dans son nom (« Niv. 3 · Moine · Bâton »), qui fixe ses armes, ses tenues, sa silhouette et ses forces :

| Classe | Dès la vague | Armes | Tenues | Vie | Dégâts | Vit. d'attaque | Marche | XP |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Fermier | 1 | bâton, dague, hache (vague 3) | habits de paysan, chapeau de paille | ×0,8 | ×0,8 | ×0,9 | ×0,95 | ×0,75 |
| Combattant | 2 | épée, sabre, lance (4), épée longue (5), guandao (7) ; 40 % portent une 2e épée ou un 2e sabre | rônin noir, robe blanche, brigand masqué, capitaine casqué (niv. 6) | ×1 | ×1 | ×1 | ×1 | ×1 |
| Moine | 3 | bâton surtout, lance (5) | robes shaolin safran, brune, grise, rouge (niv. 6), crâne rasé | ×1,15 | ×0,9 | ×1,15 | ×1,1 | ×1,2 |
| Assassin | 4 | dague surtout, sabre ; 75 % portent une 2e dague | ombre, assassin rouge (niv. 6) | ×0,75 | ×1,1 | ×1,25 | ×1,2 | ×1,1 |

Une classe fait son entrée en tête de sa première vague, annoncée avec le numéro de la vague. Ensuite, les bandits sont tirés au hasard parmi les classes déjà apparues : les fermiers, nombreux au début, se raréfient au fil des vagues, tandis que les autres deviennent plus fréquents. Les fermiers ont la silhouette « Homme » ou « Corps de base 2 », les moines et assassins les deux « Corps de base » ; les combattants les trois. Le boss est un combattant et porte la tenue de capitaine.

Tout se règle dans la table `CLASSES` (en haut de `src/server/Enemies.luau`) : armes et leur poids au tirage, vague d'apparition, chance de seconde arme, multiplicateurs, chapeau de paille, corps permis. Pour ajouter une tenue à une classe, ajoute une ligne à `OUTFITS` avec son champ `Class`.

### Tenues

Les bandits portent des tenues du catalogue Roblox, tirées au hasard parmi celles de leur classe. Ceux qui n'ont ni masque ni casque gardent le chapeau de paille, sauf les moines.

Les tenues sont enfilées sur des corps réalistes R15 (membres arrondis, visage d'homme animé), tous publiés gratuitement par Roblox : le lot « Homme » et deux « Corps de base » (Charlie et Parker), coiffés du « Visage d'homme ». Chaque tenue est préparée sur chaque corps, et chaque bandit en tire une combinaison au hasard. Leurs bras restent tendus (coude et poignet fixes) et tiennent l'arme dans la main. Pour changer de corps, copie dans la table `BODY_SHAPES` les numéros des pièces d'un lot (tête, buste, bras, jambes) relevés sur sa page du catalogue. `USE_REALISTIC_BODIES = false` revient aux personnages R6 carrés.

Les vêtements sont téléchargés au lancement du serveur. Tant qu'ils ne sont pas arrivés, ou si l'un d'eux a été retiré du catalogue, les bandits concernés apparaissent avec l'ancien corps en blocs, et un avertissement s'affiche dans la fenêtre Sortie.

### Modèles 3D importés

Une classe peut aussi porter un personnage 3D réaliste importé, à la place des tenues du catalogue : modèles Sketchfab préparés avec Blender, puis passés dans **Avatar Setup** de Studio. Ces modèles se rangent dans `ServerStorage` → `BanditModels`. Chaque modèle (ou dossier de modèles) porte le nom d'une classe (`Fermier`, `Combattant`, `Moine`, `Assassin`) ou `Boss` pour le Seigneur de guerre.

- **Préparation :** au lancement du serveur, chaque modèle est vérifié : il doit être R15 et avoir des mains et des épaules. Il est ensuite mis à la taille d'un corps réaliste (`CUSTOM_MODEL_HEIGHT`, du dessous des pieds au sommet de la tête). Un modèle inutilisable est ignoré, avec un avertissement dans la fenêtre Sortie.
- **Tirage :** une classe qui a un modèle 3D ne porte plus que lui (`PREFER_CUSTOM_MODELS`) ; les autres classes gardent leurs tenues. Les modèles 3D n'ont pas de chapeau de paille.
- **Réglages :** `USE_CUSTOM_MODELS = false` les désactive. Les réglages sont en haut de `src/server/Enemies.luau`. La préparation dans Blender, l'import et les crédits des auteurs (licence CC BY, à citer dans la description du jeu) sont décrits dans `tools/blender/README.md`.
- **Sauvegarde :** les modèles vivent dans la place, pas dans `src`. Enregistre-la depuis Studio : `build.ps1` les effacerait.

Pour changer une tenue, ouvre la page d'un vêtement sur le catalogue Roblox et copie le nombre de son adresse dans la table `OUTFITS`, en haut de `src/server/Enemies.luau`. `USE_CATALOG_OUTFITS = false` revient aux bandits en blocs.

### Niveaux

Chaque bandit a un niveau de 1 à 10, affiché devant son nom (« Niv. 4 · Combattant · Épée »). Le niveau suit le numéro de la vague, à un niveau près ; la première vague est toujours au niveau 1.

| Niveau | Points de vie | Vitesse d'attaque | Dégâts |
| --- | --- | --- | --- |
| 1 | 50 | ×1 | ×1 |
| 3 | 65 | ×1,14 | ×1,2 |
| 5 | 80 | ×1,28 | ×1,4 |
| 10 | 118 | ×1,63 | ×1,9 |

La vitesse d'attaque divise le temps d'armement et le temps entre deux attaques : un bandit de niveau 10 à l'épée arme son coup en 0,37 s au lieu de 0,6 s. Le temps d'armement ne descend jamais sous 0,25 s. Les dégâts de l'arme augmentent de 10 % par niveau : une hache de niveau 10 inflige 46 points au lieu de 24, sur les 100 points de vie du joueur. Les réglages (`MAX_LEVEL`, `LEVEL_SPREAD`, `HEALTH_PER_LEVEL`, `ATTACK_SPEED_PER_LEVEL`, `DAMAGE_PER_LEVEL`) sont en haut de `src/server/Enemies.luau`.

Les armes dépendent de la classe du bandit (voir « Classes ») : certaines n'apparaissent qu'à partir d'une vague donnée.

Les réglages (équipement par arme, délais, nombre maximal) sont en haut de `src/server/Enemies.luau`.

## Collisions et sons

Une arme tenue est solide : elle s'arrête contre les murs, le sol, le décor et les autres armes, et la manette vibre au contact. Elle traverse en revanche les corps (joueurs, bandits, mannequins), pour que les coups passent au travers au lieu de bousculer la cible.

Chaque choc, coup porté, parade, blocage et saisie joue un son, tiré de la bibliothèque audio Roblox (catalogue ProSoundEffects). Pour en changer un, ouvre la Toolbox de Studio (onglet Audio), choisis un son et colle son numéro dans `Config.Sounds` (`src/shared/Config.luau`) sous la forme `"rbxassetid://NUMERO"`.

## Traînées

Chaque lame (les tiennes et celles des bandits) laisse une traînée claire quand elle bouge. Sa longueur suit la vitesse : à peine visible sur un geste lent, large sur un vrai coup. Elle aide aussi à lire l'angle d'attaque d'un bandit. La durée et la couleur se règlent avec `Config.TRAIL_LIFETIME` et `Config.TRAIL_COLOR` (`src/shared/Config.luau`).

## Ciel et éclairage

Le temple baigne dans un coucher de soleil doré (17 h 36) : soleil bas et ombres longues, brume chaude sur les lointains, nuages volumétriques en 3D qui dérivent lentement, ciel haute définition de Roblox avec soleil, lune et étoiles. Le moteur d'éclairage **Future** donne des ombres douces aux lanternes et des reflets du ciel sur les métaux ; les lanternes vacillent comme des flammes. Un léger post-traitement ajoute un halo autour des lumières vives, des rayons de soleil et un peu de contraste. Il n'y a pas de flou de profondeur, qui fatigue les yeux en VR.

- **Réglages :** heure, couleurs, brume, nuages et effets en haut de `src/server/Ambience.luau`.
- **Autre ciel :** dans Studio, prends un ciel dans la Toolbox (recherche « skybox ») et glisse son objet `Sky` dans `Lighting`. Le script le garde tel quel. Tu peux aussi copier ses numéros d'images dans la table `SKY`.
- **Moteur Future :** il est réglé dans `default.project.json` (`Lighting.Technology`), car un script ne peut pas le changer. Si Rojo ne l'applique pas, choisis-le à la main : `Lighting` → propriété `Technology` → `Future`. Sur les casques autonomes peu puissants, Roblox réduit de lui-même la qualité.

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
