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
| Frapper à mains nues | Frapper avec une main vide | Clic gauche, main droite vide |
| Dégainer | Grip sur la poignée, à la hanche gauche | `G` (main droite) |
| Rengainer | Lâcher l'arme garde contre l'entrée du fourreau | `G` (main droite) |
| Lancer une arme | Lâcher le grip en plein geste | — |
| Rappeler l'arme lancée | Main vide, garder le grip serré un instant | `T` (main droite) |
| Double saut | Sauter (bouton `A`) une seconde fois en l'air | `Espace` en l'air |
| Courir sur un mur | En l'air, lancé le long d'un mur | idem |
| Vol plané | Garder le saut enfoncé en tombant | `Espace` maintenu |
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

## Fourreau

Chaque joueur porte un fourreau de laque rouge cerclé de laiton à la hanche gauche, avec un sabre rangé dedans à chaque apparition.

- **Dégainer :** en VR, porte une main à la poignée qui dépasse de la hanche (un contour blanc apparaît) et serre le grip, comme pour saisir n'importe quelle arme. Au clavier, `G` dégaine dans la main droite.
- **Rengainer :** en VR, amène la garde de l'arme contre l'entrée du fourreau (à moins de 1,8 stud) et relâche le grip : l'arme glisse dedans, avec son bruit de lame qui rentre. Au clavier, `G` rengaine l'arme de la main droite.
- **Armes :** la dague, l'épée et le sabre entrent au fourreau. L'épée longue et les armes d'hast sont trop longues pour la hanche. Le fourreau s'ajuste à la longueur et à la largeur de la lame rangée, y compris pour une arme prise sur le râtelier.
- **Arme rangée :** elle ne heurte rien, ne pèse rien et ne frappe pas. Seul son propriétaire peut la dégainer.
- **Arme abandonnée :** le sabre de départ lâché par terre revient seul au fourreau après le délai habituel (`WEAPON_RETURN_TIME`), si le fourreau est vide. Sinon il disparaît. À la mort, une arme du râtelier qui était au fourreau retourne au râtelier.

Les réglages sont dans `Config.SCABBARD` (`src/shared/Config.luau`) : armes acceptées, arme de départ (`START_WEAPON`, `nil` pour un fourreau vide), position et inclinaison à la hanche, distance pour rengainer, touche. Le code est dans `src/server/Scabbard.luau`.

## Frappe de dégainé (居合, iai)

Dégainer et frapper dans le même geste donne un coup critique : le premier coup porté moins de 0,8 seconde après avoir tiré la lame du fourreau, assez vite (14 studs/s), fait double dégâts.

Pendant cette fenêtre, la traînée de la lame est dorée, et une fine lame de Qi dorée prolonge la pointe de 1,5 stud : le coup porte un peu plus loin (`REACH_BONUS`). Un coup réussi affiche « 居合 Iai », avec une fente dorée, un reflet en étoile, un éclair et un sifflement métallique. La fenêtre ne sert qu'une fois par dégainé. Réglages : `Config.IAI`.

## Lancer d'armes et rappel

