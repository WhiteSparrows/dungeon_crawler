import 'entities.dart';
import 'rng.dart';

class AttackResult {
  const AttackResult(this.damage, {this.crit = false, this.miss = false});
  final int damage;
  final bool crit;
  final bool miss;
}

/// Résout une attaque au contact. 85 % de toucher, [critChance] de critique (x2),
/// dégâts = (atk + bonus aléatoire - def) x [multiplier], minimum 1.
AttackResult resolveAttack(Actor attacker, Actor target, Rng rng,
    {double critChance = 0.10, int multiplier = 1, bool sure = false}) {
  if (!sure && !rng.chance(0.85)) return const AttackResult(0, miss: true);
  final bonus = rng.range(0, (attacker.atk / 2).ceil());
  var dmg = (attacker.atk + bonus - target.def) * multiplier;
  if (dmg < 1) dmg = 1;
  final crit = rng.chance(critChance);
  if (crit) dmg *= 2;
  return AttackResult(dmg, crit: crit);
}
