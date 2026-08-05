import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/level_ui_item.dart';
import '../models/long_distance_target_ui_item.dart';
import '../models/map_generator.dart';
import '../models/side_ui_item.dart';

class RoadScrollViewModel extends ChangeNotifier {
  RoadScrollViewModel() {
    _cameraXOffset = _targetXOffset;
    _lastActiveLevel = pickNearestLevel();
  }

  /// Lower bound for [cameraProgress] — level 1, the very start of the road.
  static const double minProgress = 1.0;

  /// Upper bound for [cameraProgress]. Levels are infinite, so there is no
  /// cap — scrolling forward never stops.
  static const double maxProgress = double.infinity;

  /// How many drag pixels correspond to one level of [cameraProgress].
  static const double pixelsPerLevel = 120.0;

  /// How many levels behind the camera are still included in
  /// [visibleLevels]/[visibleSideItems], so passed items can visibly exit
  /// the screen instead of popping out of existence.
  static const double behindWindow = 3.0;

  /// How many levels ahead of the camera are included in
  /// [visibleLevels]/[visibleSideItems].
  static const double aheadWindow = 10.0;

  /// Exponential decay rate for [_flingVelocity] while flinging (per
  /// second) — higher decays faster, so the fling settles sooner.
  static const double flingDecayRate = 4.0;

  /// Fling speed (in levels/second) below which flinging is considered
  /// finished and the camera snaps to the nearest level instead.
  static const double flingStopThreshold = 0.02;

  /// Duration of one full cycle of [pulsePhase] — the ambient animation
  /// (ring pulse, target glow, side-item bob) that runs even at rest.
  static const double pulsePeriodSeconds = 1.6;

  /// Exponential ease rate for [cameraXOffset] chasing [_targetXOffset]
  /// (per second) — how quickly the camera catches up after crossing a
  /// level boundary.
  static const double cameraXOffsetSmoothingRate = 6.0;

  /// Exponential ease rate for [_cameraProgress] chasing
  /// [_snapTargetProgress] while [_isSnapping] (per second).
  static const double progressSnapRate = 18.0;

  /// Distance (in levels) from [_snapTargetProgress] below which a snap is
  /// considered complete and [_cameraProgress] locks to the exact target.
  static const double progressSnapStopThreshold = 0.01;

  /// How long the active-level indicator's up-and-down hop takes, in
  /// seconds, whenever the active level changes.
  static const double activeIndicatorHopDurationSeconds = 0.35;

  /// Peak height, in pixels, of the active-level indicator's hop.
  static const double activeIndicatorHopHeight = 42.0;

  /// Continuous position along the road, in levels (1-indexed, matching
  /// [LevelUiItem.number]). May be fractional while dragging, flinging, or
  /// snapping; always an exact integer once settled.
  double _cameraProgress = minProgress;

  /// The camera's current horizontal offset, eased toward [_targetXOffset]
  /// every frame — see [cameraXOffset].
  double _cameraXOffset = 0.0;

  /// Current fling speed, in levels/second. Only meaningful while
  /// [_isFlinging] is true; decays toward zero via [flingDecayRate].
  double _flingVelocity = 0.0;

  /// Whether momentum scrolling is currently in progress (a finger flick
  /// is still decaying [_cameraProgress] forward).
  bool _isFlinging = false;

  /// Whether [_cameraProgress] is currently easing toward
  /// [_snapTargetProgress] (settling onto a level after a drag/fling ends,
  /// or animating back to the start).
  bool _isSnapping = false;

  /// The level [_cameraProgress] eases toward while [_isSnapping].
  double _snapTargetProgress = minProgress;

  /// 0..1 looping phase for the ambient pulse animation; advances
  /// continuously regardless of scroll state.
  double _pulsePhase = 0.0;

  /// The active level ([pickNearestLevel]) as of the last frame — compared
  /// each frame to detect when the active level changes, which resets
  /// [_hopPhase] to trigger the indicator's hop.
  late int _lastActiveLevel;

  /// 0..1 progress through the active-indicator hop animation; 1.0 means
  /// at rest (no hop in progress). Reset to 0.0 whenever the active level
  /// changes, then advances back to 1.0 over
  /// [activeIndicatorHopDurationSeconds].
  double _hopPhase = 1.0;

  /// Number of times [levelUp] has been called; shown in the app bar.
  int _levelUpCount = 0;

  /// Continuous position along the road, in levels. See [_cameraProgress].
  double get cameraProgress => _cameraProgress;

  /// The single fixed long-distance goal marker, always visible near the
  /// horizon regardless of camera position.
  LongDistanceTargetUiItem get target => MapGenerator.target;

  /// Number of times [levelUp] has been called; shown in the app bar.
  int get levelUpCount => _levelUpCount;

  /// Increments the level-up counter shown, with a flashy pop animation,
  /// in the app bar.
  void levelUp() {
    _levelUpCount++;
    notifyListeners();
  }

  /// The target [cameraXOffset] eases toward: the nearest level's
  /// xOffset, snapped rather than interpolated continuously.
  double get _targetXOffset => MapGenerator.waveXOffsetForPosition(_cameraProgress.roundToDouble());

  /// The camera's current horizontal offset (same units as
  /// [LevelUiItem.xOffset]). Eases smoothly toward [_targetXOffset] every
  /// frame instead of teleporting to it, so crossing a level boundary
  /// glides rather than jumps.
  double get cameraXOffset => _cameraXOffset;

