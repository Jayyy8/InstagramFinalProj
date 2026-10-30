import "dart:async";
import "dart:io";

import "package:flutter/cupertino.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:image_picker/image_picker.dart";

import "../models/social_models.dart";
import "../providers/auth_controller.dart";
import "../providers/social_providers.dart";
import "../providers/supabase_providers.dart";
import "../theme/app_theme.dart";
import "../widgets/auth_button.dart";
import "../widgets/dialogs.dart";
import "../widgets/gradient_avatar.dart";

/// Shown once after you create an account, before the app: your name,
/// birthday, username, then a photo, bio and gender (those three are
/// optional), like Instagram's sign-up steps.
class AccountSetupPage extends ConsumerStatefulWidget {
  final Profile profile;

  const AccountSetupPage({super.key, required this.profile});

  @override
  ConsumerState<AccountSetupPage> createState() => _AccountSetupPageState();
}

class _AccountSetupPageState extends ConsumerState<AccountSetupPage> {
  static const int _steps = 4;
  int _step = 0;
  bool _saving = false;

  late final TextEditingController _first = TextEditingController(
    text: widget.profile.firstName,
  );
  late final TextEditingController _last = TextEditingController(
    text: widget.profile.lastName,
  );
  late final TextEditingController _username = TextEditingController();
  final TextEditingController _bio = TextEditingController();

  DateTime? _birthday;
  String? _gender;
  XFile? _photo;

  /// Username check while typing: null = checking / not checked yet.
  bool? _usernameFree;
  Timer? _usernameCheck;

  static final RegExp _usernameFormat = RegExp(r"^[a-z0-9._]{3,30}$");

  @override
  void initState() {
    super.initState();
    _birthday = widget.profile.birthday;
    _first.addListener(_refresh);
    _last.addListener(_refresh);
    _username.addListener(_onUsername);
  }

