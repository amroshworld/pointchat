import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import '../services/cache_service.dart';

/// Voice bubble: tap waveform to jump, −1s / +1s buttons, optional speed (1×–2×),
/// horizontal fling skips ~1s per strong fling.
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

    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
        unawaited(_audioPlayer.setPlaybackRate(1.0));
        _speedIndex = 0;
      }
    });

    _playerStateChangeSubscription = _audioPlayer.onPlayerStateChanged.listen((
      state,
    ) {
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
        await _audioPlayer.setSourceDeviceFile(_localAudioPath!);
      }
    } catch (e) {
      if (mounted) {
        await _audioPlayer.setSourceUrl(widget.audioUrl);
      }
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
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.setPlaybackRate(_playbackRate);
      if (_localAudioPath != null) {
        await _audioPlayer.play(DeviceFileSource(_localAudioPath!));
      } else {
        await _audioPlayer.play(UrlSource(widget.audioUrl));
      }
    }
  }

  Future<void> _seekBy(int deltaMs) async {
    if (_duration == Duration.zero) return;
    var ms = _position.inMilliseconds + deltaMs;
    if (ms < 0) ms = 0;
    if (ms > _duration.inMilliseconds) ms = _duration.inMilliseconds;
    await _audioPlayer.seek(Duration(milliseconds: ms));
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
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return '$twoDigitMinutes:$twoDigitSeconds';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fgColor = widget.isMe
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v > 700) {
          unawaited(_seekBy(1000));
        } else if (v < -700) {
          unawaited(_seekBy(-1000));
        }
      },
      child: SizedBox(
        width: 260,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                GestureDetector(
                  onLongPress: _cycleSpeed,
                  onTap: _togglePlay,
                  child: Icon(
                    _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                    color: fgColor,
                    size: 36,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: Icon(Icons.replay_5_rounded, color: fgColor, size: 22),
                  onPressed: () => _seekBy(-1000),
                ),
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
                        child: SizedBox(
                          height: 36,
                          child: CustomPaint(
                            painter: _WaveformPainter(
                              progress: _duration.inMilliseconds == 0
                                  ? 0.0
                                  : _position.inMilliseconds /
                                        _duration.inMilliseconds,
                              color: fgColor.withValues(alpha: 0.3),
                              progressColor: fgColor,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: Icon(Icons.forward_5_rounded, color: fgColor, size: 22),
                  onPressed: () => _seekBy(1000),
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDuration(
                    _position.inMilliseconds > 0 ? _position : _duration,
                  ),
                  style: TextStyle(
                    color: fgColor.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 40, top: 2),
              child: Row(
                children: [
                  Text(
                    'Tap bar to jump · fling ↔ ±1s',
                    style: TextStyle(
                      color: fgColor.withValues(alpha: 0.45),
                      fontSize: 9,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _cycleSpeed,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: fgColor.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        '${_playbackRate == 1.0 || _playbackRate == 2.0 ? _playbackRate.toStringAsFixed(0) : _playbackRate}x',
                        style: TextStyle(
                          color: fgColor.withValues(alpha: 0.85),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color progressColor;

  _WaveformPainter({
    required this.progress,
    required this.color,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final barCount = 30;
    final spacing = size.width / barCount;

    final heights = [
      0.3,
      0.5,
      0.8,
      0.4,
      0.6,
      0.9,
      0.7,
      0.5,
      0.3,
      0.4,
      0.6,
      0.8,
      1.0,
      0.7,
      0.5,
      0.4,
      0.6,
      0.8,
      0.5,
      0.3,
      0.4,
      0.6,
      0.7,
      0.5,
      0.4,
      0.3,
      0.5,
      0.7,
      0.4,
      0.3,
    ];

    for (int i = 0; i < barCount; i++) {
      final x = i * spacing + (spacing / 2);
      final height = size.height * heights[i % heights.length];
      final yOffset = (size.height - height) / 2;

      final isPast = (i / barCount) <= progress;
      paint.color = isPast ? progressColor : color;

      canvas.drawLine(Offset(x, yOffset), Offset(x, yOffset + height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.progressColor != progressColor;
  }
}
