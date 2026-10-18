import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import '../../core/theme/app_theme.dart';
import '../feedback.dart';

// Use the non-deprecated API for announcements
void _announce(String message, TextDirection direction) {
  try {
    SemanticsService.announce(message, direction);
  } catch (e) {
    // Fallback for older Flutter versions
    // Remove print to improve performance
  }
}

class ScreenScaffold extends StatefulWidget {
  const ScreenScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.bottom,
    this.subtitle,
    this.spokenIntro,
    this.topExtras = const [],
  });
  final String title;
  final String? subtitle;
  final String? spokenIntro; // spoken on open and on "Speak this screen"
  final List<Widget> topExtras; // read-only chips only
  final List<Widget> body;
  final Widget bottom; // BottomActionBar or custom action column

  @override
  State<ScreenScaffold> createState() => _ScreenScaffoldState();
}

class _ScreenScaffoldState extends State<ScreenScaffold> {
  String get _intro => widget.spokenIntro ?? widget.title;
  Timer? _speakTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _announce(widget.title, Directionality.of(context));
      // Delay TTS slightly to avoid blocking UI
      _speakTimer = Timer(const Duration(milliseconds: 100), () {
        if (mounted) Fx.speak?.call(_intro);
      });
    });
  }

  @override
  void dispose() {
    _speakTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WC.bg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 16, 12),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: WC.line, width: 1))),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(header: true, child: Text(widget.title, style: WT.title)),
                        if (widget.subtitle != null) Text(widget.subtitle!, style: WT.label),
                        if (widget.topExtras.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Wrap(spacing: 8, runSpacing: 8, children: widget.topExtras),
                          ),
                      ],
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Speak this screen',
                    excludeSemantics: true,
                    onTap: () {
                      Fx.haptic(Sig.tick);
                      Fx.speak?.call(_intro);
                    },
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        Fx.haptic(Sig.tick);
                        Fx.speak?.call(_intro);
                      },
                      child: const SizedBox(
                        width: 64,
                        height: 64,
                        child: Icon(Icons.volume_up_rounded, color: WC.accent, size: 34),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (int i = 0; i < widget.body.length; i++) ...[
                      widget.body[i],
                      if (i != widget.body.length - 1) const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              decoration: const BoxDecoration(
                color: WC.surface,
                border: Border(top: BorderSide(color: WC.line, width: 2)),
              ),
              child: widget.bottom,
            ),
          ],
        ),
      ),
    );
  }
}
