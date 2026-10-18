import 'package:flutter/material.dart';
import '../widgets/bottom_action_bar.dart';
import '../widgets/chips_cards_rows.dart';
import '../widgets/screen_scaffold.dart';
import '../feedback.dart';

class ChooseDestinationScreen extends StatefulWidget {
  const ChooseDestinationScreen({super.key});

  @override
  State<ChooseDestinationScreen> createState() => _ChooseDestinationScreenState();
}

class _ChooseDestinationScreenState extends State<ChooseDestinationScreen> {
  String _selectedDestination = 'Room 101';

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Choose Destination',
      spokenIntro: 'Choose your destination. Select a place and tap Start Guiding.',
      body: [
        SelectableRow(
          label: 'Room 101',
          sub: 'About 12 steps',
          selected: _selectedDestination == 'Room 101',
          onTap: () {
            setState(() {
              _selectedDestination = 'Room 101';
            });
            Fx.speak?.call('Room 101 selected. About 12 steps.');
          },
        ),
        SelectableRow(
          label: 'Washroom',
          sub: 'About 45 steps',
          selected: _selectedDestination == 'Washroom',
          onTap: () {
            setState(() {
              _selectedDestination = 'Washroom';
            });
            Fx.speak?.call('Washroom selected. About 45 steps.');
          },
        ),
        SelectableRow(
          label: 'Lift',
          sub: 'About 20 steps',
          selected: _selectedDestination == 'Lift',
          onTap: () {
            setState(() {
              _selectedDestination = 'Lift';
            });
            Fx.speak?.call('Lift selected. About 20 steps.');
          },
        ),
        SelectableRow(
          label: 'Exit',
          sub: 'About 60 steps',
          selected: _selectedDestination == 'Exit',
          onTap: () {
            setState(() {
              _selectedDestination = 'Exit';
            });
            Fx.speak?.call('Exit selected. About 60 steps.');
          },
        ),
        SelectableRow(
          label: 'Entrance',
          sub: 'About 55 steps',
          selected: _selectedDestination == 'Entrance',
          onTap: () {
            setState(() {
              _selectedDestination = 'Entrance';
            });
            Fx.speak?.call('Entrance selected. About 55 steps.');
          },
        ),
      ],
      bottom: BottomActionBar(
        onBack: () => Navigator.pop(context),
        primaryLabel: 'Start Guiding',
        onPrimary: () {
          Fx.haptic(Sig.primary);
          Fx.speak?.call('Starting navigation to $_selectedDestination');
          Navigator.pushNamed(context, '/guiding');
        },
      ),
    );
  }
}
