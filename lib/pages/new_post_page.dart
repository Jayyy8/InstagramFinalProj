import "dart:io";

import "package:adaptive_platform_ui/adaptive_platform_ui.dart";
import "package:flutter/cupertino.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:image_picker/image_picker.dart";

import "../providers/feed_provider.dart";
import "../theme/app_theme.dart";
import "../widgets/dialogs.dart";
import "../widgets/sub_page.dart";

/// New post: pick up to 10 photos, write a caption, add a location.
/// Photos are uploaded to Supabase Storage.
class NewPostPage extends ConsumerStatefulWidget {
  const NewPostPage({super.key});

  @override
  ConsumerState<NewPostPage> createState() => _NewPostPageState();
}

class _NewPostPageState extends ConsumerState<NewPostPage> {
  final TextEditingController _caption = TextEditingController();
  final TextEditingController _location = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _photos = [];
  int _selected = 0;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    // Open the library right away, like Instagram.
    WidgetsBinding.instance.addPostFrameCallback((_) => _pickFromLibrary());
  }

  @override
  void dispose() {
    _caption.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _pickFromLibrary() async {
    try {
      final picked = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1440,
        limit: 10,
      );
      if (picked.isEmpty || !mounted) return;
      setState(() {
        _photos
          ..clear()
          ..addAll(picked.take(10));
        _selected = 0;
      });
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    }
  }

  Future<void> _takePhoto() async {
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1440,
      );
      if (photo == null || !mounted) return;
      setState(() {
        if (_photos.length < 10) _photos.add(photo);
        _selected = _photos.length - 1;
      });
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    }
  }

  Future<void> _share() async {
    if (_photos.isEmpty || _sharing) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _sharing = true);
    try {
      await ref
          .read(postActionsProvider)
          .create(
            photos: List.of(_photos),
            caption: _caption.text,
            location: _location.text,
          );
      if (!mounted) return;
      showToast(context, "Your post has been shared");
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _sharing = false);
      showInfo(context, title: "Couldn't share post", message: errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return SubPage(
      title: "New post",
      actions: [
        AdaptiveAppBarAction(
          title: _sharing ? "Sharing..." : "Share",
          onPressed: _photos.isEmpty || _sharing ? () {} : _share,
        ),
      ],
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            behavior: HitTestBehavior.translucent,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 40),
              children: [
                // Selected photo.
                AspectRatio(
                  aspectRatio: 4 / 5,
                  child: _photos.isEmpty
                      ? GestureDetector(
                          onTap: _pickFromLibrary,
                          child: ColoredBox(
                            color: colors.placeholder,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  CupertinoIcons.photo_on_rectangle,
                                  size: 64,
                                  color: colors.secondaryText,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  "Select photos",
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: colors.text,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Image.file(
                          File(_photos[_selected].path),
                          fit: BoxFit.cover,
                        ),
                ),

                // Thumbnails + buttons.
                SizedBox(
                  height: 86,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(10),
                    children: [
                      for (int i = 0; i < _photos.length; i++)
                        GestureDetector(
                          onTap: () => setState(() => _selected = i),
                          onLongPress: () => setState(() {
                            _photos.removeAt(i);
                            _selected = 0;
                          }),
                          child: Container(
                            width: 66,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: i == _selected
                                    ? kIgBlue
                                    : const Color(0x00000000),
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.file(
                                File(_photos[i].path),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      _SquareButton(
                        icon: CupertinoIcons.photo_on_rectangle,
                        label: "Library",
                        onTap: _pickFromLibrary,
                      ),
                      _SquareButton(
                        icon: CupertinoIcons.camera,
                        label: "Camera",
                        onTap: _takePhoto,
                      ),
                    ],
                  ),
                ),
                if (_photos.length > 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      "Hold a thumbnail to remove it.",
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.secondaryText,
                      ),
                    ),
                  ),
                Container(height: 0.5, color: colors.separator),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: CupertinoTextField(
                    controller: _caption,
                    placeholder: "Add a caption...",
                    placeholderStyle: TextStyle(color: colors.secondaryText),
                    style: TextStyle(color: colors.text, fontSize: 15),
                    minLines: 2,
                    maxLines: 6,
                    maxLength: 2200,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: null,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                Container(height: 0.5, color: colors.separator),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.location,
                        color: colors.text,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: CupertinoTextField(
                          controller: _location,
                          placeholder: "Add location",
                          placeholderStyle: TextStyle(
                            color: colors.secondaryText,
                          ),
                          style: TextStyle(color: colors.text, fontSize: 15),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: null,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(height: 0.5, color: colors.separator),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: SizedBox(
                    width: double.infinity,
                    child: AdaptiveButton(
                      label: "Share",
                      color: kIgBlue,
                      size: AdaptiveButtonSize.large,
                      enabled: _photos.isNotEmpty && !_sharing,
                      minSize: const Size(double.infinity, 46),
                      onPressed: _share,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_sharing)
            Positioned.fill(
              child: ColoredBox(
                color: colors.background.withValues(alpha: 0.7),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CupertinoActivityIndicator(radius: 16),
                      SizedBox(height: 12),
                      Text("Sharing..."),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SquareButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SquareButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 66,
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          color: colors.field,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: colors.text, size: 22),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, color: colors.text)),
          ],
        ),
      ),
    );
  }
}