  @override
  void dispose() {
    _usernameCheck?.cancel();
    _first.dispose();
    _last.dispose();
    _username.dispose();
    _bio.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  String get _email => ref.read(supabaseProvider).auth.currentUser?.email ?? "";

  int? get _age {
    final b = _birthday;
    if (b == null) return null;
    final now = DateTime.now();
    var age = now.year - b.year;
    if (now.month < b.month || (now.month == b.month && now.day < b.day)) {
      age--;
    }
    return age;
  }

  /// "Juan Dela Cruz" → "juan.delacruz".
  String _suggestUsername() {
    String clean(String s) =>
        s.toLowerCase().replaceAll(RegExp(r"[^a-z0-9]"), "");
    final first = clean(_first.text);
    final last = clean(_last.text);
    final base = [first, last].where((s) => s.isNotEmpty).join(".");
    return base.length >= 3 ? base : widget.profile.username;
  }

  void _onUsername() {
    _usernameCheck?.cancel();
    final value = _username.text.trim().toLowerCase();
    setState(() => _usernameFree = null);
    if (!_usernameFormat.hasMatch(value)) return;
    if (value == widget.profile.username) {
      setState(() => _usernameFree = true);
      return;
    }
    _usernameCheck = Timer(const Duration(milliseconds: 450), () async {
      try {
        final free = await ref.read(repositoryProvider).usernameFree(value);
        if (mounted && _username.text.trim().toLowerCase() == value) {
          setState(() => _usernameFree = free);
        }
      } catch (_) {
        if (mounted) setState(() => _usernameFree = null);
      }
    });
  }

  bool get _canContinue => switch (_step) {
    0 => _first.text.trim().isNotEmpty && _last.text.trim().isNotEmpty,
    1 => (_age ?? 0) >= 13,
    2 =>
      _usernameFormat.hasMatch(_username.text.trim().toLowerCase()) &&
          _usernameFree == true,
    _ => !_saving,
  };

  void _next() {
    if (!_canContinue) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (_step == 1 && _username.text.isEmpty) {
      _username.text = _suggestUsername();
    }
    if (_step < _steps - 1) {
      setState(() => _step++);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_step == 0) {
      // Leaving the setup signs you out; the account stays, and the setup
      // shows again next time you log in.
      confirmAction(
        context,
        title: "Leave setup?",
        message: "You can finish setting up your account next time you log in.",
        confirmLabel: "Log out",
        destructive: true,
        onConfirm: () => ref.read(authControllerProvider.notifier).signOut(),
      );
      return;
    }
    setState(() => _step--);
  }

  Future<void> _pickPhoto() async {
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 88,
      );
      if (photo != null && mounted) setState(() => _photo = photo);
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    }
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(myProfileProvider.notifier)
          .completeSetup(
            firstName: _first.text,
            lastName: _last.text,
            username: _username.text,
            birthday: _birthday!,
            gender: _gender,
            bio: _bio.text,
            photo: _photo,
          );
      // AuthGate now shows the app.
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final text = errorText(e);
      showInfo(
        context,
        title: "Couldn't save",
        message: text.contains("duplicate") || text.contains("unique")
            ? "The username ${_username.text.trim()} was just taken. Try another one."
            : text,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final padding = MediaQuery.paddingOf(context);
    return PlainPage(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Padding(
          padding: EdgeInsets.only(top: padding.top, bottom: padding.bottom),
          child: Column(
            children: [
              // ───── Back · progress ─────
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 20, 0),
                child: Row(
                  children: [
                    CupertinoButton(
                      onPressed: _saving ? null : _back,
                      child: Icon(
                        CupertinoIcons.back,
                        color: colors.text,
                        semanticLabel: _step == 0 ? "Leave setup" : "Back",
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: SizedBox(
                          height: 4,
                          child: Stack(
                            children: [
                              Container(color: colors.field),
                              FractionallySizedBox(
                                widthFactor: (_step + 1) / _steps,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: kStoryRingColors,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [_stepBody(colors)],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: _saving
                    ? const SizedBox(
                        height: 48,
                        child: Center(child: CupertinoActivityIndicator()),
                      )
                    : AuthButton(
                        label: _step == _steps - 1 ? "Finish" : "Next",
                        onTap: _canContinue ? _next : null,
                      ),
              ),
              if (_step == _steps - 1 && !_saving)
                CupertinoButton(
                  onPressed: () {
                    setState(() {
                      _photo = null;
                      _bio.clear();
                      _gender = null;
                    });
                    _finish();
                  },
                  child: Text(
                    "Skip",
                    style: TextStyle(
                      color: colors.secondaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _title(AppColors colors, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(fontSize: 15, color: colors.secondaryText),
          ),
        ],
      ),
    );
  }

  Widget _stepBody(AppColors colors) {
    switch (_step) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _title(
              colors,
              "What's your name?",
              "Add your name so friends can find you.",
            ),
            _SetupField(controller: _first, placeholder: "First name"),
            const SizedBox(height: 12),
            _SetupField(controller: _last, placeholder: "Last name"),
            const SizedBox(height: 18),
            Row(
              children: [
                Icon(
                  CupertinoIcons.mail,
                  size: 18,
                  color: colors.secondaryText,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _email.isEmpty ? "Signed up" : "Signed up as $_email",
                    style: TextStyle(color: colors.secondaryText, fontSize: 14),
                  ),
                ),
              ],
            ),
          ],
        );
      case 1:
        final age = _age;
        final initial =
            _birthday ??
            DateTime(DateTime.now().year - 18, DateTime.now().month, 1);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _title(
              colors,
              "What's your birthday?",
              "Use your own birthday, even if this account is for a business "
                  "or a pet. No one sees it on your profile.",
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              decoration: BoxDecoration(
                color: colors.field,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _birthday == null
                    ? "Birthday"
                    : "${_months[_birthday!.month - 1]} ${_birthday!.day}, "
                          "${_birthday!.year}"
                          "${age == null ? "" : "  ·  $age years old"}",
                style: TextStyle(
                  fontSize: 16,
                  color: _birthday == null ? colors.secondaryText : colors.text,
                ),
              ),
            ),
            if (age != null && age < 13)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  "You need to be at least 13 to use Instagram.",
                  style: TextStyle(color: kIgRed, fontSize: 13),
                ),
              ),
            SizedBox(
              height: 200,
              child: CupertinoTheme(
                data: CupertinoTheme.of(context).copyWith(
                  textTheme: CupertinoTextThemeData(
                    dateTimePickerTextStyle: TextStyle(
                      color: colors.text,
                      fontSize: 21,
                    ),
                  ),
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: initial,
                  minimumDate: DateTime(1900),
                  maximumDate: DateTime.now(),
                  onDateTimeChanged: (d) => setState(() => _birthday = d),
                ),
              ),
            ),
          ],
        );
      case 2:
        final value = _username.text.trim().toLowerCase();
        final badFormat = value.isNotEmpty && !_usernameFormat.hasMatch(value);
        final Widget? status = value.isEmpty || badFormat
            ? null
            : _usernameFree == null
            ? const CupertinoActivityIndicator(radius: 8)
            : Icon(
                _usernameFree!
                    ? CupertinoIcons.checkmark_circle_fill
                    : CupertinoIcons.xmark_circle_fill,
                color: _usernameFree! ? const Color(0xFF2ECC71) : kIgRed,
                size: 22,
              );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _title(
              colors,
              "Create a username",
              "Add a username or use our suggestion. You can change it at "
                  "any time.",
            ),
            _SetupField(
              controller: _username,
              placeholder: "Username",
              suffix: status == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: status,
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              badFormat
                  ? "Use 3–30 lowercase letters, numbers, periods or underscores."
                  : _usernameFree == false
                  ? "The username $value isn't available."
                  : _usernameFree == true
                  ? "$value is available."
                  : "",
              style: TextStyle(
                fontSize: 13,
                color: badFormat || _usernameFree == false
                    ? kIgRed
                    : colors.secondaryText,
              ),
            ),
          ],
        );
      default:
        return Column(
          children: [
            _title(
              colors,
              "Add a profile picture",
              "Add a profile picture so your friends know it's you. Everyone "
                  "will be able to see your picture.",
            ),
            GestureDetector(
              onTap: _pickPhoto,
              child: Stack(
                children: [
                  _photo != null
                      ? ClipOval(
                          child: Image.file(
                            File(_photo!.path),
                            width: 140,
                            height: 140,
                            fit: BoxFit.cover,
                          ),
                        )
                      : GradientAvatar(
                          name: _first.text.isEmpty ? "?" : _first.text,
                          imageUrls: widget.profile.avatarUrls,
                          size: 140,
                          ring: false,
                        ),
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: kIgBlue,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.background, width: 3),
                      ),
                      child: const Icon(
                        CupertinoIcons.camera_fill,
                        size: 16,
                        color: Color(0xFFFFFFFF),
                        semanticLabel: "Add picture",
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            CupertinoTextField(
              controller: _bio,
              placeholder: "Bio (optional)",
              maxLength: 150,
              maxLines: 3,
              minLines: 2,
              placeholderStyle: TextStyle(color: colors.secondaryText),
              style: TextStyle(color: colors.text, fontSize: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: colors.field,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Gender (optional)",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<String>(
                groupValue: _gender,
                children: {
                  for (final g in const ["Female", "Male", "Prefer not to say"])
                    g: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        g,
                        style: TextStyle(fontSize: 13, color: colors.text),
                      ),
                    ),
                },
                onValueChanged: (g) => setState(() => _gender = g),
              ),
            ),
          ],
        );
    }
  }
}

const List<String> _months = [
  "January",
  "February",
  "March",
  "April",
  "May",
  "June",
  "July",
  "August",
  "September",
  "October",
  "November",
  "December",
];

/// A filled, rounded text field, like Instagram's sign-up screens.
class _SetupField extends StatelessWidget {
  final TextEditingController controller;
  final String placeholder;
  final Widget? suffix;

  const _SetupField({
    required this.controller,
    required this.placeholder,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return CupertinoTextField(
      controller: controller,
      placeholder: placeholder,
      autocorrect: false,
      textCapitalization: TextCapitalization.words,
      suffix: suffix,
      placeholderStyle: TextStyle(color: colors.secondaryText, fontSize: 16),
      style: TextStyle(color: colors.text, fontSize: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: colors.field,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