**Lancer :** lâcher une arme en plein geste la lance (main à 18 studs/s ou plus). Elle part plus vite que la main (×1,6, 110 studs/s au plus), file sans heurter son lanceur et blesse la première cible traversée par sa lame (dégâts de l'arme ×1,2 selon la vitesse, affichés « 投 Lancer »). Elle s'y arrête et tombe. La dague se lance bien, la lance aussi, comme un javelot. Une arme lâchée doucement tombe simplement, comme avant.

**Rappel :** main vide, garder le grip serré un instant (0,4 s) sans rien à saisir ramène la dernière arme lancée dans cette main, en vol courbe et en tournoyant. Au clavier, `T` la rappelle dans la main droite. Le rappel coûte 15 Qi, et l'arme doit être à moins de 80 studs. Une arme revenue au râtelier ne se rappelle plus.

Réglages : `Config.THROW` et `Config.RECALL`.

## Combos de calligraphie

Enchaîner les bons traits de lame trace un caractère chinois en encre d'or dans l'air, et ce caractère devient le sort : il apparaît devant le joueur, lumineux, puis part produire son effet (voir le tableau). Un trait est un geste franc de la pointe (au moins 11 studs/s, 1,2 stud de long), lu tel que le joueur le voit : vertical ou horizontal à 35° près, diagonale entre les deux. Les traits d'un même caractère doivent se suivre à moins de 2,5 secondes, et un trait parasite glissé entre deux traits (lame repositionnée un peu vite) est toléré (`ALLOW_EXTRA_STROKE`). Un geste qui monte (lame ramenée en garde) n'est jamais un trait, pas plus qu'un geste court (moins de 1,6 stud face au joueur). Un fendant qui ralentit un instant au milieu reste un seul trait. Conseil pour 川 : entre deux fendants, remonte la lame par le même chemin, bien droit ; un retour de côté peut être lu comme 横 et donner 十 à la place. Chaque trait reconnu s'affiche devant les yeux en encre d'or (竖 vertical, 横 horizontal, 丿 diagonale gauche, ㇏ diagonale droite, 点 estoc), puis le nom du combo ; un combo en recharge s'affiche en gris. Avec `Calligraphy.DEBUG = true`, chaque trait, reconnu ou refusé, s'écrit aussi dans la fenêtre Sortie avec son déplacement, ainsi que chaque sort lancé ou refusé par le serveur (et pourquoi), pour régler les seuils. Au clavier, un clic donne toujours un fendant : seul 川 (trois clics rapides) y est possible.

| Caractère | Traits | Effet | Recharge |
| --- | --- | --- | --- |
| 十 Croix du sabre | fendant (haut → bas), puis horizontal | le caractère file vers la cible la plus proche devant (visée dans un cône de 35°, 18 studs), fend tout sur son passage (30 dégâts) et éclate en croix à l'arrivée | 4 s |
| 人 Souffle de l'homme | diagonale vers la gauche, puis vers la droite | le caractère, vert, revient se fondre dans la poitrine du joueur : rend 15 % des PV et 20 Qi | 10 s |
| 川 Trois cascades | trois fendants | le caractère file droit devant et fait tomber trois lames de Qi sur son chemin (22 dégâts chacune) | 6 s |
| 大 Grande onde | horizontal, diagonale gauche, diagonale droite | le caractère monte au-dessus du joueur et s'abat au sol : onde de 14 studs, 35 dégâts, repousse et sonne 1,2 s | 12 s |
| 刺 Percée du dragon | trois estocs | le caractère part comme une flèche de Qi et transperce tout sur 24 studs (28 dégâts) | 7 s |

Chaque trait reconnu donne une petite vibration. Il faut tenir une arme à lame. Les caractères, leurs traits et leurs effets sont dans `src/shared/Calligraphy.luau`. La reconnaissance est dans `src/client/Calligraphy.client.luau`, les effets dans `src/server/Combos.luau`.

## Mains nues

Une main vide frappe aussi : un coup de poing assez rapide (au moins 9 studs/s) blesse le bandit, le mannequin ou le joueur qu'il touche.

- **Dégâts :** 8 de base. Comme pour les armes, ils suivent la vitesse du coup et profitent des bonus de niveau, de cultivation et de riposte. Le poing reste la plus faible des armes : la dague fait 12.
- **Limites :** une main posée sur la hampe d'une arme à deux mains ne frappe pas. Le poing ne pare pas et ne bloque pas.
- **Retour :** un son de choc plus sourd que celui d'une lame, et une vibration dans la manette.

Les réglages (dégâts, vitesse minimale, taille de la zone de frappe, `ENABLED` pour désactiver) sont dans `Config.FIST` (`src/shared/Config.luau`).

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
- une gerbe d'étincelles étirées, un reflet en étoile, une onde de choc rayonnante, des rayons, un éclair de lumière, un tintement aigu et une longue vibration le signalent.

Une lame immobile sur la trajectoire donne toujours une parade normale.

Les effets des parades et des blocages utilisent des textures de packs de VFX gratuits du Creator Store de Roblox : traits d'étincelles, reflet en étoile, impact, anneau rayonnant, rayons, halo, anneau. Seules les images sont reprises, par leur numéro : les émetteurs de particules sont construits par le code, donc aucun script de la Toolbox n'entre dans le jeu. Les numéros sont dans la table `VFX_TEXTURES` et les effets dans `perfectParryVfx`, `parryVfx` et `blockVfx` (`src/server/Enemies.luau`). Le bouclier ne permet pas de parade parfaite. Les réglages sont en haut de `src/server/Enemies.luau`, et le multiplicateur de riposte dans `src/shared/Config.luau`.

## Ennemis

Les bandits arrivent par vagues dès qu'un joueur saisit une arme ou porte un premier coup de poing (sur un mannequin, par exemple) : un bandit à la première vague, un de plus à chaque vague, cinq au maximum. Ils apparaissent devant la grande salle et poursuivent le joueur le plus proche.

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

### Archers et lanceurs de couteaux

Deux classes se battent à distance. Elles gardent leurs distances, se décalent de côté entre deux tirs, reculent si on s'approche, et ne sortent leur dague qu'au contact.

- **Archer** (dès la vague 5) : un arc devant la poitrine. Quand il vise, une flèche apparaît, pointe orangée, et l'arc se bande avec un bruit de souffle : un peu plus d'une seconde plus tard, la flèche part (14 dégâts au niveau 1).
- **Lanceur de couteaux** (dès la vague 6) : son bras armé recule et sa lame s'illumine, puis il lance une salve de trois couteaux qui tournoient (8 dégâts chacun).

Les projectiles volent vraiment, avec une légère chute et une traînée claire. Leur sifflement voyage avec eux, on les entend arriver. Ils visent le haut du buste et anticipent à moitié le déplacement du joueur. Pour s'en protéger :

- **Les couper en vol :** une lame qui croise le projectile en mouvement rapide le coupe en deux (étincelles dorées, son de parade parfaite).
- **Les dévier :** une lame tenue immobile sur le trajet le dévie (étincelles orangées).
- **Les bloquer :** le bouclier les arrête.
- **Les éviter :** se décaler suffit, ils ne tournent pas.

Un projectile qui manque se plante dans le décor (flèche) ou tombe (couteau). Il ne blesse jamais les bandits. Les réglages de chaque classe sont dans le champ `Ranged` de la table `CLASSES` (`src/server/Enemies.luau`), le vol dans `src/server/Projectiles.luau`.

### Attaques coordonnées

À partir de la vague 3, toutes les 7 à 12 secondes, deux bandits au contact du même joueur et de deux côtés différents (au moins 70° d'écart) frappent ensemble. On entend les deux lames dégainer en même temps, et leurs lames virent au **rouge** au lieu de l'orange. Leur armement commun est un peu plus long (0,95 s) pour laisser le temps de lire la situation : parer l'un et esquiver l'autre, ou parer des deux mains. Réglages : `COORD_*` en haut de `src/server/Enemies.luau`.

### Maître d'armes

À partir de la vague 7, une vague impaire sur deux compte un **maître d'armes** : une robe blanche, un casque, une épée ou un sabre. Il a plus de deux fois plus de vie et frappe plus fort et plus vite. Il vaut trois fois l'expérience d'un bandit.

Surtout, il **pare** : sa garde suit ta lame, avec un temps de retard (0,35 s). Un coup qui arrive du côté de sa garde est paré (étincelles, choc dans la main) et il riposte aussitôt. Pour le toucher :

- **feinter :** montrer la lame d'un côté, puis frapper vite de l'autre ;
- **frapper pendant son attaque :** il ne pare pas en frappant ;
- **parer parfaitement**, puis riposter pendant qu'il est sonné et vulnérable ;
- **le sonner** avec une technique (Rugissement du lion, Grande onde).

Il dévie aussi les armes lancées du côté de sa garde. Réglages : `MASTER_*` en haut de `src/server/Enemies.luau`.

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
| Archer | 5 | arc (tir à distance), dague au contact | archer en toile, archer brigand | ×0,7 | ×1 | ×1 | ×1 | ×1,1 |
| Lanceur | 6 | salves de trois couteaux, dague au contact | lanceur sombre, lanceur rouge (niv. 6), masque de brigand | ×0,8 | ×1 | ×1,1 | ×1,1 | ×1,1 |
| Maître d'armes | 7 (une vague impaire sur deux) | épée ou sabre ; pare les coups du côté de sa garde | robe blanche, casque | ×2,2 | ×1,2 | ×1,25 | ×1,05 | ×3 |

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

Les chocs de lames (arme contre arme, parade, parade parfaite) sont des prises « Blade Hits Metal Rod » et « Sword Impact » du catalogue ProSoundEffects. Elles ont été retenues après analyse du son : un seul impact, une attaque sèche, de l'aigu et une résonance métallique qui tinte. Les prises de coups dans le vide, de frottement ou de plusieurs chocs enchaînés ont été écartées. Chacun de ces sons a trois prises (champ `Ids`), tirées au hasard à chaque choc avec une légère variation de hauteur, pour que deux parades ne sonnent jamais pareil. Les prises de lame contre tige sont jouées un peu plus bas (`Pitch` 0,8 à 0,85) pour sonner comme un sabre lourd. Le blocage au bouclier garde son bruit de bois.

## Qinggong (轻功)

L'art de la légèreté : trois mouvements aériens, contre du Qi.

- **Double saut :** sauter une seconde fois en l'air (8 Qi). Un anneau de Qi apparaît sous les pieds.
- **Course sur les murs :** en l'air, lancé assez vite (10 studs/s) le long d'un mur, on s'y accroche et on court dessus jusqu'à 1,4 seconde (6 Qi par seconde). Sauter pendant la course repousse du mur, vers le haut et vers l'avant, et rend le double saut.
- **Vol plané :** garder le saut enfoncé en tombant limite la chute à 8 studs/s (5 Qi par seconde).

Le saut est `Espace` au clavier et le bouton `A` de la manette droite en VR. Ces mouvements font bouger la vue sans que la tête bouge : en VR, ils peuvent donner la nausée. `Config.QINGGONG.ENABLED = false` les désactive. Réglages : `Config.QINGGONG`, code dans `src/client/Qinggong.client.luau`.

## Tribulation céleste (天劫)

Atteindre le niveau d'un nouveau royaume (5, 9, 13, 17) ne suffit plus : il faut le **consolider** en survivant à la foudre du ciel.

- **Déclenchement :** au passage de niveau, « 天劫 Le ciel s'assombrit… ». La tribulation attend que les bandits en jeu soient tous tombés, puis les vagues se mettent en pause.
- **Déroulement :** le ciel vire au violet sombre, le tonnerre gronde. La foudre tombe là où se tient le joueur : 6 éclairs pour le premier royaume, 2 de plus pour chaque royaume suivant, de plus en plus rapprochés. Chaque éclair est annoncé par un cercle violet au sol qui se resserre pendant 1,2 seconde.
- **Se défendre :** sortir du cercle évite l'éclair. **Lever sa lame**, pointe vers le ciel au-dessus de la tête, au moment où il tombe l'absorbe : pas de dégâts, et 15 Qi en plus. Un éclair reçu coûte 12 % des points de vie maximaux.
- **Réussite :** « Percée ! », le royaume est consolidé, et le bonus est permanent et sauvegardé : +5 % de dégâts et +10 points de vie maximaux par royaume consolidé. Le Qi est rempli, les points de vie aussi.
- **Échec :** mourir l'interrompt. Elle revient 15 secondes après la réapparition.

Une sauvegarde d'avant cette mise à jour garde ses royaumes déjà atteints, considérés comme consolidés. Réglages : `Config.TRIBULATION`, code dans `src/server/Tribulation.luau`.

## Souffle des lames

Une arme tenue fait entendre le vent qu'elle fend : un souffle discret sur un geste lent, un sifflement aigu et fort sur un vrai coup.

- **Ce qui le règle :** le volume et la hauteur suivent la vitesse de la pointe de la lame. C'est le geste de la manette, rotation du poignet comprise, sans compter le déplacement du joueur. Le souffle démarre dès 6 studs/s et atteint son maximum à 45 studs/s. Il monte aussitôt avec le geste, puis retombe en un peu plus d'un dixième de seconde.
- **Pour tous les joueurs :** on entend aussi les lames des autres joueurs, en 3D. Le bouclier, sans lame, ne souffle pas, pas plus qu'une arme posée ou rangée au fourreau.
- **Son :** une boucle de vent de ProSoundEffects, choisie pour son souffle régulier, sans rafales ni sifflement propre.

Les réglages (vitesses, volume, hauteurs, `ENABLED`) sont dans `Config.BLADE_WIND` (`src/shared/Config.luau`), le code dans `src/client/BladeWind.client.luau`.

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
