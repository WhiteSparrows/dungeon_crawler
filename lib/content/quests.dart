/// Quêtes données par les personnages non joueurs (PNJ) croisés dans le donjon.
///
/// Un PNJ au plus par étage. Sa quête ne vaut que pour l'étage : en descendant, elle est perdue.
enum QuestKind {
  /// Éliminer N monstres (d'un type précis, ou n'importe lesquels).
  cull,

  /// Abattre un monstre vedette précis, marqué d'une étoile.
  hunt,

  /// Retrouver un objet perdu quelque part sur l'étage.
  fetch,

  /// Donner des composants d'artisanat.
  donate,

  /// Faire du spectacle : parades, coups lourds, éliminations à distance.
  stunt,
}

/// Prouesse demandée par une quête de spectacle.
enum Stunt {
  parry('parades réussies'),
  heavy('coups lourds qui touchent'),
  rangedKill('éliminations à distance');

  const Stunt(this.label);
  final String label;
}

/// Récompense spéciale d'un PNJ (en plus de l'or).
enum QuestReward {
  /// Loot box en argent.
  box('une loot box en argent'),

  /// Sac agrandi de 2 places, pour toute la run.
  bag('2 places de plus dans le sac'),

  /// Soin complet et PV max +4.
  knit('un soin complet et +4 PV max'),

  /// Un objet rare et une montée d'audience.
  fame('un objet rare et de l\'audience'),

  /// Amélioration gratuite de l'arme (ou 3 cristaux).
  forge('une amélioration gratuite de votre arme');

  const QuestReward(this.label);
  final String label;
}

/// Personnage non joueur.
class NpcDef {
  const NpcDef({
    required this.id,
    required this.name,
    required this.sprite,
    required this.tint,
    required this.kind,
    required this.reward,
    required this.intro,
    required this.ask,
    required this.waiting,
    required this.thanks,
  });

  final String id;
  final String name;
  final int sprite;
  final int tint;
  final QuestKind kind;
  final QuestReward reward;

  /// Présentation (premier contact).
  final String intro;

  /// Demande. Variables : {n}, {monster}, {item}, {component}, {stunt}.
  final String ask;

  /// Relance tant que la quête n'est pas finie.
  final String waiting;

  /// Remerciements à la remise de la récompense.
  final String thanks;
}

const npcs = <NpcDef>[
  NpcDef(
    id: 'janitor',
    name: 'Raymond, agent d\'entretien',
    sprite: 84,
    tint: 0xFF9AD0FF,
    kind: QuestKind.cull,
    reward: QuestReward.bag,
    intro: "Un vieil homme en bleu de travail s'appuie sur son balai. Il a l'air d'être là depuis la saison 1. "
        "Peut-être depuis la construction du donjon.",
    ask: "« Trente ans que je nettoie derrière les candidats. Faites un peu le ménage pour une fois : "
        "débarrassez-moi de {n} {monster}. En échange, je vous recouds votre sac. J'ai du fil. »",
    waiting: "« Encore {left} à balayer. Je ne vais nulle part, moi. Mon contrat non plus. »",
    thanks: "« Voilà du travail propre. » Il vous prend votre sac et y coud deux poches en un temps record. "
        "Elles sentent un peu la serpillère.",
  ),
  NpcDef(
    id: 'intern',
    name: 'Gérard, stagiaire de la régie',
    sprite: 84,
    tint: 0xFFFFC080,
    kind: QuestKind.hunt,
    reward: QuestReward.box,
    intro: "Un jeune homme en sueur, casque audio de travers, serre un talkie-walkie éteint. "
        "Son badge indique « STAGIAIRE ». En dessous, quelqu'un a écrit « (non rémunéré) ».",
    ask: "« La production veut une séquence choc, et c'est MOI qui dois la filmer. Il y a un {monster} vedette "
        "sur l'étage, avec une étoile au-dessus de la tête. Abattez-le devant les caméras, s'il vous plaît. "
        "Je vous refile une loot box de la réserve. Personne ne compte. »",
    waiting: "« Il rôde toujours, le {monster} étoilé. Mon chef m'a déjà crié dessus deux fois. »",
    thanks: "« C'EST DANS LA BOÎTE ! » Gérard pleure de joie et vous glisse une loot box sous le manteau. "
        "Il sera peut-être embauché. Non. Mais il y croit.",
  ),
  NpcDef(
    id: 'granny',
    name: 'Mamie Josette, ex-candidate',
    sprite: 84,
    tint: 0xFFE0B0E0,
    kind: QuestKind.fetch,
    reward: QuestReward.knit,
    intro: "Une vieille dame tricote dans un fauteuil à bascule, au milieu d'un donjon. Personne ne sait "
        "comment le fauteuil est arrivé là. Elle non plus.",
    ask: "« Je suis la gagnante de la saison 1, mon petit. Bon, la seule survivante. J'ai égaré {item} "
        "quelque part dans cet étage. Rapportez-moi ça et je vous tricote quelque chose de chaud. »",
    waiting: "« Alors, {item} ? À votre âge, j'avais déjà vaincu trois boss. Avec mes aiguilles. »",
    thanks: "« Ah, merci mon petit ! » Elle vous enfile un pull tricoté main. Il est moche, il gratte, "
        "et il soigne toutes vos blessures. Ne demandez pas comment.",
  ),
  NpcDef(
    id: 'influencer',
    name: 'Kévin, influenceur égaré',
    sprite: 84,
    tint: 0xFF80FFB0,
    kind: QuestKind.stunt,
    reward: QuestReward.fame,
    intro: "Un garçon en doudoune fluo filme tout avec son téléphone, perche à selfie déployée. "
        "Il est entré dans le donjon « pour une vidéo de dix minutes ». Il y a trois semaines.",
    ask: "« Wesh, t'es le candidat de l'émission ?! Fais-moi du contenu ! Il me faut {n} {stunt}, "
        "en direct, devant ma caméra. Je te partage avec mes abonnés et je te file un truc rare. »",
    waiting: "« Encore {left} {stunt}, frère. L'algorithme n'attend pas. Mes abonnés non plus. Mes parents, si. »",
    thanks: "« TROP BIEN ! » Kévin poste la vidéo. Elle fait le buzz. Il vous donne un objet rare "
        "« reçu d'un partenariat » et vous oublie aussitôt.",
  ),
  NpcDef(
    id: 'tinkerer',
    name: 'Odile, bricoleuse clandestine',
    sprite: 84,
    tint: 0xFFC0C0C0,
    kind: QuestKind.donate,
    reward: QuestReward.forge,
    intro: "Une femme en salopette, lunettes de soudure sur le front, a monté un atelier pirate dans un "
        "recoin. Il y a des étincelles partout et un panneau « INTERDIT AUX CAMÉRAS ».",
    ask: "« Psst. Il me manque {n} {component} pour finir mon bidule. Ne demandez pas quel bidule. "
        "Apportez-les-moi et j'affûte votre arme gratuitement. Démontez vos vieilleries si besoin. »",
    waiting: "« Il me faut toujours {n} {component}. Mon bidule s'impatiente. Il fait des bruits. »",
    thanks: "« Parfait. » Odile s'empare de votre arme, la passe à la meuleuse dans une gerbe d'étincelles "
        "et vous la rend, rutilante. Le bidule, derrière elle, émet un bip satisfait.",
  ),
];

NpcDef npcById(String id) => npcs.firstWhere((n) => n.id == id);

/// Objets perdus de Mamie Josette.
const lostItems = [
  'le dentier en or',
  'la pelote de laine fétiche',
  'le sonotone',
  'la photo du chat Mistigri',
  'la télécommande de la télé',
];
