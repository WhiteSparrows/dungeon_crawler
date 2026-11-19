import 'items.dart';

/// Réaction du public en plateau après une réponse.
enum Crowd {
  applause('APPLAUDISSEMENTS'),
  laughs('RIRES ENREGISTRÉS'),
  boos('HUÉES'),
  gasps('OOOOH !'),
  silence('SILENCE GÊNÉ');

  const Crowd(this.label);
  final String label;
}

/// Réponse possible en interview, avec ses conséquences.
/// `{s0}`, `{s1}`, `{s2}` sont remplacés par les noms des sponsors de la run.
class Answer {
  const Answer(
    this.text,
    this.reaction,
    this.crowd, {
    this.hype = 0,
    this.gold = 0,
    this.healPct = 0,
    this.sponsor,
    this.sponsorDelta = 0,
    this.timerDelta = 0,
    this.extraMonsters = 0,
    this.box,
    this.viewersPct = 0,
  });

  final String text;

  /// Réplique de MAESTRO après la réponse.
  final String reaction;
  final Crowd crowd;
  final double hype;
  final int gold;
  final double healPct;

  /// Sponsor concerné (0..2), ou -1 pour tous.
  final int? sponsor;
  final double sponsorDelta;

  /// Tours ajoutés (ou retirés) au compte à rebours du prochain étage.
  final int timerDelta;
  final int extraMonsters;
  final BoxTier? box;
  final double viewersPct;

  /// Résumé lisible des conséquences.
  List<String> get effects => [
        if (hype > 0) 'Hype +${hype.round()}',
        if (hype < 0) 'Hype ${hype.round()}',
        if (viewersPct > 0) 'Audience +${(viewersPct * 100).round()} %',
        if (gold > 0) '+$gold or',
        if (healPct > 0) 'Soin ${(healPct * 100).round()} %',
        if (sponsorDelta > 0) 'Sponsor ravi',
        if (sponsorDelta < 0) 'Sponsors vexés',
        if (timerDelta > 0) '+$timerDelta tours au prochain étage',
        if (timerDelta < 0) '$timerDelta tours au prochain étage',
        if (extraMonsters > 0) '+$extraMonsters monstre${extraMonsters > 1 ? 's' : ''} au prochain étage',
        if (box != null) 'Loot box ${box!.label}',
      ];
}

/// Contexte de la run, pour poser des questions en rapport avec ce qui vient de se passer.
enum When { always, poisoned, lowHp, killer, pacifist, rich, broke, mimic, deep, wounded, fell, prayed }

class Question {
  const Question(this.text, this.answers, {this.when = When.always});
  final String text;
  final List<Answer> answers;
  final When when;
}

