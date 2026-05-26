import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../core/theme/app_theme.dart';

class VoicePlayerWidget extends StatefulWidget {
  final String url;
  final bool isMine;
  final String? fileName;
  final int? initialDurationSec;

  const VoicePlayerWidget({
    super.key,
    required this.url,
    required this.isMine,
    this.fileName,
    this.initialDurationSec,
  });

  @override
  State<VoicePlayerWidget> createState() => _VoicePlayerWidgetState();
}

class _VoicePlayerWidgetState extends State<VoicePlayerWidget>
    with TickerProviderStateMixin {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _completeSub;
  late AnimationController _waveCtrl;
  late List<Animation<double>> _waveAnims;

  @override
  void initState() {
    super.initState();
    if (widget.initialDurationSec != null) {
      _duration = Duration(seconds: widget.initialDurationSec!);
    }
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _waveAnims = List.generate(4, (i) {
      return Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(
          parent: _waveCtrl,
          curve: Interval(i * 0.15, 0.6 + i * 0.1, curve: Curves.easeInOut),
        ),
      );
    });
    _posSub = _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _durSub = _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _completeSub = _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _completeSub?.cancel();
    _player.dispose();
    _waveCtrl.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
      setState(() => _isPlaying = false);
    } else {
      await _player.play(UrlSource(widget.url));
      setState(() => _isPlaying = true);
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isMine ? Colors.white : AppTheme.primaryColor;
    final bgColor = widget.isMine
        ? AppTheme.primaryColor.withValues(alpha: 0.3)
        : AppTheme.cardHighColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _togglePlay,
            child: Icon(
              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(width: 6),
          ...List.generate(4, (i) {
            return AnimatedBuilder(
              animation: _waveAnims[i],
              builder: (ctx, child) {
                return Container(
                  width: 3,
                  height: 14 * _waveAnims[i].value,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    color: _isPlaying ? color : color.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              },
            );
          }),
          const SizedBox(width: 8),
          Text(
            _isPlaying
                ? _fmt(_position)
                : _duration > Duration.zero
                    ? _fmt(_duration)
                    : _fmt(Duration.zero),
            style: TextStyle(
              color: color.withValues(alpha: 0.9),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}