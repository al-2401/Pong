import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../engine/ai_controller.dart';
import '../engine/difficulty.dart';
import '../engine/engine.dart';
import '../engine/game_state.dart';
import '../engine/match_runner.dart';
import '../input/touch_controller.dart';
import '../settings/preferences.dart';
import 'field_projection.dart';
import 'game_painter.dart';
import 'labels.dart';
import 'pong_scope.dart';
import 'theme.dart';
import 'widgets.dart';

/// Decoration the painter reads every frame. It lives outside the widget tree
/// so the ticker can update it without rebuilding anything.
class FieldOverlayData {
  Offset shake = Offset.zero;
  final List<Offset> trail = [];
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.difficulty});

  final Difficulty difficulty;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const int _trailLength = 12;
  static const double _shakeDecay = 0.12;

  final ValueNotifier<int> _frame = ValueNotifier<int>(0);
  final TouchPaddleController _touch = TouchPaddleController();
  final FieldOverlayData _overlay = FieldOverlayData();

  late final Ticker _ticker;
  late PongScope _scope;

  MatchRunner? _runner;
  FieldProjection? _projection;
  Size? _fieldSize;
  Duration _lastTick = Duration.zero;
  double _shake = 0;
  bool _paused = false;
  bool _matchRecorded = false;
  bool _rallyRecord = false;
  bool _orientationLocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scope = PongScope.of(context);
    if (!_orientationLocked) {
      _orientationLocked = true;
      _lockOrientation();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _frame.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && !_paused) {
      setState(() => _paused = true);
    }
  }

  /// The field shape is decided once, on the way in. Rotating mid-rally would
  /// change the geometry while the ball is in flight.
  void _lockOrientation() {
    final allowed = switch (_scope.preferences.orientation) {
      FieldOrientation.portrait => const [
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ],
      FieldOrientation.landscape => const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
      FieldOrientation.auto =>
        MediaQuery.orientationOf(context) == Orientation.portrait
            ? const [
                DeviceOrientation.portraitUp,
                DeviceOrientation.portraitDown,
              ]
            : const [
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ],
    };
    SystemChrome.setPreferredOrientations(allowed);
  }

  void _ensureMatch(Size size) {
    if (_runner != null && _fieldSize == size) return;
    _fieldSize = size;

    // Single player fills the screen, so the field shape comes from the device
    // itself. In a networked match this number will arrive from the host.
    final length = FieldProjection.lengthFor(size);
    final preset = DifficultyPreset.of(widget.difficulty);
    final rules = preset.rulesFor(
      fieldLength: length,
      paddleInertia: _scope.preferences.paddleInertia,
    );

    _projection = FieldProjection.fit(size, length);
    _runner = MatchRunner(
      engine: GameEngine(rules: rules),
      bottom: _touch,
      top: AiPaddleController(side: FieldSide.top, profile: preset.ai),
    );
    _touch.reset();
    _overlay.trail.clear();
    _lastTick = Duration.zero;
    _matchRecorded = false;
    _rallyRecord = false;
  }

  void _onTick(Duration elapsed) {
    final runner = _runner;
    if (runner == null || _paused || runner.state.phase == MatchPhase.matchOver) {
      _lastTick = elapsed;
      return;
    }
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }

    final dt = (elapsed - _lastTick).inMicroseconds / Duration.microsecondsPerSecond;
    _lastTick = elapsed;
    if (dt <= 0) return;

    _handleEvents(runner.advance(dt));
    _updateTrail(runner.state);
    _updateShake(dt);
    _frame.value++;
  }

  void _handleEvents(List<GameEvent> events) {
    if (events.isEmpty) return;
    final state = _runner!.state;

    for (final event in events) {
      switch (event.type) {
        case GameEventType.paddleHit:
          _scope.sound.paddleHit();
          _scope.records.registerSpeed(state.speedProgress);
          if (event.side == FieldSide.bottom) {
            _shake = 1;
            if (_scope.preferences.haptics) HapticFeedback.lightImpact();
          }
        case GameEventType.wallHit:
          _scope.sound.wallHit();
        case GameEventType.score:
          _scope.sound.score();
          if (_scope.preferences.haptics) HapticFeedback.mediumImpact();
          if (_scope.records.registerRally(state.rallyHits)) {
            _rallyRecord = true;
          }
        case GameEventType.matchOver:
          if (!_matchRecorded) {
            _matchRecorded = true;
            _scope.records.registerMatch(
              difficulty: widget.difficulty,
              won: event.side == FieldSide.bottom,
            );
          }
          if (_scope.preferences.haptics) HapticFeedback.heavyImpact();
          setState(() {});
      }
    }
  }

  void _updateTrail(GameState state) {
    if (state.phase != MatchPhase.rally) {
      _overlay.trail.clear();
      return;
    }
    _overlay.trail.add(Offset(state.ball.x, state.ball.y));
    if (_overlay.trail.length > _trailLength) {
      _overlay.trail.removeAt(0);
    }
  }

  void _updateShake(double dt) {
    if (_shake <= 0) {
      _overlay.shake = Offset.zero;
      return;
    }
    _shake = math.max(0, _shake - dt / _shakeDecay);
    final amplitude = _shake * _shake * (_projection?.scale ?? 0) * 0.014;
    _overlay.shake = Offset(
      math.sin(_shake * 41) * amplitude,
      math.cos(_shake * 33) * amplitude,
    );
  }

  void _setPaused(bool value) {
    setState(() {
      _paused = value;
      if (!value) _lastTick = Duration.zero;
    });
  }

  void _restart() {
    setState(() {
      _runner?.reset();
      _overlay.trail.clear();
      _overlay.shake = Offset.zero;
      _shake = 0;
      _lastTick = Duration.zero;
      _matchRecorded = false;
      _rallyRecord = false;
      _paused = false;
    });
  }

  void _onPointer(PointerEvent event) {
    final projection = _projection;
    if (projection == null || _paused) return;
    _touch.target = projection.fieldXFromLocal(event.localPosition);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PongColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            _ensureMatch(size);
            final runner = _runner!;
            final projection = _projection!;

            return Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _onPointer,
              onPointerMove: _onPointer,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: PongPainter(
                        state: runner.state,
                        projection: projection,
                        trail: _overlay.trail,
                        showSpeedMeter: _scope.preferences.speedMeter,
                        shake: _overlay.shake,
                        repaint: _frame,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    left: 4,
                    child: IconButton(
                      onPressed: () => _setPaused(true),
                      icon: const Icon(Icons.pause_rounded),
                      color: PongColors.muted,
                      tooltip: 'Пауза',
                    ),
                  ),
                  if (_paused) _PauseOverlay(
                    onResume: () => _setPaused(false),
                    onRestart: _restart,
                    onExit: () => Navigator.of(context).pop(),
                  ),
                  if (runner.state.phase == MatchPhase.matchOver)
                    _MatchOverOverlay(
                      state: runner.state,
                      difficulty: widget.difficulty,
                      newRecord: _rallyRecord,
                      onRestart: _restart,
                      onExit: () => Navigator.of(context).pop(),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay({
    required this.onResume,
    required this.onRestart,
    required this.onExit,
  });

  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return DimmedPanel(
      children: [
        Text('ПАУЗА', style: mono(size: 28)),
        const SizedBox(height: 28),
        PongButton(label: 'ПРОДОЛЖИТЬ', onPressed: onResume),
        const SizedBox(height: 12),
        PongButton(label: 'ЗАНОВО', onPressed: onRestart, filled: false),
        const SizedBox(height: 12),
        PongButton(label: 'В МЕНЮ', onPressed: onExit, filled: false),
      ],
    );
  }
}

