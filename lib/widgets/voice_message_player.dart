import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/cache_service.dart';

/// Modern Voice Message Player with dynamic waveform, speed controls (1x-2x),
/// smooth progress ring, and robust audio loading fallback.
class VoiceMessagePlayer extends StatefulWidget {
  final String audioUrl;
  final bool isMe;

  const VoiceMessagePlayer({
    super.key,
    required this.audioUrl,
    required this.isMe,
  });

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerCompleteSubscription;
  StreamSubscription? _playerStateChangeSubscription;

  String? _localAudioPath;

  static const List<double> _speedSteps = [1.0, 1.5, 2.0];
  int _speedIndex = 0;

  double get _playbackRate => _speedSteps[_speedIndex];

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  void _initAudio() async {
    _durationSubscription = _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) setState(() => _duration = duration);
    });

    _positionSubscription = _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) setState(() => _position = position);
    });

    _playerCompleteSubscription =
        _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
        unawaited(_audioPlayer.setPlaybackRate(1.0));
        _speedIndex = 0;
      }
    });

    _playerStateChangeSubscription =
        _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    try {
      final fileInfo = await MediaCacheManager.instance.downloadFile(
        widget.audioUrl,
      );
      if (mounted) {
        _localAudioPath = fileInfo.file.path;
      }
    } catch (_) {
      // Fallback directly to URL source if caching fails
    }
  }

  @override
  void dispose() {
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerCompleteSubscription?.cancel();
    _playerStateChangeSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isLoading) return;
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        setState(() => _isLoading = true);
        await _audioPlayer.setPlaybackRate(_playbackRate);

        if (_localAudioPath != null) {
          await _audioPlayer.play(DeviceFileSource(_localAudioPath!));
        } else {
          await _audioPlayer.play(UrlSource(widget.audioUrl));
        }
      }
    } catch (e) {
      // Fallback try UrlSource
      try {
        await _audioPlayer.play(UrlSource(widget.audioUrl));
      } catch (_) {}
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _seekToFraction(double fraction) {
    if (_duration == Duration.zero) return;
    final clamped = fraction.clamp(0.0, 1.0);
    final ms = (_duration.inMilliseconds * clamped).round();
    _audioPlayer.seek(Duration(milliseconds: ms));
  }

  void _cycleSpeed() {
    setState(() {
      _speedIndex = (_speedIndex + 1) % _speedSteps.length;
    });
    if (_isPlaying) {
      _audioPlayer.setPlaybackRate(_playbackRate);
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(d.inMinutes.remainder(60));
    String seconds = twoDigits(d.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeColor = widget.isMe
        ? colorScheme.primary
        : const Color(0xFF007AFF);
    final fgColor = widget.isMe
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;

    final progress = _duration.inMilliseconds == 0
        ? 0.0
        : (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);

    return Container(
      width: 250,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isMe
            ? activeColor.withValues(alpha: 0.12)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: activeColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Play/Pause button with circular progress ring
              GestureDetector(
                onTap: _togglePlay,
                child: SizedBox(
                  width: 38,
                  height: 38,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 2.5,
                        backgroundColor: activeColor.withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                      ),
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: activeColor,
                          shape: BoxShape.circle,
                        ),
                        child: _isLoading
                            ? const Padding(
                                padding: EdgeInsets.all(7.0),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                _isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Dynamic Waveform
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) {
                        final w = constraints.maxWidth;
                        if (w <= 0) return;
                        _seekToFraction(details.localPosition.dx / w);
                      },
                      onHorizontalDragUpdate: (details) {
                        final w = constraints.maxWidth;
                        if (w <= 0) return;
                        _seekToFraction(details.localPosition.dx / w);
                      },
                      child: SizedBox(
                        height: 32,
                        child: CustomPaint(
                          painter: _ModernWaveformPainter(
                            progress: progress,
                            color: fgColor.withValues(alpha: 0.3),
                            progressColor: activeColor,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(width: 8),

              // Playback Speed Button
              GestureDetector(
                onTap: _cycleSpeed,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: activeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_playbackRate == 1.0 || _playbackRate == 2.0 ? _playbackRate.toStringAsFixed(0) : _playbackRate}x',
                    style: GoogleFonts.inter(
                      color: activeColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // Duration Text
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: Text(
              _isPlaying || _position.inMilliseconds > 0
                  ? '${_formatDuration(_position)} / ${_formatDuration(_duration)}'
                  : _formatDuration(_duration),
              style: GoogleFonts.inter(
                color: fgColor.withValues(alpha: 0.6),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModernWaveformPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color progressColor;

  _ModernWaveformPainter({
    required this.progress,
    required this.color,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    const barCount = 28;
    final spacing = size.width / barCount;

    // Organic waveform height pattern
    final heights = [
      0.35, 0.55, 0.85, 0.45, 0.65, 0.95, 0.75, 0.50,
      0.30, 0.45, 0.65, 0.85, 1.00, 0.70, 0.55, 0.40,
      0.60, 0.80, 0.50, 0.35, 0.45, 0.65, 0.75, 0.55,
      0.40, 0.30, 0.50, 0.70,
    ];

    for (int i = 0; i < barCount; i++) {
      final x = i * spacing + (spacing / 2);
      final height = (size.height * heights[i % heights.length]).clamp(4.0, size.height);
      final yOffset = (size.height - height) / 2;

      final isPast = (i / barCount) <= progress;
      paint.color = isPast ? progressColor : color;

      canvas.drawLine(Offset(x, yOffset), Offset(x, yOffset + height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ModernWaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.progressColor != progressColor;
  }
}
