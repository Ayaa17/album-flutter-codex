import 'package:flutter/material.dart';

import '../../data/models/target_face.dart';

class ActivitySetup {
  const ActivitySetup({required this.name, required this.targetFaceType});

  final String name;
  final TargetFaceType targetFaceType;
}

Future<ActivitySetup?> showActivitySetupDialog(
  BuildContext context, {
  required String defaultName,
  String title = 'New activity',
  String confirmLabel = 'Create',
  bool autofocusName = true,
}) {
  final controller = TextEditingController(text: defaultName);
  TargetFaceType selected = TargetFaceType.fullTenRing;

  return showDialog<ActivitySetup>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          final bottomInset = MediaQuery.of(dialogContext).viewInsets.bottom;
          return AlertDialog(
            title: Text(title),
            contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            content: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: autofocusName,
                    decoration: const InputDecoration(
                      labelText: 'Activity name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Target face',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  RadioGroup<TargetFaceType>(
                    groupValue: selected,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => selected = value);
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: TargetFaceType.values
                          .map(
                            (type) => RadioListTile<TargetFaceType>(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              value: type,
                              title: Text(type.label),
                              subtitle: Text(type.description),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final trimmed = controller.text.trim();
                  final name = trimmed.isEmpty ? defaultName : trimmed;
                  if (name.isEmpty) {
                    Navigator.of(dialogContext).pop();
                    return;
                  }
                  Navigator.of(
                    dialogContext,
                  ).pop(ActivitySetup(name: name, targetFaceType: selected));
                },
                child: Text(confirmLabel),
              ),
            ],
          );
        },
      );
    },
  );
}
