import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'engine/painter.dart';
import 'views/road_scroll_app_bar.dart';
import 'road_scroll_viewmodel.dart';

class RoadScrollWidget extends StatefulWidget {
  const RoadScrollWidget({super.key});

  @override
  State<RoadScrollWidget> createState() => _RoadScrollWidgetState();
}

class _RoadScrollWidgetState extends State<RoadScrollWidget> with SingleTickerProviderStateMixin {
  late final RoadScrollViewModel _viewModel;
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _viewModel = RoadScrollViewModel();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final delta = elapsed - _lastElapsed;
    _lastElapsed = elapsed;
    _viewModel.onFrame(delta);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: RoadScrollAppBar(viewModel: _viewModel),
      body: Stack(
        children: [
          GestureDetector(
            onVerticalDragStart: (_) => _viewModel.onDragStart(),
            onVerticalDragUpdate: (details) => _viewModel.onDragUpdate(details.delta.dy),
            onVerticalDragEnd: (details) => _viewModel.onDragEnd(details.primaryVelocity ?? 0.0),
            child: ListenableBuilder(
              listenable: _viewModel,
              builder: (context, _) => CustomPaint(
                size: Size.infinite,
                painter: Road3DPainter(
                  levels: _viewModel.visibleLevels,
                  sideItems: _viewModel.visibleSideItems,
                  target: _viewModel.target,
                  cameraProgress: _viewModel.cameraProgress,
                  cameraXOffset: _viewModel.cameraXOffset,
                  pulsePhase: _viewModel.pulsePhase,
                  activeIndicatorBounce: _viewModel.activeIndicatorBounce,
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            bottom: 16 + MediaQuery.paddingOf(context).bottom,
            child: FloatingActionButton(
              heroTag: null,
              onPressed: _viewModel.returnToStart,
              child: const Icon(Icons.home),
            ),
          ),
        ],
      ),
    );
  }
}
