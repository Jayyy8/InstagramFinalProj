import "package:adaptive_platform_ui/adaptive_platform_ui.dart";
import "package:flutter/cupertino.dart";

import "../data/developers.dart";
import "../theme/app_theme.dart";
import "../widgets/gradient_avatar.dart";
import "../widgets/sub_page.dart";

/// Settings → Developer info: group members and what each one did.
class DeveloperInfoPage extends StatelessWidget {
  const DeveloperInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return SubPage(
      title: "Developer info",
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                      colors: kStoryRingColors,
                    ),
                  ),
                  child: const Icon(
                    CupertinoIcons.camera,
                    color: Color(0xFFFFFFFF),
                    size: 38,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  kProjectName,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(kCourse, style: TextStyle(color: colors.secondaryText)),
                const SizedBox(height: 4),
                Text(
                  "${kDevelopers.length} group members",
                  style: TextStyle(color: colors.secondaryText, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          for (final dev in kDevelopers)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AdaptiveCard(
                padding: const EdgeInsets.all(14),
                borderRadius: BorderRadius.circular(14),
                color: colors.field,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GradientAvatar(
                          name: dev.name,
                          imageUrls: dev.photoUrl == null
                              ? null
                              : [dev.photoUrl!],
                          size: 48,
                          ring: false,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dev.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: colors.text,
                                ),
                              ),
                              Text(
                                dev.role,
                                style: TextStyle(
                                  color: colors.secondaryText,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (dev.contributions.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        "Contributions",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: colors.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    for (final c in dev.contributions)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("•  ", style: TextStyle(color: colors.text)),
                            Expanded(
                              child: Text(
                                c,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colors.text,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            "Built with Flutter, Supabase, Riverpod and adaptive_platform_ui.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: colors.secondaryText),
          ),
        ],
      ),
    );
  }
}
