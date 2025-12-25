import 'package:flutter/material.dart';
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
                _SectionHeader(title: '外觀'),
                Card(
                  child: Column(
                    children: ThemeMode.values
                        .map(
                          (mode) => RadioListTile<ThemeMode>(
                            value: mode,
                            groupValue: settings.themeMode,
                            onChanged: (value) {
                              if (value != null) {
                                context.read<SettingsCubit>().toggleTheme(
                                  value,
                                );
                              }
                            },
                            title: Text(_themeModeLabel(mode)),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 24),
                _SectionHeader(title: '活動'),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.abc),
                        title: const Text('預設活動名稱'),
                        subtitle: Text(settings.defaultActivityNameFormat),
                        trailing: const Icon(Icons.edit_outlined),
                        onTap: () => _editDefaultName(
                          context,
                          settings.defaultActivityNameFormat,
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.folder_outlined),
                        title: const Text('儲存路徑'),
                        subtitle: Text(settings.storagePath),
                        trailing: const Icon(Icons.edit_location_alt_outlined),
                        onTap: () =>
                            _changeStoragePath(context, settings.storagePath),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _SectionHeader(title: '關於'),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(Icons.info_outline),
                        title: Text('Event Album'),
                        subtitle: Text('版本 ${settings.version}'),
                      ),
                      // ListTile(
                      //   leading: Icon(Icons.code_outlined),
                      //   title: Text('開發'),
                      //   subtitle: Text('OpenAI Codex · Flutter'),
                      // ),
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
        return '淺色模式';
      case ThemeMode.dark:
        return '深色模式';
      case ThemeMode.system:
        return '跟隨系統';
    }
  }

  Future<void> _editDefaultName(BuildContext context, String current) async {
    final controller = TextEditingController(text: current);
    final cubit = context.read<SettingsCubit>();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('預設活動名稱'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('可使用 {date} 插入今日日期。'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '名稱格式',
                  helperText: '例如：Event {date}',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('儲存'),
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
          title: const Text('變更儲存路徑'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '資料夾路徑',
              helperText: '請輸入有效的本機路徑',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('儲存'),
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
