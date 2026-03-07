import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import '../services/cache_service.dart';

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
        _audioPlayer.setPlaybackRate(1.0);
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

    // Cache the audio file locally
    try {
      final fileInfo = await MediaCacheManager.instance.downloadFile(
        widget.audioUrl,
      );
      if (mounted) {
        _localAudioPath = fileInfo.file.path;
        _audioPlayer.setSourceDeviceFile(_localAudioPath!);
      }
    } catch (e) {
      if (mounted) {
        _audioPlayer.setSourceUrl(widget.audioUrl);
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

  void _togglePlay() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      if (_localAudioPath != null) {
        await _audioPlayer.play(DeviceFileSource(_localAudioPath!));
      } else {
        await _audioPlayer.play(UrlSource(widget.audioUrl));
      }
    }
  }

  void _onDragUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    if (_duration == Duration.zero) return;

    final percent = details.delta.dx / constraints.maxWidth;
    final change = _duration.inMilliseconds * percent;

    int newPosition = _position.inMilliseconds + change.toInt();
    if (newPosition < 0) newPosition = 0;
    if (newPosition > _duration.inMilliseconds) {
      newPosition = _duration.inMilliseconds;
    }

    _audioPlayer.seek(Duration(milliseconds: newPosition));
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fgColor = widget.isMe
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;

    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: _togglePlay,
            child: Icon(
              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
              color: fgColor,
              size: 36,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onHorizontalDragUpdate: (details) =>
                      _onDragUpdate(details, constraints),
                  child: Container(
                    height: 36,
                    color: Colors.transparent, // to catch drags
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
          const SizedBox(width: 8),
          Text(
            _formatDuration(_position.inSeconds > 0 ? _position : _duration),
            style: TextStyle(
              color: fgColor.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
        ],
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
