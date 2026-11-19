/// Répliques de MAESTRO, l'animateur du show. `{name}`, `{floor}`, `{monster}` sont remplacés.
abstract final class MaestroLines {
  static const runStart = [
    "Bienvenue dans DONJON EN DIRECT ! Souriez, vous êtes filmé. Et probablement bientôt mort.",
    "Un nouveau candidat ! Les paris sont ouverts : je donne trois étages, grand maximum.",
    "Mesdames, messieurs, entités gazeuses : voici notre chair à canon du jour !",
  ];

  static const firstKill = [
    "Premier sang ! L'audience se réveille enfin.",
    "Oh, il sait taper. Notez-le, la régie.",
    "Un {monster} de moins. Sa famille a été prévenue par courrier publicitaire.",
  ];

  static const newFloor = [
    "Étage {floor} ! Les sponsors commencent à retenir votre nom. Enfin, presque.",
    "Bienvenue à l'étage {floor}. Ici, même la moquette est hostile.",
    "Étage {floor}. Statistiquement, c'est ici que les gens comme vous abandonnent. Ou meurent.",
    "Descente réussie ! Étage {floor}. On applaudit, on applaudit.",
  ];

  static const levelUp = [
    "Niveau supérieur ! Vous êtes désormais légèrement moins pathétique.",
    "Montée de niveau ! La régie a validé une augmentation de votre espérance de vie de 4 secondes.",
  ];

  static const lowHp = [
    "Hmm, ça sent le sapin. Quelqu'un a pensé à la musique triste ?",
    "Ses points de vie fondent ! Restez avec nous après la pub.",
    "Attention, candidat en danger. Je veux dire : CONTENU EN DANGER.",
  ];

  static const death = [
    "Et c'est terminé ! Rediffusion de ce moment tragique en boucle toute la semaine.",
    "Paix à son âme. Le prochain candidat est déjà dans le sas.",
    "Mort au combat. Enfin, « combat » est un grand mot.",
  ];

  static const potion = [
    "Il boit un liquide trouvé par terre. Nos juristes déclinent toute responsabilité.",
  ];

  static const timerWarning = [
    "Plus que {left} tours avant la démolition de l'étage ! Les bulldozers chauffent.",
    "Attention : démolition dans {left} tours. Je dis ça, je dis rien.",
  ];

  static const demolition = [
    "DÉMOLITION ! Le plafond s'effondre. Courez, ou ne courez pas, c'est très télégénique aussi.",
    "Fin de l'épisode ! L'étage est démoli. Avec vous dedans, apparemment.",
  ];

  static const twist = [
    "On s'ennuie en régie. REBONDISSEMENT ! Lâchez les invités surprise !",
    "L'audience s'effondre. Vite, des monstres ! N'importe lesquels !",
    "Ennuyeux. ENNUYEUX. La régie envoie de quoi pimenter tout ça.",
  ];

  static const viral = [
    "VOUS ÊTES VIRAL ! Des milliards de paires d'yeux sur vous. Et quelques tentacules.",
    "Les compteurs explosent ! Ne mourez pas maintenant, ce serait du gâchis.",
  ];

  static const sponsorGift = [
    "Colis parachuté de la part de {sponsor} ! Ils vous aiment. Pour l'instant.",
    "{sponsor} vous offre un cadeau. N'oubliez pas de les remercier à l'antenne.",
  ];

  static const secondWind = [
    "Il aurait dû mourir ! Le public hurle ! On rembobine pour le ralenti !",
  ];

  static const bossIntro = [
    "Mesdames, messieurs, la tête d'affiche de la zone : {boss} ! La sortie reste verrouillée tant qu'il respire.",
    "Roulements de tambour... {boss} entre en scène ! Pas d'escalier pour vous tant que la star tient debout.",
  ];

  static const bossDown = [
    "{boss} est tombé ! Je ne l'aimais pas de toute façon. La sortie est ouverte.",
    "Incroyable ! {boss} est vaincu ! Ses fans vont vous haïr. Nos audiences vont vous adorer.",
  ];

  static const enrage = [
    "{boss} est furieux ! Ça va faire mal. Pour vous.",
  ];

  static const victory = [
    "C'EST FINI ! Le Directeur est tombé ! Vous avez gagné la saison ! ... La saison 2 démarre lundi.",
  ];

  static const interviewIntro = [
    "Bienvenue sur le plateau ! Asseyez-vous, essuyez ce sang, et souriez : on est en direct.",
    "Et voici notre candidat, qui a survécu à l'étage {floor} ! Applaudissez, ou je vous fais applaudir.",
    "Lumières ! Caméras ! Candidat légèrement abîmé ! C'est l'heure de l'interview.",
  ];
}
