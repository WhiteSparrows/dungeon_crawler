# Donjon en Direct

Roguelite tour par tour pour Android (Flutter). La Terre a été rachetée par un conglomérat galactique
du divertissement : vous êtes le candidat du jour d'un donjon filmé en direct, commenté par MAESTRO,
un animateur cabotin. Objectif : descendre le plus bas possible.

## Jouer

- **Tap** sur une case : déplacement automatique (s'arrête si un monstre apparaît).
- **Tap** sur une case voisine ou **swipe** : un pas / une attaque.
- **Tap sur soi** : attendre (ou descendre si on est sur l'escalier).
- **SAC** : équiper une arme / un accessoire, boire, jeter (chaque action prend un tour).
- **Coffre clignotant** (en bas à droite) : ouvrir ses loot boxes (gratuit, hors tour).
- Clavier (PC) : flèches / ZQSD / WASD, `Espace` attendre, `Entrée` descendre, `P` potion de soin,
  `I` sac, `B` loot box, `R` rejouer.
- **Trophée** (en haut) : tableau d'honneur des succès, commentés par MAESTRO.
- **Barre du show** (sous les PV) : audience, hype, tours avant démolition, jauges des sponsors.
  La toucher ouvre la régie (sponsors, talents).
- Builds debug uniquement : appui long sur « ETAGE » = une loot box Or ; appui long sur la barre du
  show = téléportation sur l'escalier.

## Mécaniques

- **Fioles mystère** : 7 effets (régénération, force, robustesse, poison, téléportation, clairvoyance,
  rage) avec un aspect différent à chaque run ; on les identifie en les goûtant.
- **Loot boxes** Bronze / Argent / Or / Légendaire : gagnées par les succès, les montées de niveau,
  les coffres et les mimiques. Raretés Commun → Légendaire.
- **Succès** (16) : absurdes, ils rapportent tous une loot box.
- **Mimiques** (dès l'étage 2) : des coffres avec des dents, indiscernables des vrais.
- **Le show** : la hype monte avec les combats, combos, risques et exploits, et retombe quand on
  traîne. L'audience suit la hype. Trop d'ennui et la régie lâche des monstres (rebondissement).
- **Sponsors** (3 par run parmi 8) : chacun a ses goûts (sang, potions, agonie, exploration, or,
  vitesse, shopping, exploits). Satisfaits, ils parachutent des loot boxes.
- **Fin d'épisode** : chaque étage a un compte à rebours ; à zéro, il est démoli (dégâts croissants).
- **Interview** à chaque sortie d'étage : 2 à 3 questions de MAESTRO, 3 réponses au choix, réaction du
  public et conséquences (hype, or, soins, sponsors, temps ou monstres en plus à l'étage suivant).
  Certaines questions dépendent de ce qui vient de se passer (poison, mimique, quasi-mort, carnage…).
- **Coulisses** : un talent parmi 3 (15 au total), infirmerie, boutique.

## Profondeur

- **5 zones** de 3 étages, chacune avec son décor, ses monstres et son boss : les Égouts, le Parc
  d'attractions abandonné, le Centre commercial, le Plateau télé, l'Administration infernale.
- **25 monstres** + **5 boss** (étages 3, 6, 9, 12, 15). Un boss garde l'escalier et le verrouille ;
  certains appellent des renforts ou s'enragent. Vaincre le Directeur des Programmes à l'étage 15
  gagne la saison.
- **Altérations** : poison, feu (dégâts par tour), étourdi (tour perdu), gêné (coups à moitié).
  Certaines armes les infligent, des bagues en immunisent, la potion de soin retire poison et feu,
  le pansement sponsorisé retire tout.

## Variété

- **Lieux interactifs** (marqués d'un « ? ») : fontaine douteuse, autel de sponsor, distributeur
  automatique, bouche de la vérité. Les frapper ouvre un choix aux conséquences aléatoires.
- **Pièges cachés** : pics, canon à confettis, projecteur brûlant, trappe (chute à l'étage suivant,
  sans interview). On les repère parfois en passant à côté ; le déplacement auto évite ceux repérés.
- **Modificateurs d'étage** (environ 1 étage sur 3) : panne de courant, happy hour, pluie de pièces,
  double XP, monstre vedette doré (loot box Or), épisode écourté.
- **MAESTRO bavard** : commentaires spontanés, fausses coupures pub des sponsors, blagues après les
  éliminations, 24 questions d'interview.

## Sons et musique

Bruitages et deux boucles chiptune (donjon, plateau) synthétisés pour le jeu par
`python tool/make_sounds.py` (aucune dépendance, écrit dans `assets/audio/`). Musique et effets se
coupent séparément dans les réglages ; tout se met en pause quand l'appli passe en arrière-plan.

## Sauvegarde

La partie en cours est sauvegardée dès que l'appli passe en arrière-plan, ou avec « Pause » (bouton
retour). Le menu propose alors « Reprendre ». La sauvegarde stocke la graine et la liste des actions,
et les rejoue à l'identique. Si le moteur change (`Game.saveVersion`), les anciennes sauvegardes sont
refusées proprement.

## Méta-progression (sauvegardée sur l'appareil)

- **Droits d'auteur** gagnés à chaque fin de run (étages, audience record, monstres, succès, bonus
  pour les succès obtenus pour la première fois, +50 % au défi du jour). Abandonner compte aussi.
- **Loge des stars** : signer de nouveaux **rôles** (7 : Candidat lambda, Concierge, Influenceuse,
  Prof de gym, Comptable, Chef de cantine, Cascadeur), acheter des **contrats** permanents
  (PV, potions, hype, or, temps d'antenne, loot box de bienvenue), revoir les **rediffusions**
  (15 dernières runs, records).
- **Défi du jour** : même donjon pour tout le monde ce jour-là, rôle de base et aucun contrat.
- **Tableau d'honneur** : les succès restent acquis d'une run à l'autre.

## Réglages

Roue crantée du menu : vibrations, croix directionnelle à l'écran, effacement de la progression.

## Développement

Le SDK Flutter de `C:\Program Files\flutter` n'est pas accessible en écriture : utiliser la copie
`C:\Users\Nicolas\flutter`.

```powershell
$env:PATH = "C:\Users\Nicolas\flutter\bin;$env:PATH"
flutter test
flutter run -d emulator-5554
```

Avast intercepte le HTTPS : Gradle échoue alors avec `PKIX path building failed`. Un magasin de
certificats Java contenant le certificat Avast a été créé dans `~\.gradle\truststore-avast.jks`
(copie du `cacerts` d'Android Studio + `C:\ProgramData\Avast Software\Avast\wscert.pem`). Avant un build :

```powershell
$env:JAVA_TOOL_OPTIONS = "-Djavax.net.ssl.trustStore=$env:USERPROFILE\.gradle\truststore-avast.jks -Djavax.net.ssl.trustStorePassword=changeit"
```

Équilibrage : `dart run tool/balance.dart 300 [role]` fait jouer 300 runs à un bot et affiche la
répartition des étages atteints, les causes de mort et le temps passé en hype VIRAL.
Icônes : `powershell -File tool\make_icons.ps1` régénère les icônes Android depuis le sprite de MAESTRO.

APK à installer sur un téléphone : `flutter build apk --release --split-per-abi`, puis
`buildpp\outputslutter-apkpp-arm64-v8a-release.apk` (signé avec la clé de debug : suffisant
pour l'installer soi-même, pas pour le Play Store).

## Structure

- `lib/core/` : moteur pur Dart, déterministe par graine (génération, FOV, chemins, combat, tours).
- `lib/content/` : données (monstres, répliques de MAESTRO, index des sprites).
- `lib/ui/` : contrôleur d'animation, rendu pixel art (`render/`), écrans.
- `test/core_test.dart` : tests du moteur.

## Crédits

- Sprites : [Tiny Dungeon](https://kenney.nl/assets/tiny-dungeon) par Kenney (CC0).
- Police : Press Start 2P par CodeMan38 (SIL OFL).
- Sons et musiques : synthétisés pour ce projet (`tool/make_sounds.py`).