class _MatchOverOverlay extends StatelessWidget {
  const _MatchOverOverlay({
    required this.state,
    required this.difficulty,
    required this.newRecord,
    required this.onRestart,
    required this.onExit,
  });

  final GameState state;
  final Difficulty difficulty;
  final bool newRecord;
  final VoidCallback onRestart;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final won = state.matchWinner == FieldSide.bottom;
    return DimmedPanel(
      children: [
        Text(
          won ? 'ПОБЕДА' : 'ПОРАЖЕНИЕ',
          style: mono(
            size: 30,
            color: won ? PongColors.player : PongColors.opponent,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '${state.bottomScore} : ${state.topScore}',
          style: mono(size: 40, weight: FontWeight.w300),
        ),
        const SizedBox(height: 10),
        Text(
          '${difficulty.title} · ЛУЧШАЯ СЕРИЯ ${state.longestRally}',
          style: mono(size: 12, color: PongColors.muted, letterSpacing: 1.5),
        ),
        if (newRecord) ...[
          const SizedBox(height: 10),
          Text(
            'НОВЫЙ РЕКОРД',
            style: mono(size: 13, color: PongColors.player),
          ),
        ],
        const SizedBox(height: 28),
        PongButton(label: 'ЕЩЁ РАЗ', onPressed: onRestart),
        const SizedBox(height: 12),
        PongButton(label: 'В МЕНЮ', onPressed: onExit, filled: false),
      ],
    );
  }
}
