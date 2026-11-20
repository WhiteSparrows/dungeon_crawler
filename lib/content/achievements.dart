import 'items.dart';

/// Succès débloquables pendant une run. Chacun rapporte une loot box.
class AchievementDef {
  const AchievementDef(this.id, this.name, this.desc, this.reward, this.flavor, {this.secret = false});
  final String id;
  final String name;

  /// Condition, en clair.
  final String desc;
  final BoxTier reward;

  /// Le commentaire (déplacé) de MAESTRO, affiché une fois le succès obtenu.
  final String flavor;

  /// Succès secret : la condition reste cachée tant qu'il n'est pas obtenu.
  final bool secret;
}

const achievementDefs = <AchievementDef>[
  AchievementDef('first_blood', 'Premier sang', 'Éliminer un premier monstre.', BoxTier.bronze,
      "Félicitations ! Vous avez ôté une vie. Notre service comptabilité vous ouvre officiellement un "
          "dossier « Prédateur ». Le monstre, lui, avait un crédit immobilier sur vingt ans."),
  AchievementDef('rat_catcher', 'Dératiseur agréé', "Éliminer 5 rats d'égout.", BoxTier.bronze,
      "Cinq rats syndiqués de moins. Le syndicat a déposé un préavis de grève, une plainte, et un "
          "petit bouquet de fleurs sur votre oreiller. Dormez bien."),
  AchievementDef('food_critic', 'Critique gastronomique', 'Éliminer 3 gelées de cantine.', BoxTier.bronze,
      "Trois gelées de cantine terrassées. Le chef les avait servies le mardi depuis 1987. Vous venez "
          "de détruire un patrimoine culinaire. Et franchement, merci."),
  AchievementDef('thirsty', 'Sobriété ? Connais pas', 'Boire 4 potions dans la même run.', BoxTier.bronze,
      "Quatre flacons trouvés PAR TERRE, dans un DONJON, avalés sans hésiter. Votre foie a envoyé une "
          "lettre de démission. Nous l'avons transmise à vos ayants droit, par anticipation."),
  AchievementDef('poisoned', 'Ça avait un goût bizarre', 'Boire du poison sans le savoir.', BoxTier.bronze,
      "Le poison avait un arrière-goût de noisette, de regret et de mauvaise décision. Le public a "
          "voté : c'est le meilleur moment de la semaine. Vous pouvez le revoir en boucle sur notre chaîne.",
      secret: true),
  AchievementDef('pacifist', 'Pacifiste (temporaire)', 'Descendre un étage sans rien tuer.', BoxTier.bronze,
      "Un étage entier sans une goutte de sang. Les monstres ont trouvé ça vexant. Les sponsors ont "
          "trouvé ça suspect. Moi, j'ai trouvé ça long."),
  AchievementDef('taster', 'Goûteur officiel', 'Identifier 3 fioles mystère.', BoxTier.argent,
      "Trois fioles mystère identifiées par la méthode scientifique la plus ancienne : boire et voir. "
          "Marie Curie serait fière. Enfin, Marie Curie serait surtout inquiète."),
  AchievementDef('genius', 'Coup de génie', 'Placer 5 coups critiques.', BoxTier.argent,
      "Cinq coups critiques ! Nos analystes ont étudié votre technique : c'est de la chance. Pure, "
          "brute, honteuse. Le public adore la chance. Ça lui donne de l'espoir."),
  AchievementDef('miracle', 'Miraculé', 'Survivre avec 3 PV ou moins.', BoxTier.argent,
      "Trois points de vie. TROIS. Nous avions déjà imprimé l'avis de décès, réservé la fanfare et "
          "loué votre appartement. Vous nous devez une fanfare."),
  AchievementDef('express', 'Descente express', 'Descendre moins de 40 tours après être arrivé.', BoxTier.argent,
      "Arrivé, repéré l'escalier, parti. Vous avez traversé l'étage comme un livreur de pizza un "
          "vendredi soir. Les monstres n'ont même pas eu le temps de se maquiller."),
  AchievementDef('tax_exile', 'Évadé fiscal', 'Posséder 150 pièces.', BoxTier.argent,
      "Cent cinquante pièces dans les poches, dans un donjon où rien ne s'achète, sauf en coulisses, "
          "à des prix que je fixe moi-même. Je vous aime bien, vous. Vous êtes un client."),
  AchievementDef('butter', 'Tartinade', 'Éliminer 5 monstres au couteau à beurre.', BoxTier.argent,
      "Cinq victimes au couteau à beurre. Les fabricants de couverts ont appelé, ils veulent vous "
          "signer comme égérie. Le beurre, lui, refuse de commenter.",
      secret: true),
  AchievementDef('tourist', 'Touriste consciencieux', 'Explorer entièrement un étage.', BoxTier.argent,
      "Vous avez visité chaque recoin. CHAQUE recoin. Même celui où le stagiaire caméraman pleurait. "
          "Il vous dit merci pour la compagnie, et adieu."),
  AchievementDef('carnage', 'Carnage télévisuel', 'Éliminer 3 monstres en 6 tours.', BoxTier.or,
      "Trois éliminations en six tours ! La régie a dû rajouter des cadavres au générique de fin. Le "
          "comité d'éthique s'est réuni en urgence, puis s'est dissous faute de motivation."),
  AchievementDef('mimic', 'Ce coffre avait des dents', 'Éliminer une mimique.', BoxTier.or,
      "Vous avez tué un meuble. Un meuble qui voulait vous manger, certes. Mais un meuble. Ikea "
          "galactique a émis une alerte de sécurité concernant votre personne.",
      secret: true),
  AchievementDef('deep', 'Spéléologue amateur', "Atteindre l'étage 5.", BoxTier.or,
      "Étage 5 ! Vous êtes officiellement plus profond que 94 % des candidats et que 100 % des "
          "émissions culturelles. Les parieurs qui avaient misé sur vous sont riches. Ils ne vous remercieront pas."),
  AchievementDef('just_in_time', 'Juste à temps', 'Descendre à 10 tours ou moins de la démolition.',
      BoxTier.argent,
      "Vous avez quitté l'étage au moment où le bulldozer passait la première. Le conducteur est déçu. "
          "Il vous avait gardé une place sous les gravats."),
  AchievementDef('sponsored', 'Homme-sandwich', 'Recevoir un premier colis de sponsor.', BoxTier.argent,
      "Un sponsor vous a envoyé un colis. Vous êtes désormais un panneau publicitaire ambulant. "
          "Petit conseil : ne mourez pas en tenant la marque à l'envers, c'est dans le contrat."),
  AchievementDef('viral', 'Viral', 'Atteindre le niveau de hype VIRAL.', BoxTier.or,
      "VOUS ÊTES VIRAL ! Votre tête tourne sur six milliards d'écrans, dans quarante dimensions. "
          "Quelque part, une méduse cosmique a fait de vous son fond d'écran. Ne la décevez pas."),
  AchievementDef('talk_show', 'Bête de plateau', 'Faire applaudir le public 3 fois en interview.',
      BoxTier.argent,
      "Trois salves d'applaudissements sur MON plateau. Attention, candidat : il n'y a de place que pour "
          "une seule star ici. Et ce n'est pas celle qui saigne sur ma moquette."),
  AchievementDef('boss_slayer', 'Tueur de têtes d\'affiche', 'Vaincre un boss de zone.', BoxTier.or,
      "Vous avez éliminé une tête d'affiche. Son agent a appelé : il vous représente, désormais. "
          "Vingt pour cent de tout ce que vous tuerez. C'est le métier."),
  AchievementDef('sick', 'Malade imaginaire', 'Subir 3 altérations en même temps.', BoxTier.bronze,
      "Empoisonné, en feu, étourdi et gêné, ou presque. Vous êtes un catalogue de pharmacie ambulant. "
          "Notre médecin de plateau refuse de vous approcher, il dit que c'est contagieux. C'est faux. Probablement.",
      secret: true),
  AchievementDef('season_win', 'Fin de saison', 'Vaincre le Directeur des Programmes.', BoxTier.legendaire,
      "Vous avez vaincu le Directeur. Félicitations : vous êtes renouvelé pour une saison 2. Ce n'était pas "
          "une récompense. C'était une menace. On se revoit à la rentrée.",
      secret: true),
  AchievementDef('showstopper', "Numéro d'acteur", 'Utiliser 10 fois votre compétence dans une run.',
      BoxTier.argent,
      "Dix fois le même numéro, et le public en redemande. Vous êtes officiellement un personnage récurrent. "
          "Les scénaristes vous détestent, ils vont devoir vous écrire des répliques."),
  AchievementDef('defused', 'Démineur amateur', "Échapper à l'explosion d'un kamikaze.", BoxTier.bronze,
      "Il a gonflé, il a explosé, et vous étiez déjà ailleurs. Le kamikaze est mort pour rien. "
          "Comme tous les kamikazes, me direz-vous. Mais lui, en plus, c'était un rat.",
      secret: true),
  AchievementDef('specialist', 'Spécialiste autoproclamé', 'Monter une compétence au niveau 6.', BoxTier.argent,
      "Niveau 6 dans une compétence ! Vous êtes officiellement un expert. Notre service juridique précise que "
          "« expert » n'engage à rien et ne protège pas des monstres."),
  AchievementDef('jack_of_all', 'Couteau suisse', 'Toutes les compétences au niveau 2.', BoxTier.argent,
      "Un peu de tout, beaucoup de rien ! Le public adore les profils polyvalents. Les monstres aussi : "
          "il y a plus de saveurs."),
  AchievementDef('crafter', 'Bricoleur du dimanche', "Fabriquer 5 choses à l'atelier.", BoxTier.bronze,
      "Cinq créations faites main ! Notre émission de déco a appelé, elle veut vous voir. Vous n'irez pas, "
          "vous serez mort, mais c'est gentil de leur part."),
  AchievementDef('recycler', 'Recyclage militant', 'Démonter 10 objets.', BoxTier.bronze,
      "Dix objets réduits en pièces détachées. Les écologistes applaudissent. Les objets, eux, ne disent rien. "
          "Ils ne peuvent plus."),
  AchievementDef('corruption', 'Corruption passive', 'Soudoyer un monstre.', BoxTier.bronze,
      "Vous avez payé un monstre pour qu'il s'en aille. Il a accepté. Le donjon est donc un lieu de travail "
          "comme un autre. Les syndicats de monstres saluent une « négociation constructive ».",
      secret: true),
];

AchievementDef achievementById(String id) => achievementDefs.firstWhere((a) => a.id == id);
