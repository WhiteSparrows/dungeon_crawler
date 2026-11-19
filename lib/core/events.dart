import 'grid.dart';

/// Événements émis par le moteur à chaque tour. L'UI s'en sert pour animer,
/// la future couche « show » (audience, sponsors) s'en servira pour réagir.
sealed class GameEvent {
  const GameEvent();
}

class MoveEvent extends GameEvent {
  const MoveEvent(this.actorId, this.from, this.to);
  final int actorId;
  final Pos from;
  final Pos to;
}

class AttackEvent extends GameEvent {
  const AttackEvent({
    required this.attackerId,
    required this.targetId,
    required this.from,
    required this.to,
    required this.damage,
    this.crit = false,
    this.miss = false,
  });
  final int attackerId;
  final int targetId;
  final Pos from;
  final Pos to;
  final int damage;
  final bool crit;
  final bool miss;
}

class DeathEvent extends GameEvent {
  const DeathEvent(this.actorId, this.pos, this.sprite, {this.isPlayer = false});
  final int actorId;
  final Pos pos;
  final int sprite;
  final bool isPlayer;
}

class HealEvent extends GameEvent {
  const HealEvent(this.pos, this.amount);
  final Pos pos;
  final int amount;
}

class PickupEvent extends GameEvent {
  const PickupEvent(this.pos, this.label);
  final Pos pos;
  final String label;
}

class LevelUpEvent extends GameEvent {
  const LevelUpEvent(this.level);
  final int level;
}

class FloorEvent extends GameEvent {
  const FloorEvent(this.floor);
  final int floor;
}

class AchievementEvent extends GameEvent {
  const AchievementEvent(this.id);
  final String id;
}

/// Une loot box vient d'être gagnée (succès, montée de niveau, coffre).
class BoxGainedEvent extends GameEvent {
  const BoxGainedEvent(this.tierIndex, this.reason);
  final int tierIndex;
  final String reason;
}

/// Une potion / fiole a été bue ([unknown] : fiole mystère pas encore identifiée).
class ItemUsedEvent extends GameEvent {
  const ItemUsedEvent({this.unknown = false});
  final bool unknown;
}

class GoldEvent extends GameEvent {
  const GoldEvent(this.amount);
  final int amount;
}

class ItemPickedEvent extends GameEvent {
  const ItemPickedEvent();
}

/// Une mimique se révèle.
class RevealEvent extends GameEvent {
  const RevealEvent(this.pos);
  final Pos pos;
}

class SponsorGiftEvent extends GameEvent {
  const SponsorGiftEvent(this.sponsorIndex, this.tierIndex);
  final int sponsorIndex;
  final int tierIndex;
}

/// La régie lâche des monstres pour réveiller l'audience.
class TwistEvent extends GameEvent {
  const TwistEvent();
}

/// L'étage est en cours de démolition et blesse le joueur.
class DemolitionEvent extends GameEvent {
  const DemolitionEvent(this.damage);
  final int damage;
}

/// Le joueur quitte l'étage : interview puis coulisses.
class BackstageEvent extends GameEvent {
  const BackstageEvent();
}

/// Une altération (poison, feu, étourdi, gêné) touche un acteur.
class StatusEvent extends GameEvent {
  const StatusEvent(this.actorId, this.pos, this.statusIndex);
  final int actorId;
  final Pos pos;
  final int statusIndex;
}

/// Dégâts d'une altération en fin de tour.
class StatusDamageEvent extends GameEvent {
  const StatusDamageEvent(this.actorId, this.pos, this.damage, this.statusIndex);
  final int actorId;
  final Pos pos;
  final int damage;
  final int statusIndex;
}

/// Un boss apparaît à l'écran (première fois) ou tombe.
class BossEvent extends GameEvent {
  const BossEvent(this.name, {this.defeated = false});
  final String name;
  final bool defeated;
}

/// Le boss final est vaincu : la saison est gagnée.
class VictoryEvent extends GameEvent {
  const VictoryEvent();
}

/// Le joueur s'approche d'un lieu interactif : un choix s'ouvre.
class FeatureEvent extends GameEvent {
  const FeatureEvent(this.pos);
  final Pos pos;
}

/// Un piège se déclenche ou est repéré.
class TrapEvent extends GameEvent {
  const TrapEvent(this.pos, this.kindIndex, {this.triggered = true});
  final Pos pos;
  final int kindIndex;
  final bool triggered;
}

/// Un modificateur d'étage est annoncé.
class FloorModEvent extends GameEvent {
  const FloorModEvent(this.modIndex);
  final int modIndex;
}

enum MessageKind { info, good, danger, maestro }

class MessageEvent extends GameEvent {
  const MessageEvent(this.text, [this.kind = MessageKind.info]);
  final String text;
  final MessageKind kind;
}
