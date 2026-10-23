# Instagram Replica (Flutter + Supabase)

A class project that recreates the Instagram app. The UI is built only with
`adaptive_platform_ui` and Flutter's Cupertino library (no `material.dart`
imports in `lib/`), so it adapts to the phone it runs on:

| Device            | What you see                                          |
| ----------------- | ----------------------------------------------------- |
| iPhone, iOS 26+   | Native Liquid Glass toolbar, tab bar, buttons, alerts |
| iPhone, iOS ≤ 18  | Classic Cupertino navigation bar and tab bar          |
| Android           | Material app bar, navigation bar, dialogs, snackbars  |

## Features

- **Auth:** register (email code), log in with password / code / Apple, forgot
  password, **change password** (Settings → Change password).
- **Profile:** edit name, username, bio and **profile photo** (uploaded to
  Supabase Storage), followers / following lists, "Complete your profile".
- **Feed:** posts with up to 10 photos (Supabase Storage), likes, comments,
  saves, share to DMs, delete your own posts, pull to refresh.
  Posts from you and people you follow come first, then the sample channels.
- **Stories:** upload photos or videos (camera or gallery), add text, see who
  viewed and liked your story, reply by DM, archive, 24-hour expiry.
- **Notes (My Day):** 60-character notes shown in the inbox and on profiles,
  like and reply by DM, 24-hour expiry.
- **Follow / Add friend:** search accounts, suggestions, follow / unfollow.
- **Direct messages:** realtime chat with text and photos, "Seen", unsend.
- **Notifications:** new followers, likes and comments on your posts.
- **Settings → Developer info:** group members and contributions
  (edit `lib/data/developers.dart`).

## Setup

1. **Database:** open the Supabase dashboard → SQL Editor → New query, paste
   all of [`supabase/schema.sql`](supabase/schema.sql) and press Run. It
   creates the tables, security rules, storage buckets and turns on realtime
   for messages. It is safe to run again.
2. **Group members:** replace the placeholders in `lib/data/developers.dart`.
3. `flutter pub get`

## Run on a phone

- **Android (USB debugging):** `flutter run --release`
- **iPhone (sideload):** needs a Mac with Xcode. Minimum iOS is 15.0.
  Open `ios/Runner.xcworkspace`, pick your Apple ID team under Signing, then
  `flutter run --release` with the phone connected.

The phone asks for camera, microphone and photo access the first time you
post or add to your story.
