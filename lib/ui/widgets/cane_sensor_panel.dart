import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../safety/cane_sensor.dart';

class CaneSensorPanel extends StatelessWidget {
  final CaneSensorData data;
  final ValueChanged<double>? onDistanceChanged;
  final ValueChanged<bool>? onStairsChanged;
  final ValueChanged<bool>? onDropOffChanged;
  final VoidCallback? onReset;

  const CaneSensorPanel({
    super.key,
    required this.data,
    this.onDistanceChanged,
    this.onStairsChanged,
    this.onDropOffChanged,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.line, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Simulated Cane Sensor',
                style: AppText.bodyBold,
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: onReset,
                child: Text(
                  'Reset',
                  style: AppText.caption.copyWith(
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Distance: ${data.distanceCm.round()} cm',
            style: AppText.caption,
          ),
          const SizedBox(height: 8),
          Material(
            color: Colors.transparent,
            child: Slider(
              value: data.distanceCm,
              min: 0,
              max: 300,
              divisions: 30,
              activeColor: data.isDanger ? AppColors.bad : AppColors.accent,
              onChanged: onDistanceChanged,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildToggle(
                  label: 'Stairs ahead',
                  value: data.stairsAhead,
                  onChanged: onStairsChanged,
                  isDanger: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildToggle(
                  label: 'Drop-off ahead',
                  value: data.dropOffAhead,
                  onChanged: onDropOffChanged,
                  isDanger: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (data.isDanger)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bad.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.bad, width: 1),
              ),
              child: Text(
                '⚠️ Danger detected',
                style: AppText.captionBold.copyWith(
                  color: AppColors.bad,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToggle({
    required String label,
    required bool value,
    required ValueChanged<bool>? onChanged,
    required bool isDanger,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppText.caption,
          ),
        ),
        CupertinoSwitch(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
