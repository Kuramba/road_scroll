import 'package:flutter/material.dart';

import '../road_scroll_viewmodel.dart';

/// The app bar for [RoadScrollWidget]: a flashy level-up counter on the
/// left and a "Level Up" button on the right. Pressing the button spawns
/// a huge number at screen center that flies to the counter and lands.
class RoadScrollAppBar extends StatefulWidget implements PreferredSizeWidget {
  const RoadScrollAppBar({super.key, required this.viewModel});

  final RoadScrollViewModel viewModel;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  State<RoadScrollAppBar> createState() => _RoadScrollAppBarState();
}

class _RoadScrollAppBarState extends State<RoadScrollAppBar> {
  final GlobalKey _counterKey = GlobalKey();

  void _onLevelUpPressed() {
    final overlay = Overlay.of(context);
    final screenSize = MediaQuery.sizeOf(context);
    final start = Offset(screenSize.width / 2, screenSize.height / 2);

    final counterBox = _counterKey.currentContext?.findRenderObject() as RenderBox?;
    final end = counterBox != null ? counterBox.localToGlobal(counterBox.size.center(Offset.zero)) : const Offset(40, 40);

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _FlyingLevelUpNumber(
        start: start,
        end: end,
        text: '+1',
        onDone: () {
          entry.remove();
          widget.viewModel.levelUp();
        },
      ),
    );
    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) => _FlashyCounter(key: _counterKey, count: widget.viewModel.levelUpCount),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ElevatedButton.icon(
            onPressed: _onLevelUpPressed,
            icon: const Icon(Icons.arrow_upward),
            label: const Text('Level Up'),
          ),
        ),
      ],
    );
  }
}

/// A number that pops in with a flashy scale+fade whenever it changes,
/// then stays put — used for the level-up counter in the app bar.
class _FlashyCounter extends StatelessWidget {
  const _FlashyCounter({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        const Icon(Icons.star, color: Colors.amber),
        const SizedBox(width: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          transitionBuilder: (child, animation) => ScaleTransition(
            scale: Tween<double>(begin: 1.8, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.elasticOut),
            ),
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: Text(
            '$count',
            key: ValueKey(count),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.amber),
          ),
        ),
      ],
    );
  }
}

/// A huge number that appears at [start] (screen center) and animates,
/// shrinking, to [end] (the app bar counter's position), then calls
/// [onDone] so the caller can remove this overlay entry and apply the
/// actual counter update it was "delivering".
class _FlyingLevelUpNumber extends StatefulWidget {
  const _FlyingLevelUpNumber({required this.start, required this.end, required this.text, required this.onDone});

  final Offset start;
  final Offset end;
  final String text;
  final VoidCallback onDone;

  @override
  State<_FlyingLevelUpNumber> createState() => _FlyingLevelUpNumberState();
}

class _FlyingLevelUpNumberState extends State<_FlyingLevelUpNumber> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeInOutCubic.transform(_controller.value);
        final position = Offset.lerp(widget.start, widget.end, t)!;
        final fontSize = 120.0 + (20.0 - 120.0) * t;
        final opacity = _controller.value < 0.85 ? 1.0 : (1.0 - (_controller.value - 0.85) / 0.15).clamp(0.0, 1.0);
        return Positioned(
          left: position.dx,
          top: position.dy,
          child: FractionalTranslation(
            translation: const Offset(-0.5, -0.5),
            child: Opacity(
              opacity: opacity,
              child: Text(
                widget.text,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                  shadows: const [Shadow(blurRadius: 8, color: Colors.black26)],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
