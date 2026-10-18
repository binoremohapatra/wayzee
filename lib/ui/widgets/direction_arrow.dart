import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum Direction {
  left,
  right,
  straight,
  stairs,
  stop,
}

class DirectionArrow extends StatelessWidget {
  final Direction direction;
  final double size;

  const DirectionArrow({
    super.key,
    required this.direction,
    this.size = 120,
  });

  @override
  Widget build(BuildContext context) {
    IconData iconData;
    Color color;

    switch (direction) {
      case Direction.left:
        iconData = Icons.arrow_back_ios_new;
        color = AppColors.text;
        break;
      case Direction.right:
        iconData = Icons.arrow_forward_ios;
        color = AppColors.text;
        break;
      case Direction.straight:
        iconData = Icons.arrow_upward;
        color = AppColors.text;
        break;
      case Direction.stairs:
        iconData = Icons.stairs;
        color = AppColors.warn;
        break;
      case Direction.stop:
        iconData = Icons.do_not_step;
        color = AppColors.bad;
        break;
    }

    return Semantics(
      label: _getDirectionLabel(direction),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.card,
          shape: BoxShape.circle,
          border: Border.all(
            color: color,
            width: 3,
          ),
        ),
        child: Icon(
          iconData,
          size: size * 0.5,
          color: color,
        ),
      ),
    );
  }

  String _getDirectionLabel(Direction direction) {
    switch (direction) {
      case Direction.left:
        return 'Turn left';
      case Direction.right:
        return 'Turn right';
      case Direction.straight:
        return 'Go straight';
      case Direction.stairs:
        return 'Stairs ahead';
      case Direction.stop:
        return 'Stop';
    }
  }
}
