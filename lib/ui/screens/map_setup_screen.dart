import 'package:flutter/material.dart';
import '../../core/theme/accessible_colors.dart';
import '../../data/storage/map_database.dart';
import '../../domain/navigation/navigation_graph.dart';
import '../widgets/accessible_scaffold.dart';
import '../widgets/accessible_tactile_button.dart';

class MapSetupScreen extends StatefulWidget {
  final MapDatabase mapDatabase;

  const MapSetupScreen({super.key, required this.mapDatabase});

  @override
  State<MapSetupScreen> createState() => _MapSetupScreenState();
}

class _MapSetupScreenState extends State<MapSetupScreen> {
  List<NavNode> _nodes = [];
  bool _isHealthy = true;
  String _statusMessage = 'Loading indoor map...';

  @override
  void initState() {
    super.initState();
    _loadMap();
  }

  Future<void> _loadMap() async {
    final nodes = await widget.mapDatabase.getAllNodes();
    final healthy = await widget.mapDatabase.validateGraphIntegrity();
    setState(() {
      _nodes = nodes;
      _isHealthy = healthy;
      _statusMessage = 'Map contains ${nodes.length} rooms/landmarks. Graph integrity: ${healthy ? "Valid" : "Corrupt"}';
    });
  }

  Future<void> _promptAddLandmark() async {
    final nameController = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AccessibleColors.surface,
        title: const Text('Mark New Landmark', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: nameController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'e.g. Kitchen entrance',
            hintStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = nameController.text.trim();
              if (text.isNotEmpty && _nodes.isNotEmpty) {
                await widget.mapDatabase.markLandmarkHere(
                  landmarkName: text,
                  previousNodeId: _nodes.first.id,
                  distanceMeters: 5.0,
                  relativeBearingDegrees: 0.0,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                await _loadMap();
              }
            },
            child: const Text('Save Landmark'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AccessibleScaffold(
      screenTitle: 'Indoor Map Setup',
      spokenScreenTitle: 'Indoor map setup. Configure rooms and landmarks for navigation.',
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: AccessibleColors.surface,
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(
                  color: _isHealthy ? AccessibleColors.tactileAccent : AccessibleColors.danger,
                  width: 2.0,
                ),
              ),
              child: Text(
                _statusMessage,
                style: const TextStyle(color: Colors.white, fontSize: 16.0),
              ),
            ),
            const SizedBox(height: 16.0),
            AccessibleTactileButton(
              label: 'Mark Landmark Here',
              icon: Icons.add_location_alt_rounded,
              onPressed: _promptAddLandmark,
            ),
            const SizedBox(height: 16.0),
            const Text(
              'SAVED ROOMS & LANDMARKS',
              style: TextStyle(
                color: AccessibleColors.textSecondary,
                fontSize: 14.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8.0),
            ..._nodes.map(
              (n) => Container(
                margin: const EdgeInsets.symmetric(vertical: 4.0),
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: AccessibleColors.surface,
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.place_rounded, color: AccessibleColors.tactileAccent),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: Text(
                        '${n.name} (${n.type.name})',
                        style: const TextStyle(color: Colors.white, fontSize: 18.0),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24.0),
            AccessibleTactileButton(
              label: 'Backup Map (Export JSON)',
              icon: Icons.cloud_download_rounded,
              onPressed: () async {
                final jsonStr = await widget.mapDatabase.exportToJson();
                await widget.mapDatabase.saveMapWithBackupAndAtomicWrite(jsonStr);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Map exported & saved atomically')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
