import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit/core/labels.dart';
import 'package:orbit/core/network/api_client.dart';
import 'package:orbit/features/discovery/domain/profile.dart';
import 'package:orbit/features/media/data/media_repository.dart';
import 'package:orbit/features/profile/data/account_repository.dart';
import 'package:orbit/features/profile/domain/my_profile.dart';
import 'package:orbit/features/profile/presentation/my_profile_controller.dart';
import 'package:orbit/features/profile/presentation/photo_editor.dart';
import 'package:orbit/l10n/app_localizations.dart';

/// W14: edit the member's own profile.
class EditProfileScreen extends ConsumerStatefulWidget {
  /// Creates the edit screen.
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final MyProfile _original = ref.read(myProfileProvider)!;
  late final _name = TextEditingController(text: _original.displayName);
  late final _bio = TextEditingController(text: _original.bio);
  late final _pronouns = TextEditingController(text: _original.pronouns);
  late final _height = TextEditingController(
    text: _original.heightCm?.toString() ?? '',
  );
  late final _tags = TextEditingController(text: _original.tags.join(', '));
  late Set<LookingFor> _lookingFor = {..._original.lookingFor};
  late bool _showAge = _original.showAge;
  late bool _showDistance = _original.showDistance;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _bio, _pronouns, _height, _tags]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !(_form.currentState?.validate() ?? false)) return;
    final height = int.tryParse(_height.text.trim());
    final tags = [
      for (final t in _tags.text.split(','))
        if (t.trim().replaceAll('#', '').isNotEmpty)
          t.trim().replaceAll('#', ''),
    ];
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => _saving = true);
    final MyProfile saved;
    try {
      saved = await ref
          .read(accountRepositoryProvider)
          .saveProfile(
            _original.copyWith(
              displayName: _name.text.trim(),
              bio: _bio.text.trim(),
              pronouns: _pronouns.text.trim(),
              heightCm: height,
              clearHeight: height == null,
              lookingFor: _lookingFor,
              tags: tags,
              showAge: _showAge,
              showDistance: _showDistance,
            ),
          );
    } on ApiException {
      messenger.showSnackBar(SnackBar(content: Text(l10n.actionFailed)));
      if (mounted) setState(() => _saving = false);
      return;
    }
    ref.read(myProfileProvider.notifier).save(saved);
    messenger.showSnackBar(SnackBar(content: Text(l10n.profileSaved)));
    router.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.editProfileTitle),
        actions: [TextButton(onPressed: _save, child: Text(l10n.save))],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (ref.watch(mediaRepositoryProvider) != null)
              const PhotoEditor()
            else
              Text(
                l10n.photoLaterNote,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              maxLength: 30,
              decoration: InputDecoration(labelText: l10n.displayNameLabel),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? l10n.displayNameRequired : null,
            ),
            TextFormField(
              controller: _bio,
              maxLength: 280,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n.aboutLabel,
                hintText: l10n.aboutHint,
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _pronouns,
                    maxLength: 20,
                    decoration: InputDecoration(labelText: l10n.pronounsLabel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _height,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: l10n.heightLabel),
                    validator: (v) {
                      final text = (v ?? '').trim();
                      if (text.isEmpty) return null;
                      final cm = int.tryParse(text);
                      return cm == null || cm < 120 || cm > 230
                          ? l10n.heightInvalid
                          : null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(l10n.lookingForLabel, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final goal in LookingFor.values)
                  FilterChip(
                    label: Text(l10n.lookingFor(goal)),
                    selected: _lookingFor.contains(goal),
                    onSelected: (selected) => setState(
                      () => _lookingFor = selected
                          ? {..._lookingFor, goal}
                          : ({..._lookingFor}..remove(goal)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _tags,
              decoration: InputDecoration(
                labelText: l10n.tagsLabel,
                hintText: l10n.tagsHint,
              ),
            ),
            const SizedBox(height: 16),
            Text(l10n.showOnProfile, style: theme.textTheme.titleSmall),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.showAge),
              value: _showAge,
              onChanged: (v) => setState(() => _showAge = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.showDistance),
              value: _showDistance,
              onChanged: (v) => setState(() => _showDistance = v),
            ),
          ],
        ),
      ),
    );
  }
}