  /// 0..1 looping phase for the ambient pulse animation. See [_pulsePhase].
  double get pulsePhase => _pulsePhase;

  /// Whether momentum scrolling is currently in progress. See
  /// [_isFlinging].
  bool get isFlinging => _isFlinging;

  /// Vertical offset for the active-level indicator: 0 at rest (landed on
  /// the item), bouncing up and back down whenever the active level changes.
  double get activeIndicatorBounce => _hopPhase >= 1.0 ? 0.0 : -activeIndicatorHopHeight * sin(_hopPhase * pi);

  /// Levels within [behindWindow]/[aheadWindow] of [cameraProgress].
  /// Levels are infinite, so this window is generated on demand rather
  /// than sliced from a pre-built list.
  List<LevelUiItem> get visibleLevels {
    final start = max((_cameraProgress - behindWindow).ceil(), minProgress.toInt());
    final end = (_cameraProgress + aheadWindow).floor();
    return [for (var number = start; number <= end; number++) MapGenerator.levelAt(number)];
  }

  /// Side items whose visibility range overlaps the current
  /// [behindWindow]/[aheadWindow] around [cameraProgress].
  List<SideUiItem> get visibleSideItems => MapGenerator.sideItemsInRange(
    _cameraProgress - behindWindow,
    _cameraProgress + aheadWindow,
  );

  /// The level number closest to the current camera position.
  int pickNearestLevel() => max(_cameraProgress.round(), minProgress.toInt());

  /// Starts an eased animation of cameraProgress toward [progress], rather
  /// than snapping instantly.
  void _startSnapTo(double progress) {
    _isFlinging = false;
    _flingVelocity = 0.0;
    _isSnapping = true;
    _snapTargetProgress = progress;
  }

  /// Brings the nearest level to front.
  void _bringNearestLevelToFront() => _startSnapTo(pickNearestLevel().toDouble());

  /// Animates the camera back to the very first level.
  void returnToStart() => _startSnapTo(minProgress);

  /// Call when a vertical drag begins: cancels any in-progress fling or
  /// snap so the finger takes over immediately.
  void onDragStart() {
    _isFlinging = false;
    _flingVelocity = 0.0;
    _isSnapping = false;
  }

  /// Call on every vertical drag movement, with the frame's raw pixel
  /// delta ([dyPixels], positive = finger moving down). Moves
  /// [cameraProgress] directly (no easing) and clamps it to
  /// [minProgress]/[maxProgress].
  void onDragUpdate(double dyPixels) {
    _isFlinging = false;
    _flingVelocity = 0.0;
    _isSnapping = false;
    _cameraProgress = (_cameraProgress - dyPixels / pixelsPerLevel).clamp(minProgress, maxProgress);
    notifyListeners();
  }

  /// Call when a vertical drag ends, with the gesture's release velocity
  /// in pixels/second. Starts a fling if fast enough, otherwise snaps
  /// straight to the nearest level.
  void onDragEnd(double primaryVelocityPixelsPerSecond) {
    final levelsPerSecond = -primaryVelocityPixelsPerSecond / pixelsPerLevel;
    if (levelsPerSecond.abs() < flingStopThreshold) {
      _bringNearestLevelToFront();
      return;
    }
    _flingVelocity = levelsPerSecond;
    _isFlinging = true;
  }

  /// Call once per rendered frame, with the elapsed time since the last
  /// call. Advances every time-driven piece of state: the ambient pulse,
  /// the camera-offset ease, the active-indicator hop, and whichever of
  /// fling decay or snap-easing is currently active.
  void onFrame(Duration elapsed) {
    final dt = elapsed.inMicroseconds / 1e6;
    _pulsePhase = (_pulsePhase + dt / pulsePeriodSeconds) % 1.0;

    final smoothing = 1.0 - exp(-cameraXOffsetSmoothingRate * dt);
    _cameraXOffset += (_targetXOffset - _cameraXOffset) * smoothing;

    final nearest = pickNearestLevel();
    if (nearest != _lastActiveLevel) {
      _lastActiveLevel = nearest;
      _hopPhase = 0.0;
    }
    if (_hopPhase < 1.0) {
      _hopPhase = (_hopPhase + dt / activeIndicatorHopDurationSeconds).clamp(0.0, 1.0);
    }

    if (_isFlinging) {
      _flingVelocity *= exp(-flingDecayRate * dt);
      final next = _cameraProgress + _flingVelocity * dt;
      final hitBound = next <= minProgress || next >= maxProgress;
      _cameraProgress = hitBound ? next.clamp(minProgress, maxProgress) : next;

      if (hitBound || _flingVelocity.abs() < flingStopThreshold) {
        _isFlinging = false;
        _flingVelocity = 0.0;
        _bringNearestLevelToFront();
      }
    } else if (_isSnapping) {
      final diff = _snapTargetProgress - _cameraProgress;
      final snapSmoothing = 1.0 - exp(-progressSnapRate * dt);
      _cameraProgress += diff * snapSmoothing;
      if (diff.abs() < progressSnapStopThreshold) {
        _cameraProgress = _snapTargetProgress;
        _isSnapping = false;
      }
    }

    notifyListeners();
  }
}
