import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/layout/app_scaffold.dart';
import '../../shared/models/party.dart';

class PartySelectionPage extends StatefulWidget {
  const PartySelectionPage({super.key});

  @override
  State<PartySelectionPage> createState() => _PartySelectionPageState();
}

class _PartySelectionPageState extends State<PartySelectionPage> {
  final List<Party> _parties = Party.getSampleParties();
  final Set<String> _selected = {};
  bool _allSelected = false;
  String? _expandedPartyId;

  void _toggleAll() {
    setState(() {
      _allSelected = !_allSelected;
      if (_allSelected) {
        _selected.addAll(_parties.map((p) => p.id));
      } else {
        _selected.clear();
      }
    });
  }

  void _toggleParty(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
        _allSelected = false;
      } else {
        _selected.add(id);
        _allSelected = _selected.length == _parties.length;
      }
    });
  }

  void _toggleExpanded(String id) {
    setState(() {
      _expandedPartyId = _expandedPartyId == id ? null : id;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppScaffold(
      title: 'GUIA ELEITORAL',
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    Text(
                      'ESCOLHA OS\nPARTIDOS',
                      style: textTheme.displayMedium,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Selecione os partidos que você deseja comparar com suas respostas. Você pode escolher todos ou apenas os de seu interesse.',
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    _SelectAllButton(
                      isSelected: _allSelected,
                      onTap: _toggleAll,
                    ),
                    const SizedBox(height: 24),
                    _PartyGrid(
                      parties: _parties,
                      selected: _selected,
                      onToggle: _toggleParty,
                    ),
                    const SizedBox(height: 24),
                    if (_expandedPartyId != null)
                      _PartyDetailCard(
                        party: _parties.firstWhere(
                          (p) => p.id == _expandedPartyId,
                        ),
                      ),
                    if (_expandedPartyId == null && _selected.isNotEmpty)
                      _PartyDetailCard(
                        party: _parties.firstWhere(
                          (p) => _selected.contains(p.id),
                        ),
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selected.isNotEmpty
                    ? () => Navigator.pushNamed(context, '/results')
                    : null,
                child: const Text('VER RESULTADOS'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectAllButton extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectAllButton({required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.surfaceContainer,
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_box : Icons.check_box_outline_blank,
              color: isSelected ? AppTheme.background : AppTheme.onSurface,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              'SELECIONAR TODOS OS PARTIDOS',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected ? AppTheme.background : AppTheme.onSurface,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartyGrid extends StatelessWidget {
  final List<Party> parties;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  const _PartyGrid({
    required this.parties,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: parties.map((party) {
        final isSelected = selected.contains(party.id);
        return GestureDetector(
          onTap: () => onToggle(party.id),
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.surfaceContainerHigh
                  : AppTheme.surfaceContainer,
              border: Border.all(
                color: isSelected
                    ? AppTheme.primary
                    : AppTheme.outlineVariant,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Center(
              child: Text(
                party.abbreviation,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isSelected
                      ? AppTheme.primary
                      : AppTheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PartyDetailCard extends StatelessWidget {
  final Party party;

  const _PartyDetailCard({required this.party});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${party.name} (${party.abbreviation})',
            style: textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            party.description,
            style: textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
