// lib/shared/widgets/drawer/followed_actor_tile.dart
//
// Quem a pessoa escolheu acompanhar. E o dado que da sentido ao bloco de cima:
// o LED do Farol acende pelos votos DESTE parlamentar.

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../models/political_actor.dart';
import 'drawer_section.dart';

class FollowedActorTile extends StatelessWidget {
  const FollowedActorTile({
    super.key,
    required this.actor,
    required this.onOpenProfile,
    required this.onChoose,
    this.featureEnabled = true,
  });

  final PoliticalActor? actor;
  final VoidCallback onOpenProfile;
  final VoidCallback onChoose;
  final bool featureEnabled;

  @override
  Widget build(BuildContext context) {
    final followed = actor;

    return InkWell(
      onTap: !featureEnabled || followed == null ? null : onOpenProfile,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DrawerSectionLabel(
              featureEnabled ? 'ACOMPANHANDO' : 'ACOMPANHAR POLÍTICOS',
            ),
            const SizedBox(height: 12),
            if (!featureEnabled)
              _Validation(onChoose: onChoose)
            else if (followed == null)
              _Empty(onChoose: onChoose)
            else
              _Followed(actor: followed),
          ],
        ),
      ),
    );
  }
}

class _Validation extends StatelessWidget {
  const _Validation({required this.onChoose});

  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('EM VALIDAÇÃO', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Ajude a decidir se esta área deve ser lançada.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 6),
        DrawerInlineAction(label: 'Conhecer a validação', onTap: onChoose),
      ],
    );
  }
}

class _Followed extends StatelessWidget {
  const _Followed({required this.actor});

  final PoliticalActor actor;

  /// `PDT • RS · Deputada(o) federal`, pulando o que a Camara nao informou —
  /// um "null • RS" na gaveta e pior do que uma linha mais curta.
  String get _subtitle {
    final origin = [actor.party, actor.state].whereType<String>().join(' • ');
    return origin.isEmpty ? actor.roleLabel : '$origin · ${actor.roleLabel}';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        _Initials(name: actor.displayName),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                actor.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleLarge,
              ),
              Text(
                _subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const Icon(
          Icons.chevron_right,
          size: 20,
          color: AppTheme.onSurfaceVariant,
        ),
      ],
    );
  }
}

/// Iniciais em vez da foto da Camara: a gaveta abre e fecha em um gesto, e um
/// circulo vazio esperando download seria o que a pessoa mais veria.
class _Initials extends StatelessWidget {
  const _Initials({required this.name});

  final String name;

  String get _initials {
    final words = name.trim().split(RegExp(r'\s+'))
      ..removeWhere((word) => word.isEmpty);
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      final only = words.first;
      return (only.length == 1 ? only : only.substring(0, 2)).toUpperCase();
    }
    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.surfaceContainerHigh,
      ),
      child: Text(
        _initials,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppTheme.onSurface,
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onChoose});

  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Você ainda não segue ninguém.',
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                color: AppTheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 6),
        DrawerInlineAction(label: 'Escolher um político', onTap: onChoose),
      ],
    );
  }
}
