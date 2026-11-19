/// Répliques de MAESTRO, l'animateur du show. `{name}`, `{floor}`, `{monster}` sont remplacés.
abstract final class MaestroLines {
  static const runStart = [
    "Bienvenue dans DONJON EN DIRECT ! Souriez, vous êtes filmé. Et probablement bientôt mort.",
    "Un nouveau candidat ! Les paris sont ouverts : je donne trois étages, grand maximum.",
    "Mesdames, messieurs, entités gazeuses : voici notre chair à canon du jour !",
    "Le candidat entre en scène ! Notre service juridique me prie de rappeler que la mort est incluse dans le contrat.",
    "Bonsoir et bienvenue ! Ce soir, un humain, un donjon, et zéro chance. Ça va être magnifique.",
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
    "Étage {floor} ! Le décorateur a fait de son mieux. Il est mort depuis, mais il a fait de son mieux.",
    "Étage {floor}. Les monstres d'ici ont lu votre dossier. Ils ont ri.",
    "Bienvenue à l'étage {floor}, où le wifi est mauvais et les chances de survie pires.",
    "Étage {floor} ! Petit rappel : les escaliers, c'est vers le bas. Les cercueils aussi.",
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
    "Fin de l'aventure ! Ses organes ont été promis à trois sponsors différents. On va devoir partager.",
    "Et voilà. On garde la scène pour le bêtisier de fin d'année.",
    "Décès confirmé. L'audience remercie le candidat pour sa contribution au divertissement intergalactique.",
  ];

  static const potion = [
    "Il boit un liquide trouvé par terre. Nos juristes déclinent toute responsabilité.",
  ];

  /// Commentaires spontanés pendant la partie.
  static const ambient = [
    "Petit message de la régie : arrêtez de regarder les murs, il n'y a rien derrière. Enfin, rien de légal.",
    "Saviez-vous que 73 % des candidats meurent en lisant ce genre de message ? Ne vous déconcentrez pas.",
    "Nos statisticiens confirment : vous marchez bizarrement. Le public adore.",
    "Une pensée pour notre caméraman de l'étage, mangé hier. Il filmait très bien. Il filmait jusqu'au bout.",
    "Quelqu'un dans le public demande si vous êtes célibataire. C'est un tentacule qui demande. Je transmets.",
    "On me signale en oreillette que votre mère regarde. Bonjour madame ! Elle dit que vous vous tenez mal.",
    "Rappel : si vous trouvez la sortie du donjon, merci de ne pas l'utiliser. Elle n'existe pas. C'est un détail.",
    "Je m'ennuie. Faites quelque chose de stupide, s'il vous plaît. Pour moi.",
    "Les parieurs ont relevé votre cote. Personne ne sait pourquoi. Moi non plus.",
    "Attention, ce donjon contient des traces de fruits à coque, de magie noire et de clauses abusives.",
    "La régie me dit que vous saignez sur la moquette de location. Ce sera retenu sur vos gains.",
    "Fun fact : ce donjon a été construit par le plus bas soumissionnaire. Ça se voit, non ?",
  ];

  /// Fausses coupures pub. `{sponsor}` et `{slogan}` sont remplacés.
  static const ads = [
    "PAGE DE PUB ! {sponsor} : {slogan} Et maintenant, retour au massacre.",
    "Cette séquence vous est offerte par {sponsor}. « {slogan} » Conditions en petits caractères, très petits, illisibles.",
    "Une pause pour nos partenaires : {sponsor}. {slogan} Merci de ne pas mourir pendant la pub, ça gâche l'effet.",
    "{sponsor} vous rappelle : {slogan} Offre valable dans tout l'univers sauf ici.",
  ];

  /// Petites blagues après une élimination (de temps en temps).
  static const killQuips = [
    "Ouch. Celle-là, on la passera au ralenti.",
    "Et un de moins ! Plus que quelques milliards.",
    "Le public hurle ! Enfin, une partie du public. L'autre partie, c'était sa famille.",
    "Élimination propre. Enfin, « propre »...",
    "Notre équipe de nettoyage vous déteste, mais notre audimat vous adore.",
    "Magnifique ! On en fera un mème.",
    "Il avait des rêves, vous savez. Bon, des rêves de vous manger, mais quand même.",
    "Coup parfait. Les juges donnent 9,5. Le jury d'outre-tombe donne 2.",
  ];

  static const trapFall = [
    "La trappe s'ouvre ! Notre candidat descend un étage par la méthode express. Pas d'interview, pas de bisous.",
  ];

  static const trapSpotted = [
    "Bien vu ! Ce piège nous a coûté cher, vous auriez pu au moins marcher dessus.",
    "Vous avez repéré un piège. Le stagiaire qui l'a posé sera licencié.",
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
