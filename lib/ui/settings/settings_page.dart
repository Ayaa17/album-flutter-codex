import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/settings/settings_cubit.dart';
import '../../blocs/settings/settings_state.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocConsumer<SettingsCubit, SettingsState>(
          listenWhen: (previous, current) =>
              previous.message != current.message,
          listener: (context, state) {
            final message = state.message;
            if (message != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(message),
                  duration: const Duration(milliseconds: 300),
                ),
              );
            }
          },
          builder: (context, state) {
            final settings = state.settings;
            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              children: [
                _SectionHeader(title: 'Appearance'),
                Card(
                  child: RadioGroup<ThemeMode>(
                    groupValue: settings.themeMode,
                    onChanged: (value) {
                      if (value != null) {
                        context.read<SettingsCubit>().toggleTheme(value);
                      }
                    },
                    child: Column(
                      children: ThemeMode.values
                          .map(
                            (mode) => RadioListTile<ThemeMode>(
                              value: mode,
                              title: Text(_themeModeLabel(mode)),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _SectionHeader(title: 'Defaults'),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.abc),
                        title: const Text('Default activity name'),
                        subtitle: Text(settings.defaultActivityNameFormat),
                        trailing: const Icon(Icons.edit_outlined),
                        onTap: () => _editDefaultName(
                          context,
                          settings.defaultActivityNameFormat,
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.straighten_outlined),
                        title: const Text('Default distance'),
                        subtitle: Text('${settings.defaultDistanceMeters} m'),
                        trailing: const Icon(Icons.edit_outlined),
                        onTap: () => _editDefaultDistance(
                          context,
                          settings.defaultDistanceMeters,
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.folder_outlined),
                        title: const Text('Storage path'),
                        subtitle: Text(settings.storagePath),
                        trailing: const Icon(Icons.edit_location_alt_outlined),
                        onTap: () =>
                            _changeStoragePath(context, settings.storagePath),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _SectionHeader(title: 'About'),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: const Text('Event Album'),
                        subtitle: Text('Version ${settings.version}'),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  Future<void> _editDefaultName(BuildContext context, String current) async {
    final controller = TextEditingController(text: current);
    final cubit = context.read<SettingsCubit>();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Default activity name'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Use {date} to include today's date."),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Name format',
                  helperText: 'Example: Event {date}',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (!context.mounted) return;
    if (result != null && result.isNotEmpty) {
      await cubit.updateDefaultNaming(result);
    }
  }

  Future<void> _changeStoragePath(BuildContext context, String current) async {
    final controller = TextEditingController(text: current);
    final cubit = context.read<SettingsCubit>();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Change storage path'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Directory path',
              helperText: 'Enter a writable folder path.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (!context.mounted) return;
    if (result != null && result.isNotEmpty) {
      await cubit.updateStoragePath(result);
    }
  }

  Future<void> _editDefaultDistance(BuildContext context, int current) async {
    final controller = TextEditingController(text: '$current');
    final cubit = context.read<SettingsCubit>();
    final result = await showDialog<int>(
      context: context,
      builder: (context) {
        String? errorText;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Default distance'),
              content: TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Distance',
                  suffixText: 'm',
                  errorText: errorText,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final meters = int.tryParse(controller.text.trim());
                    if (meters == null || meters <= 0) {
                      setState(() => errorText = 'Enter a distance in meters.');
                      return;
                    }
                    Navigator.of(context).pop(meters);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(controller.dispose);
    if (!context.mounted) return;
    if (result != null) {
      await cubit.updateDefaultDistance(result);
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
