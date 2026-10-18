import 'package:flutter/cupertino.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Guide screen',
      child: CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          backgroundColor: AppColors.background,
          border: null,
          middle: Text(
            'Guide',
            style: AppText.headline,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.location_solid,
                    size: 80,
                    color: AppColors.muted,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Not guiding',
                    style: AppText.body,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Start guiding from the Home screen',
                    style: AppText.caption,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