const questions = <Question>[
  // ---------------------------------------------------------------- génériques
  Question("Alors, qu'est-ce que ça fait de massacrer des créatures en direct ?", [
    Answer("J'adore ça. Vraiment.", 'Magnifique. Les spectateurs frissonnent.', Crowd.applause,
        hype: 25, viewersPct: 0.1),
    Answer('Je pense à ma mère.', "Oh. Le public est ému. Quelqu'un vous lance un cadeau.", Crowd.gasps,
        hype: 5, box: BoxTier.bronze),
    Answer('Pas de commentaire.', 'Notre service juridique apprécie votre discrétion. Voici une enveloppe.',
        Crowd.silence, hype: -10, gold: 40),
  ]),
  Question('Un petit mot pour nos généreux sponsors ?', [
    Answer('Buvez, achetez, consommez : {s0} !', '{s0} a adoré. Ils vous ont à l\'œil.', Crowd.applause,
        sponsor: 0, sponsorDelta: 50),
    Answer('Merci {s1}, sans vous je serais déjà mort.', 'Émouvant. Et rentable.', Crowd.applause,
        sponsor: 1, sponsorDelta: 50),
    Answer('Ils peuvent tous aller se faire voir.', "OH ! Coupez ! ... Non, ne coupez pas, l'audience explose.",
        Crowd.gasps, hype: 30, sponsor: -1, sponsorDelta: -30),
  ]),
  Question("Nos parieurs vous donnent mort à l'étage suivant. Un commentaire ?", [
    Answer('Pariez contre moi.', "J'ai misé sur vous. Si vous mourez, je garde l'argent. Voici une avance.",
        Crowd.laughs, gold: 60, timerDelta: -30),
    Answer('Je vais tout casser.', 'Promesse enregistrée. La régie ajoute quelques invités.', Crowd.applause,
        hype: 20, extraMonsters: 2),
    Answer("J'ai peur.", 'Ça se voit. Allez, un petit soin pour la route. Pathétique.', Crowd.boos,
        healPct: 0.35, hype: -15),
  ]),
  Question('Quelle est votre plus grande peur, candidat ?', [
    Answer('Les coffres qui mordent.', 'Ha ! Tenez, un coffre. Promis, celui-là ne mord pas.', Crowd.laughs,
        box: BoxTier.bronze),
    Answer('La coupure pub.', 'Nous aussi. Nous aussi.', Crowd.laughs, hype: 15),
    Answer('Vous.', '... Je note. Le prochain étage sera un peu plus court. Rien de personnel.', Crowd.gasps,
        hype: 35, timerDelta: -25),
  ]),
  Question('Vous avez un talent caché ? Le public adore les talents cachés.', [
    Answer('Je chante.', "Ne chantez pas. Par pitié. Tenez, de l'argent pour ne pas chanter.", Crowd.laughs,
        gold: 35),
    Answer('Je cours très vite.', "Prouvez-le : vous aurez un peu plus de temps à l'étage suivant.",
        Crowd.applause, timerDelta: 30),
    Answer('Je fais des grimaces.', 'Le public est... perplexe. Mais il regarde.', Crowd.silence,
        hype: 12, viewersPct: 0.05),
  ]),
  Question('Si vous sortez vivant, que ferez-vous de vos gains ?', [
    Answer('Je rachète la Terre.', 'Ambitieux ! {s2} vous trouve inspirant.', Crowd.applause,
        sponsor: 2, sponsorDelta: 40, hype: 10),
    Answer('Je soigne mes blessures.', 'Raisonnable. Ennuyeux, mais raisonnable.', Crowd.silence,
        healPct: 0.5, hype: -10),
    Answer('Je reviens. Saison 2.', 'Un candidat qui comprend le business ! Une loot box pour vous.',
        Crowd.applause, box: BoxTier.argent, hype: 5),
  ]),
  Question('Le public veut savoir : vous avez un surnom ?', [
    Answer('Le Fléau des Égouts.', "Le Fléau des Égouts ! Ça claque. On l'imprime sur des tasses.",
        Crowd.applause, hype: 20),
    Answer('Mes amis m\'appellent « Chouchou ».', 'Chouchou. CHOUCHOU. Le public est hilare.', Crowd.laughs,
        hype: 15, viewersPct: 0.08),
    Answer('Je préfère rester anonyme.', 'Dans une émission de télé-réalité. Évidemment.', Crowd.boos,
        hype: -8, sponsor: -1, sponsorDelta: 10),
  ]),
  Question("Un candidat d'une autre saison dit que vous êtes surcoté. Votre réponse ?", [
    Answer('Il est mort, non ?', 'Il est mort, oui. Glacial. On adore.', Crowd.gasps, hype: 25),
    Answer('Il a raison.', "Une humilité rafraîchissante. Et un peu triste. Tenez, un remontant.",
        Crowd.silence, healPct: 0.25, hype: -5),
    Answer('Envoyez-le-moi à l\'étage suivant.', 'Pas lui, mais j\'ai des remplaçants motivés.', Crowd.applause,
        hype: 15, extraMonsters: 1, box: BoxTier.bronze),
  ]),

  Question('Votre plat préféré, pour la petite fiche ?', [
    Answer('La gelée de cantine.', "Cannibalisme culinaire ! La gelée de l'étage 1 a porté plainte.", Crowd.laughs,
        hype: 12),
    Answer('Le steak de {s1}.', '{s1} vous offre un an de steaks. Enfin, un steak. Pour un an.', Crowd.applause,
        sponsor: 1, sponsorDelta: 35),
    Answer('Je ne mange plus depuis que je vois ce que vous servez.', 'Le traiteur est vexé. Il était dans la salle.',
        Crowd.gasps, hype: 18),
  ]),
  Question("Le public a voté : il veut vous voir combattre avec une main dans le dos. Vous acceptez ?", [
    Answer('Avec plaisir.', "Formidable ! On vous l'attache... ah non, on n'a pas de corde. Prenez cette loot box.",
        Crowd.applause, box: BoxTier.bronze, hype: 10),
    Answer('Le public peut venir le faire lui-même.', 'Le public prend des notes. Quelques monstres aussi.',
        Crowd.gasps, hype: 20, extraMonsters: 1),
    Answer('Non.', "Le public est déçu. Le public est toujours déçu. C'est son métier.", Crowd.boos, hype: -10,
        gold: 20),
  ]),
  Question('Une rumeur dit que vous parlez aux monstres avant de les tuer. Vrai ?', [
    Answer('Je leur lis des poèmes.', 'Le service culture de la chaîne veut vous engager.', Crowd.laughs,
        hype: 15, viewersPct: 0.05),
    Answer("Je m'excuse, c'est tout.", "Poli. Inutile, mais poli. La politesse ne rapporte rien ici.", Crowd.silence,
        healPct: 0.2),
    Answer('Je leur parle de {s0}.', "Placement de produit en plein combat. {s0} pleure de joie.", Crowd.applause,
        sponsor: 0, sponsorDelta: 45),
  ]),
  Question('On a retrouvé votre journal intime dans votre sac. Je lis un extrait ?', [
    Answer('Allez-y.', "« Cher journal, aujourd'hui un rat m'a mordu et j'ai pleuré. » Magnifique. Diffusé.",
        Crowd.laughs, hype: 25, viewersPct: 0.1),
    Answer('Je vous paie pour ne pas le faire.', 'Accepté. Je le lirai quand même la semaine prochaine.', Crowd.boos,
        gold: -30, hype: -5),
    Answer("Ce n'est pas mon journal.", "Il y a votre nom dessus. Et votre sang. Le public adore le mensonge.",
        Crowd.gasps, hype: 15),
  ]),
  Question('Dernière question, rapide : chat ou chien ?', [
    Answer('Chat.', 'Le public est divisé. Une émeute éclate dans les gradins. Merci.', Crowd.gasps, hype: 20),
    Answer('Chien.', 'Le public est divisé. Une émeute éclate dans les gradins. Merci aussi.', Crowd.gasps, hype: 20),
    Answer('Gelée de cantine.', "Réponse inattendue. Le comité de sélection vous offre un petit quelque chose.",
        Crowd.laughs, box: BoxTier.bronze),
  ]),

  // ---------------------------------------------------------------- en contexte
  Question("Vous êtes tombé dans une trappe et avez sauté notre interview précédente. C'était volontaire ?",
      when: When.fell, [
    Answer('Totalement.', "Esquiver MAESTRO ? Personne n'esquive MAESTRO. Prochain étage plus court.", Crowd.gasps,
        hype: 20, timerDelta: -20),
    Answer('Non, je suis maladroit.', "Maladroit et vivant. La meilleure combinaison pour l'audimat.", Crowd.laughs,
        hype: 15),
    Answer("Vous m'avez manqué.", "Oh. Je... Coupez. COUPEZ. Donnez-lui une loot box, vite.", Crowd.applause,
        box: BoxTier.argent),
  ]),
  Question("Nos caméras vous ont vu prier devant un autel de sponsor. Vous êtes croyant ?", when: When.prayed, [
    Answer('Je crois en {s0}.', '{s0} vous croit aussi. Un peu. Contre rémunération.', Crowd.applause,
        sponsor: 0, sponsorDelta: 40),
    Answer('Je crois en moi.', 'Courageux. Statistiquement faux, mais courageux.', Crowd.laughs, hype: 15),
    Answer('Je crois en rien, je voulais la loot box.', "L'honnêteté ! Ça ne se voit jamais ici. Le public est sous le choc.",
        Crowd.gasps, hype: 25),
  ]),

  Question("Vous avez bu du poison tout à l'heure. Vous recommandez ?", when: When.poisoned, [
    Answer('Arôme fruité, finale amère.', "Un vrai sommelier ! {s0} veut vous signer.", Crowd.laughs,
        sponsor: 0, sponsorDelta: 45, hype: 10),
    Answer("Je ne bois plus rien de suspect.", 'Promesse de candidat. On en reparle dans deux étages.',
        Crowd.laughs, hype: 5),
    Answer("Je l'ai fait exprès.", "... Personne n'y croit. Mais on salue l'aplomb.", Crowd.boos, hype: 12),
  ]),
  Question("Vous êtes arrivé ici avec à peine quelques points de vie. Le public a cru à votre mort. Et vous ?",
      when: When.lowHp, [
    Answer('Jamais douté.', 'Mensonge éhonté. Le public adore les menteurs.', Crowd.applause, hype: 20),
    Answer('Je veux ma maman.', 'Touchant. On vous soigne avant que vous ne pleuriez à l\'antenne.',
        Crowd.gasps, healPct: 0.6, hype: -5),
    Answer("C'était une stratégie.", "« Une stratégie ». Notez-le, c'est le titre du prochain épisode.",
        Crowd.laughs, hype: 10, viewersPct: 0.1),
  ]),
  Question('Vous avez laissé une sacrée traînée de cadavres. Un message pour les familles ?', when: When.killer, [
    Answer('Ils ne souffraient pas. Enfin, pas longtemps.', 'Brutal. {s1} est conquis.', Crowd.gasps,
        sponsor: 1, sponsorDelta: 40, hype: 15),
    Answer('Désolé.', "Excuses acceptées par le comité d'éthique, qui n'existe pas.", Crowd.silence, gold: 25),
    Answer('À qui le tour ?', "La régie prend ça comme une demande. Bonne chance.", Crowd.applause,
        hype: 30, extraMonsters: 2),
  ]),
  Question("Vous n'avez tué personne à cet étage. Vous êtes malade ?", when: When.pacifist, [
    Answer('Je suis pacifiste.', 'Un pacifiste dans un donjon. Le concept nous plaît, pour l\'instant.',
        Crowd.laughs, hype: 10, box: BoxTier.bronze),
    Answer("J'économise mes forces.", 'Économisez aussi notre audience, elle baisse.', Crowd.boos, hype: -10,
        timerDelta: 20),
    Answer('Le prochain étage va saigner.', 'On prend note. On prépare le nettoyage.', Crowd.applause,
        hype: 20, extraMonsters: 1),
  ]),
  Question('Vous êtes plutôt riche pour un candidat. Une idée de placement ?', when: When.rich, [
    Answer('{s2}, bien sûr.', "{s2} vous remercie et vous envoie un petit quelque chose.", Crowd.applause,
        sponsor: 2, sponsorDelta: 50),
    Answer('Je garde tout sous mon matelas.', "Vous n'avez pas de matelas. Vous dormez dans un donjon.",
        Crowd.laughs, hype: 10),
    Answer('Je donne tout au public !', 'NON. Personne ne fait ça. ... Bon, le public vous adore.',
        Crowd.gasps, gold: -60, hype: 40, viewersPct: 0.15),
  ]),
  Question('Vous êtes fauché. Comment comptez-vous survivre ?', when: When.broke, [
    Answer('Grâce à votre générosité ?', 'Bien tenté. Tenez, une pièce. Une seule.', Crowd.laughs, gold: 15),
    Answer('À la force de mes bras.', "Ce sont de petits bras, mais d'accord.", Crowd.silence, hype: 8),
    Answer('En vendant mon âme à {s0}.', '{s0} accepte. Ils accepteraient n\'importe quoi.', Crowd.gasps,
        sponsor: 0, sponsorDelta: 60, hype: 5),
  ]),
  Question('Un coffre vous a mordu. Les images tournent en boucle. Votre réaction ?', when: When.mimic, [
    Answer("J'ai mordu en retour.", "On a les images. C'est dégoûtant. On adore.", Crowd.laughs, hype: 25),
    Answer('Je ne fais plus confiance aux meubles.', 'Sage décision. Paranoïa offerte par la production.',
        Crowd.laughs, box: BoxTier.bronze),
    Answer('Il me faut une revanche.', 'La régie a justement des coffres en stock...', Crowd.applause,
        hype: 15, extraMonsters: 1),
  ]),
  Question('Vous voilà très profond dans le donjon. Le public commence à vous aimer. Ça vous fait quoi ?',
      when: When.deep, [
    Answer('Je les aime aussi.', 'Mignon. Écœurant, mais mignon.', Crowd.applause, hype: 20, viewersPct: 0.1),
    Answer('Je ne fais pas ça pour eux.', 'Le public adore être méprisé. Allez comprendre.', Crowd.gasps,
        hype: 25),
    Answer("Qu'ils m'envoient des cadeaux.", "Le public a entendu. Les sponsors aussi.", Crowd.laughs,
        sponsor: -1, sponsorDelta: 30),
  ]),
  Question('Vous saignez sur mon plateau. Vous voulez un pansement ?', when: When.wounded, [
    Answer('Oui, merci.', 'Pansement sponsorisé par {s1}. Ça pique un peu.', Crowd.silence,
        healPct: 0.3, sponsor: 1, sponsorDelta: 15),
    Answer("Non, c'est mon sang de scène.", 'Quel professionnalisme. Les caméras adorent.', Crowd.applause,
        hype: 20),
    Answer('Je veux un médecin. Un vrai.', 'Ha ! Ha ! Ha ! ... Ah, vous étiez sérieux.', Crowd.laughs,
        hype: 10, healPct: 0.15),
  ]),
];
