import 'package:flutter/material.dart';

import 'road_scroll/road_scroll_widget.dart';

void main() => runApp(const RoadScrollApp());

class RoadScrollApp extends StatelessWidget {
  const RoadScrollApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RoadScrollWidget(),
    );
  }
}
