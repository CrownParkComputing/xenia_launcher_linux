import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/config.dart';

class CardSizeSettings extends StatelessWidget {
  const CardSizeSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Game Card Size',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SegmentedButton<GameCardSize>(
              segments: const [
                ButtonSegment<GameCardSize>(
                  value: GameCardSize.small,
                  label: Text('Small'),
                ),
                ButtonSegment<GameCardSize>(
                  value: GameCardSize.medium,
                  label: Text('Medium'),
                ),
                ButtonSegment<GameCardSize>(
                  value: GameCardSize.large,
                  label: Text('Large'),
                ),
              ],
              selected: {settingsProvider.config.cardSize},
              onSelectionChanged: (Set<GameCardSize> selection) {
                settingsProvider.setCardSize(selection.first);
              },
            ),
          ],
        ),
      ),
    );
  }
}
