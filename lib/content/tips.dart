/// Conseils de MAESTRO, affichés une seule fois, au moment où la mécanique apparaît.
/// Le ton est moqueur, mais chaque conseil dit clairement quoi faire.
class TipDef {
  const TipDef(this.id, this.title, this.text);
  final String id;
  final String title;
  final String text;
}

const tipDefs = <TipDef>[
  TipDef('welcome', 'Bienvenue sur le plateau',
      "Je suis MAESTRO, votre animateur. Vous, vous êtes le contenu. Le principe : descendre le plus bas "
          "possible dans le donjon, survivre, et surtout divertir. Ces petites fiches vous expliqueront tout, "
          "une seule fois. Je ne me répète pas, je suis payé à la réplique."),
  TipDef('move', 'Se déplacer',
      "Touchez une case pour y aller (le trajet s'arrête si un monstre apparaît). Glissez le doigt pour faire "
          "un seul pas. Touchez un monstre collé à vous pour le frapper. Touchez-vous vous-même pour attendre "
          "un tour. Une croix directionnelle existe dans les réglages, pour les nostalgiques."),
  TipDef('hud', 'Lire le bandeau',
      "En haut : vos PV, votre niveau, votre or. Juste dessous : le nombre de spectateurs, la HYPE, le compte à "
          "rebours de l'étage et les jauges de vos trois sponsors. Touchez ce bandeau pour ouvrir la régie et "
          "voir ce que chaque sponsor aime."),
  TipDef('monster', 'Un monstre !',
      "Les monstres jouent quand vous jouez : un pas pour vous, un pas pour eux. Frappez-les au contact. Les "
          "petits carrés de couleur au-dessus d'eux sont des altérations (poison, feu, étourdi, gêné). Ceux qui "
          "tirent de loin, explosent ou soignent sont à traiter en priorité."),
  TipDef('combat', 'Choisir ses coups',
      "Toucher un monstre au contact donne un coup RAPIDE (gratuit). La barre de combat propose mieux : "
          "LOURD (2 d'endurance, gros dégâts, peut étourdir), POUSSER (1, l'envoie valser deux cases plus loin, "
          "déséquilibré, et encore plus mal s'il percute un mur), PARER (2, bloque le prochain coup au contact et "
          "riposte). Choisissez le coup, puis touchez le monstre. L'endurance remonte toute seule, plus vite en attendant."),
  TipDef('intent', 'Lire les intentions',
      "La petite étiquette au-dessus d'un monstre dit ce qu'il fera si vous ne bougez pas : « ! » il frappe, "
          "« ... » orange il prépare un coup LOURD, « !! » rouge il l'abat (écartez-vous ou PAREZ), « > » il tire, "
          "« ... » gris il recharge (foncez !), « ** » il va exploser, « + » il soigne, « z » il est sonné."),
  TipDef('ranged', 'Tirer de loin',
      "Un tireur ! Touchez TIRER, puis touchez la cible encadrée de jaune. Votre lance-pierre utilise des cailloux "
          "(il y en a dans chaque étage) ; les baguettes magiques coûtent 2 d'endurance. Après chaque tir, les tireurs "
          "ennemis rechargent un tour : c'est le moment de foncer sur eux."),
  TipDef('skill', 'Votre POUVOIR',
      "Le bouton POUVOIR déclenche la compétence de votre rôle. Elle se recharge en quelques tours. "
          "Appui long sur le bouton pour lire ce qu'elle fait. N'hésitez pas, le public adore les numéros."),
  TipDef('potion', 'Vous saignez',
      "Le bouton SOIN boit une potion de soin. Elle retire aussi le poison et le feu. Les fioles mystère, "
          "elles, peuvent faire n'importe quoi : on ne sait ce qu'elles font qu'en les goûtant. Le public adore "
          "quand vous goûtez."),
  TipDef('bag', 'Un objet à équiper',
      "Ouvrez le SAC : touchez un objet pour voir ses effets et le comparer à ce que vous portez, puis "
          "ÉQUIPER. Une arme et un accessoire à la fois. Équiper, boire ou jeter prend un tour."),
  TipDef('mastery', 'Vos compétences progressent',
      "Chaque geste vous entraîne : frapper fait monter la Bagarre (deux fois plus vite à mains nues), tirer le "
          "Tir, les sorts la Magie, parer et pousser la Garde, l'atelier le Bricolage, le pouvoir le Charisme. "
          "Chaque niveau donne un bonus, certains débloquent un palier. Tout est dans le SAC, onglet STATS."),
  TipDef('craft', "L'atelier",
      "Vous avez récupéré des composants (ferraille, os, gelée…). Ils vont dans votre bourse, sans prendre de "
          "place. Dans le SAC : touchez un objet inutile puis DÉMONTER pour en tirer des composants, et ouvrez "
          "l'onglet ATELIER pour fabriquer munitions, bombes, potions, ou affûter votre arme."),
  TipDef('lootbox', 'Une loot box',
      "Le coffre doré qui clignote en bas à droite, ce sont vos loot boxes. Touchez-le pour les ouvrir, "
          "c'est gratuit et ça ne prend pas de tour. Vous en gagnez avec les succès, les montées de niveau, "
          "les coffres et les sponsors."),
  TipDef('chest', 'Un coffre',
      "Frappez un coffre pour l'ouvrir : il donne une loot box. Attention, à partir de l'étage 2, certains "
          "coffres sont des MIMIQUES. Ils ont des dents. Personne ne vous avait prévenu. Sauf moi, là."),
  TipDef('feature', 'Un lieu interactif',
      "Le « ? » doré signale un lieu interactif : fontaine, autel de sponsor, distributeur… Marchez dessus "
          "pour faire un choix. Les conséquences sont souvent bonnes. Souvent."),
  TipDef('stairs', "L'escalier",
      "Voilà la sortie de l'étage. Marchez dessus puis touchez DESCENDRE (ou touchez-vous). Vous passerez "
          "par mon plateau pour une interview avant l'étage suivant. Tous les 3 étages, un boss garde l'escalier."),
  TipDef('timer', 'Fin d\'épisode',
      "Le chronomètre en haut compte les tours avant la DÉMOLITION de l'étage. À zéro, le plafond vous tombe "
          "dessus, de plus en plus fort. Fouiller rapporte, traîner tue. Choisissez."),
  TipDef('hype', 'La HYPE',
      "La hype monte quand vous faites le spectacle : éliminations en série, risques, succès. Elle retombe "
          "quand vous traînez. Elle fait grimper l'audience et plaît aux sponsors. Si le public s'ennuie trop, "
          "la régie lâche des monstres pour pimenter. Je dis ça pour vous."),
  TipDef('sponsor', 'Un sponsor est content',
      "Chaque sponsor a ses goûts : le sang, les potions, l'agonie, la vitesse, l'or… Remplissez leur jauge "
          "et ils vous parachutent une loot box. La régie (touchez le bandeau) détaille ce que chacun aime."),
  TipDef('status', 'Altération',
      "Vous êtes sous le coup d'une altération. POISON et FEU font des dégâts chaque tour, ÉTOURDI fait perdre "
          "un tour, GÊNÉ divise vos dégâts par deux. Ça passe tout seul. La potion de soin retire poison et feu, "
          "le pansement sponsorisé retire tout."),
  TipDef('trap', 'Un piège',
      "Les pièges sont cachés jusqu'à ce qu'on marche dessus, ou qu'on les repère en passant à côté. Une "
          "fois repérés, ils sont marqués d'une croix et le déplacement automatique les évite. La trappe, elle, "
          "vous fait tomber à l'étage suivant. Sans interview. Je le prends mal."),
  TipDef('mod', "Modificateur d'étage",
      "Cet étage a une règle spéciale, rappelée dans le bandeau sous le compteur : panne de courant, happy "
          "hour, double XP… Adaptez-vous. Ou pas, c'est aussi de la bonne télé."),
  TipDef('boss', 'Un boss',
      "La tête d'affiche de la zone. Tant qu'il est debout, la sortie est verrouillée. Sa barre de vie "
          "s'affiche en haut. Certains appellent des renforts, d'autres s'énervent quand ils sont blessés. "
          "Bonne chance. Non, vraiment."),
  TipDef('interview', "L'interview",
      "Sur mon plateau, je pose des questions et vous choisissez une réponse. Chaque réponse a des "
          "conséquences : hype, or, soins, sponsors, temps ou monstres en plus à l'étage suivant. La réaction "
          "du public vous dira si c'était une bonne idée."),
  TipDef('backstage', 'Les coulisses',
      "Entre deux étages : prenez un TALENT gratuit (un seul, bonus permanent pour la run), soignez-vous à "
          "l'infirmerie et faites vos courses à la boutique. Puis RETOUR EN SCÈNE."),
  TipDef('gameover', 'Fin de diffusion',
      "C'est fini pour cette fois. Mais rien n'est perdu : vous touchez des DROITS D'AUTEUR selon l'étage "
          "atteint, l'audience et vos exploits. Dépensez-les dans la Loge des stars pour débloquer des rôles et "
          "des bonus permanents. Puis recommencez. Encore. Et encore."),
  TipDef('loge', 'La Loge des stars',
      "Depuis le menu, la LOGE DES STARS vous permet de signer de nouveaux rôles (chacun avec son pouvoir) "
          "et d'acheter des contrats permanents. Le DÉFI DU JOUR propose le même donjon à tout le monde, avec "
          "50 % de droits d'auteur en plus."),
];

TipDef tipById(String id) => tipDefs.firstWhere((t) => t.id == id);
