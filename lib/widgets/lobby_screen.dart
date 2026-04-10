import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/player.dart';
import '../controllers/game_controller.dart';
import 'board_widget.dart';

// ============================================================================
// Token definitions — 8 classic Monopoly-style colors with emoji icons
// ============================================================================
class _Token {
  final Color color;
  final String emoji;
  final String label;
  const _Token(this.color, this.emoji, this.label);
}

const List<_Token> kTokens = [
  _Token(Color(0xFFE53935), '🎩', 'Top Hat'),
  _Token(Color(0xFF1E88E5), '🚗', 'Car'),
  _Token(Color(0xFF43A047), '🐶', 'Dog'),
  _Token(Color(0xFFFFB300), '⚓', 'Anchor'),
  _Token(Color(0xFF8E24AA), '👠', 'Heel'),
  _Token(Color(0xFFFF6F00), '🛥️', 'Boat'),
  _Token(Color(0xFF00ACC1), '🎸', 'Guitar'),
  _Token(Color(0xFFF06292), '👑', 'Crown'),
];

// ============================================================================
// LobbyScreen
// ============================================================================
class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  // Start with 2 players
  final List<_PlayerEntry> _entries = [
    _PlayerEntry(name: 'Player 1', tokenIndex: 0),
    _PlayerEntry(name: 'Player 2', tokenIndex: 1),
  ];

  bool get _canStart => _entries.length >= 2 && _allNamesValid;

  bool get _allNamesValid =>
      _entries.every((e) => e.name.trim().isNotEmpty);

  Set<int> get _usedTokenIndices =>
      _entries.map((e) => e.tokenIndex).toSet();

  void _addPlayer() {
    if (_entries.length >= 8) return;
    // Pick first unused token
    final usedIndices = _usedTokenIndices;
    final nextToken =
        List.generate(8, (i) => i).firstWhere((i) => !usedIndices.contains(i));
    setState(() {
      _entries.add(_PlayerEntry(
        name: 'Player ${_entries.length + 1}',
        tokenIndex: nextToken,
      ));
    });
  }

  void _removePlayer(int index) {
    if (_entries.length <= 2) return;
    setState(() => _entries.removeAt(index));
  }

  void _onTokenSelected(int entryIndex, int tokenIndex) {
    // Swap tokens if already taken
    final existingIndex =
        _entries.indexWhere((e) => e.tokenIndex == tokenIndex);
    setState(() {
      if (existingIndex != -1 && existingIndex != entryIndex) {
        _entries[existingIndex].tokenIndex = _entries[entryIndex].tokenIndex;
      }
      _entries[entryIndex].tokenIndex = tokenIndex;
    });
  }

  void _startGame() {
    if (!_canStart) return;

    final players = _entries.asMap().entries.map((e) {
      final index = e.key;
      final entry = e.value;
      final token = kTokens[entry.tokenIndex];
      return Player(
        id: 'player_${index + 1}',
        name: entry.name.trim(),
        tokenColor: token.color,
        balance: 150000,
      );
    }).toList();

    // Override the provider with the lobby-selected players
    ref.read(gameControllerProvider.notifier).initPlayers(players);

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => const Scaffold(
          backgroundColor: Color(0xFF0D1A0D),
          body: SafeArea(child: BoardWidget()),
        ),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1A0D),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _entries.length,
                itemBuilder: (context, i) => _PlayerCard(
                  entry: _entries[i],
                  entryIndex: i,
                  canRemove: _entries.length > 2,
                  usedTokenIndices: _usedTokenIndices,
                  onNameChanged: (name) =>
                      setState(() => _entries[i].name = name),
                  onTokenSelected: (ti) => _onTokenSelected(i, ti),
                  onRemove: () => _removePlayer(i),
                ),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF1B2A1B),
        border: Border(
          bottom: BorderSide(color: Color(0xFF2E4A2E), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🏙️', style: TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'LAGOS MONOPOLY',
                    style: TextStyle(
                      color: Color(0xFFFFD600),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                  ),
                  Text(
                    '${_entries.length} player${_entries.length > 1 ? 's' : ''} • tap to configure',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: const BoxDecoration(
        color: Color(0xFF1B2A1B),
        border: Border(top: BorderSide(color: Color(0xFF2E4A2E), width: 1)),
      ),
      child: Row(
        children: [
          // Add player button
          if (_entries.length < 8)
            Expanded(
              child: _LobbyButton(
                label: '+ Add Player',
                color: Colors.white12,
                textColor: Colors.white70,
                onTap: _addPlayer,
              ),
            ),
          if (_entries.length < 8) const SizedBox(width: 12),

          // Start game button
          Expanded(
            flex: 2,
            child: _LobbyButton(
              label: _canStart ? '🚀  Start Game' : 'Enter all names',
              color: _canStart
                  ? const Color(0xFFFFD600)
                  : Colors.white12,
              textColor: _canStart ? Colors.black : Colors.white38,
              onTap: _canStart ? _startGame : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// _PlayerCard — one row per player with name field + token picker
// ============================================================================
class _PlayerCard extends StatelessWidget {
  final _PlayerEntry entry;
  final int entryIndex;
  final bool canRemove;
  final Set<int> usedTokenIndices;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<int> onTokenSelected;
  final VoidCallback onRemove;

  const _PlayerCard({
    required this.entry,
    required this.entryIndex,
    required this.canRemove,
    required this.usedTokenIndices,
    required this.onNameChanged,
    required this.onTokenSelected,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final token = kTokens[entry.tokenIndex];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2A1B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: token.color.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // ── Name row ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
            child: Row(
              children: [
                // Current token badge
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: token.color.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: token.color, width: 2),
                  ),
                  child: Center(
                    child: Text(token.emoji,
                        style: const TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 12),

                // Name text field
                Expanded(
                  child: TextField(
                    controller:
                        TextEditingController(text: entry.name)
                          ..selection = TextSelection.collapsed(
                              offset: entry.name.length),
                    onChanged: onNameChanged,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Enter name…',
                      hintStyle:
                          const TextStyle(color: Colors.white38, fontSize: 14),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 10),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Remove button
                if (canRemove)
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.white38, size: 18),
                    onPressed: onRemove,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),

          // ── Token picker row ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: List.generate(kTokens.length, (i) {
                final t = kTokens[i];
                final isSelected = entry.tokenIndex == i;
                final isTaken =
                    usedTokenIndices.contains(i) && !isSelected;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => onTokenSelected(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      height: 38,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? t.color.withOpacity(0.3)
                            : Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? t.color
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Opacity(
                          opacity: isTaken ? 0.25 : 1.0,
                          child: Text(t.emoji,
                              style: TextStyle(
                                  fontSize: isSelected ? 20 : 16)),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// _LobbyButton
// ============================================================================
class _LobbyButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback? onTap;

  const _LobbyButton({
    required this.label,
    required this.color,
    required this.textColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// _PlayerEntry — mutable local state for one lobby row
// ============================================================================
class _PlayerEntry {
  String name;
  int tokenIndex;
  _PlayerEntry({required this.name, required this.tokenIndex});
}
