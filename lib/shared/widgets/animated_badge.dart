import 'package:flutter/material.dart';

String badgeEmojiForLevel(int level) {
  if (level <= 5) return '⭐';
  if (level <= 15) return '🌟';
  if (level <= 30) return '💎';
  if (level <= 50) return '👑';
  if (level <= 75) return '🔥';
  return '🏆';
}

Color badgeColorForLevel(int level) {
  if (level <= 5) return const Color(0xFFFFD700);
  if (level <= 15) return const Color(0xFF00BFFF);
  if (level <= 30) return const Color(0xFFE040FB);
  if (level <= 50) return const Color(0xFFFF6F00);
  if (level <= 75) return const Color(0xFFFF1744);
  return const Color(0xFFFFD700);
}

class AnimatedBadge extends StatefulWidget {
  final int level;
  final double size;

  const AnimatedBadge({super.key, required this.level, this.size = 24});

  @override
  State<AnimatedBadge> createState() => _AnimatedBadgeState();
}

class _AnimatedBadgeState extends State<AnimatedBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnim = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _glowAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(AnimatedBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.level != widget.level) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emoji = badgeEmojiForLevel(widget.level);
    final color = badgeColorForLevel(widget.level);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.5 + _scaleAnim.value * 0.5,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4 * _glowAnim.value),
                  blurRadius: 6 + 4 * _glowAnim.value,
                  spreadRadius: 1 * _glowAnim.value,
                ),
              ],
            ),
            child: Center(
              child: Text(emoji, style: TextStyle(fontSize: widget.size * 0.6)),
            ),
          ),
        );
      },
    );
  }
}

class AnimatedBadgeRow extends StatelessWidget {
  final int level;
  final double badgeSize;
  const AnimatedBadgeRow({
    super.key,
    required this.level,
    this.badgeSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    final color = badgeColorForLevel(level);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBadge(level: level, size: badgeSize),
        const SizedBox(width: 6),
        Text(
          'Lv$level',
          style: TextStyle(
            color: color,
            fontSize: badgeSize * 0.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
