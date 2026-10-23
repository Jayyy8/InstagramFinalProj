import "package:adaptive_platform_ui/adaptive_platform_ui.dart";
import "package:flutter/cupertino.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:image_picker/image_picker.dart";

import "../providers/social_providers.dart";
import "../theme/app_theme.dart";
import "../widgets/dialogs.dart";
import "../widgets/gradient_avatar.dart";
import "../widgets/sub_page.dart";

/// Edit profile: photo, name, username, bio.
class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _username = TextEditingController();
  final TextEditingController _bio = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _loaded = false;
  bool _saving = false;
  bool _uploading = false;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _changePhoto() async {
    Future<void> pick(ImageSource source) async {
      try {
        final photo = await _picker.pickImage(
          source: source,
          imageQuality: 85,
          maxWidth: 800,
        );
        if (photo == null) return;
        setState(() => _uploading = true);
        await ref.read(myProfileProvider.notifier).setAvatar(photo);
        if (mounted) showToast(context, "Profile photo updated");
      } catch (e) {
        if (mounted) showToast(context, errorText(e), error: true);
      } finally {
        if (mounted) setState(() => _uploading = false);
      }
    }

    showActionSheet(
      context,
      title: "Change profile picture",
      actions: [
        SheetAction(
          label: "Choose from library",
          icon: CupertinoIcons.photo,
          onTap: () => pick(ImageSource.gallery),
        ),
        SheetAction(
          label: "Take photo",
          icon: CupertinoIcons.camera,
          onTap: () => pick(ImageSource.camera),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final username = _username.text.trim().toLowerCase();
    if (!RegExp(r"^[a-z0-9._]{3,30}$").hasMatch(username)) {
      showInfo(
        context,
        title: "Invalid username",
        message:
            "Usernames are 3-30 characters and can only use letters, numbers, periods and underscores.",
      );
      return;
    }
    if (_bio.text.length > 150) {
      showInfo(
        context,
        title: "Bio too long",
        message: "Use 150 characters or fewer.",
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(myProfileProvider.notifier)
          .save(username: username, fullName: _name.text, bio: _bio.text);
      if (mounted) {
        showToast(context, "Profile saved");
        Navigator.of(context).pop();
      }
    } catch (e) {
      final text = errorText(e);
      if (mounted) {
        showInfo(
          context,
          title: "Couldn't save",
          message: text.contains("duplicate") || text.contains("unique")
              ? "The username $username is already taken."
              : text,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final profile = ref.watch(myProfileProvider).valueOrNull;

    if (profile != null && !_loaded) {
      _loaded = true;
      _name.text = profile.fullName;
      _username.text = profile.username;
      _bio.text = profile.bio;
    }

    Widget field(String label, TextEditingController c, {int maxLines = 1}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 13, color: colors.secondaryText),
            ),
            const SizedBox(height: 6),
            AdaptiveTextField(
              controller: c,
              maxLines: maxLines,
              minLines: 1,
              autocorrect: false,
              style: TextStyle(color: colors.text, fontSize: 15),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              cupertinoDecoration: BoxDecoration(
                border: Border.all(color: colors.separator),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
      );
    }

    return SubPage(
      title: "Edit profile",
      actions: [
        AdaptiveAppBarAction(
          title: _saving ? "Saving..." : "Done",
          onPressed: _saving ? () {} : _save,
        ),
      ],
      child: profile == null
          ? const Center(child: CupertinoActivityIndicator())
          : GestureDetector(
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              behavior: HitTestBehavior.translucent,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: _uploading ? null : _changePhoto,
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              GradientAvatar(
                                name: profile.username,
                                imageUrls: profile.avatarUrls,
                                size: 90,
                                ring: false,
                              ),
                              if (_uploading)
                                const CupertinoActivityIndicator(radius: 14),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "Edit picture",
                            style: TextStyle(
                              color: kIgBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  field("Name", _name),
                  field("Username", _username),
                  field("Bio", _bio, maxLines: 4),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: AdaptiveButton(
                      label: _saving ? "Saving..." : "Save",
                      enabled: !_saving,
                      color: kIgBlue,
                      size: AdaptiveButtonSize.large,
                      minSize: const Size(double.infinity, 46),
                      onPressed: _save,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
