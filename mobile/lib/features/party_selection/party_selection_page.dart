import 'package:flutter/material.dart';

import '../../core/layout/app_scaffold.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/party.dart';
import '../../shared/quiz_session.dart';

class PartySelectionPage extends StatefulWidget {
  const PartySelectionPage({super.key});

  @override
  State<PartySelectionPage> createState() => _PartySelectionPageState();
}

class _PartySelectionPageState extends State<PartySelectionPage> {
  final QuizSession _session = QuizSession.instance;
  bool _allSelected = false;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _expandedPartyId;

  List<Party> get _parties => _session.candidates;
  Set<String> get _selected => _session.selectedCandidateIds;

  @override
  void initState() {
    super.initState();
    _loadCandidates();
  }

  Future<void> _loadCandidates() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await _session.loadCandidates();
      _allSelected = _selected.length == _parties.length && _parties.isNotEmpty;
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
      _expandedPartyId = id;
    });
  }

  Future<void> _submitAndNavigate() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await _session.submit();
      if (mounted) Navigator.pushNamed(context, '/results');
    } catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'FAROL POLÍTICO',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          Navigator.pushReplacementNamed(context, '/weighting');
        },
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody(Theme.of(context).textTheme)),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selected.isNotEmpty && !_isSubmitting
                    ? _submitAndNavigate
                    : null,
                child: Text(_isSubmitting ? 'CALCULANDO...' : 'VER RESULTADOS'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(TextTheme textTheme) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Não foi possível carregar os candidatos.',
                style: textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadCandidates,
                child: const Text('TENTAR NOVAMENTE'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text('ESCOLHA OS\nPARTIDOS', style: textTheme.displayMedium),
            const SizedBox(height: 16),
            Text(
              'Selecione os partidos que você deseja comparar com suas respostas.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            _SelectAllButton(isSelected: _allSelected, onTap: _toggleAll),
            const SizedBox(height: 24),
            _PartyGrid(
              parties: _parties,
              selected: _selected,
              onToggle: _toggleParty,
            ),
            const SizedBox(height: 24),
            if (_expandedPartyId != null)
              _PartyDetailCard(
                party: _parties.firstWhere((p) => p.id == _expandedPartyId),
              ),
            if (_expandedPartyId == null && _selected.isNotEmpty)
              _PartyDetailCard(
                party: _parties.firstWhere((p) => _selected.contains(p.id)),
              ),
            const SizedBox(height: 24),
          ],
        ),
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
              'SELECIONAR TODOS',
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
                color: isSelected ? AppTheme.primary : AppTheme.outlineVariant,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: party.hasLogoAsset
                  ? Image.asset(
                      party.logoAsset,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => _PartyFallbackLogo(
                        party: party,
                        isSelected: isSelected,
                      ),
                    )
                  : _PartyFallbackLogo(
                      party: party,
                      isSelected: isSelected,
                    ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PartyFallbackLogo extends StatelessWidget {
  final Party party;
  final bool isSelected;

  const _PartyFallbackLogo({
    required this.party,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        party.abbreviation,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: isSelected ? AppTheme.primary : AppTheme.onSurfaceVariant,
        ),
        textAlign: TextAlign.center,
      ),
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
            'O QUE ${party.abbreviation} DEFENDE',
            style: textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(party.description, style: textTheme.bodyMedium),
        ],
      ),
    );
  }
}
