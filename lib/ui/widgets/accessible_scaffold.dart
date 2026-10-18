import 'package:flutter/material.dart';
import '../../core/theme/accessible_colors.dart';
import '../../core/accessibility/accessible_semantics.dart';

/// Screen scaffold enforcing true-black background, TalkBack announcements, and focus order.
class AccessibleScaffold extends StatefulWidget {
  final String screenTitle;
  final String? spokenScreenTitle;
  final Widget body;
  final Widget? bottomNavigationBar;
  final bool announceOnEntry;

  const AccessibleScaffold({
    super.key,
    String? screenTitle,
    String? title,
    this.spokenScreenTitle,
    required this.body,
    this.bottomNavigationBar,
    this.announceOnEntry = true,
  }) : screenTitle = screenTitle ?? title ?? 'Wayze';

  @override
  State<AccessibleScaffold> createState() => _AccessibleScaffoldState();
}

class _AccessibleScaffoldState extends State<AccessibleScaffold> {
  @override
  void initState() {
    super.initState();
    if (widget.announceOnEntry) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AccessibleSemantics.announce(widget.screenTitle);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AccessibleColors.background,
      appBar: AppBar(
        backgroundColor: AccessibleColors.background,
        elevation: 0,
        centerTitle: false,
        title: Semantics(
          header: true,
          child: Text(
            widget.screenTitle,
            style: const TextStyle(
              color: AccessibleColors.textPrimary,
              fontSize: 24.0,
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter',
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: widget.body,
        ),
      ),
      bottomNavigationBar: widget.bottomNavigationBar,
    );
  }
}
