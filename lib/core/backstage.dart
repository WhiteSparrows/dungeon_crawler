import '../content/interviews.dart';
import '../content/items.dart';
import '../content/talents.dart';

class ShopOffer {
  ShopOffer(this.item, this.price);
  final ItemDef item;
  final int price;
  bool sold = false;
}

/// Résultat d'une réponse en interview, pour l'affichage.
class AnswerResult {
  const AnswerResult(this.answerText, this.reaction, this.crowd, this.effects);
  final String answerText;
  final String reaction;
  final Crowd crowd;
  final List<String> effects;
}

/// Entre deux étages : l'interview sur le plateau de MAESTRO, puis les coulisses
/// (talent à choisir, boutique, infirmerie).
class Backstage {
  Backstage({
    required this.intro,
    required this.questions,
    required this.shop,
    required this.talents,
    required this.healPrice,
  });

  final String intro;
  final List<Question> questions;
  final results = <AnswerResult>[];
  final List<ShopOffer> shop;
  final List<TalentDef> talents;
  final int healPrice;
  bool talentPicked = false;
  bool healed = false;

  int get current => results.length;
  bool get interviewDone => results.length >= questions.length;
  Question? get question => interviewDone ? null : questions[current];
}
