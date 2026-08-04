import 'level_ui_item.dart';
import 'long_distance_target_ui_item.dart';
import 'side_ui_item.dart';

class RoadMap {
  final List<LevelUiItem> levels;
  final List<SideUiItem> sideItems;
  final LongDistanceTargetUiItem target;

  const RoadMap({
    required this.levels,
    required this.sideItems,
    required this.target,
  });
}
