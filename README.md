# Instagram Replica (Flutter + Supabase)

A class project that recreates the Instagram app. The UI is built only with
`adaptive_platform_ui` and Flutter's Cupertino library (no `material.dart`
imports in `lib/`), so it adapts to the phone it runs on:

| Device            | What you see                                          |
| ----------------- | ----------------------------------------------------- |
| iPhone, iOS 26+   | Native Liquid Glass toolbar, tab bar, buttons, alerts |
| iPhone, iOS ≤ 18  | Classic Cupertino navigation bar and tab bar          |
| Android           | Instagram's flat Android bars (icon-only tab bar), Material dialogs and controls |

## Features

- **Auth:** register (email code), log in with password / code, forgot
  password, **change password** (Settings → Change password).
- **Profile:** edit name, username, bio and **profile photo** (uploaded to
  Supabase Storage), followers / following lists, "Complete your profile".
- **Feed:** posts with up to 10 photos or one video (Supabase Storage), likes,
  comments, saves, share to DMs, delete your own posts, pull to refresh.
  Posts from you and people you follow come first, then the sample channels.
- **New post (the "+" button):** Instagram's create screen with your photo
  gallery, a big preview, "Select" for up to 10 photos and the
  POST / STORY / INSTANTS / REEL / LIVE switcher. The editor has Audio, Text,
  Overlay, Filter (12 filters), Edit (brightness, contrast, saturation,
  warmth, fade) and Ratio (original, 4:5, 1:1, 16:9); edits are drawn into
  the uploaded photo. The details page adds a caption, a poll, a prompt, a
  song, tagged people, a location, a link, the AI label, "Post only to
  profile", the audience, "Also share on your story", hide like count and
  turn off commenting.
- **Text editor** (stories, posts, reels): Instagram's fonts, colors,
  animations (Typewriter, Pop, Fade, Jump, Wobble), effects (Neon, Glow,
  Shadow, Outline, Shimmer), alignment, background box, size slider,
  Mention and Location. Drag texts and stickers; pinch to resize.
- **Videos** (reels / video posts): text, filter, edit, ratio, overlay photo
  and a draggable song sticker, applied while the video plays.
- **Share sheet:** pick people (✓) and Send, Add to story, Copy link,
  Share to feed.
- **Reposts:** the repost button (or Share to feed) adds a post to your
  profile's Reposts tab and to your followers' feeds ("username reposted").
- **Reels:** videos from you and people you follow, then the sample channels.
- **Sample channel profiles:** tap a sample account to see its profile and posts.
- **Stories:** upload photos or videos (camera or gallery), add text, a
  location and a song (30-second previews from the iTunes Search API), see
  who viewed and liked your story, reply by DM, archive, 24-hour expiry.
- **Notes (My Day):** 60-character notes with an optional song and location,
  shown in the inbox and on profiles, like and reply by DM, 24-hour expiry.
- **Follow / Add friend:** search accounts, suggestions, follow / unfollow.
- **Direct messages:** realtime chat with text and photos, "Seen", reactions
  (hold or double-tap), reply (swipe right or hold), unsend, delete for you.
- **Notifications:** new followers, likes and comments on your posts, with a
  red count on the heart for anything new.
- **Settings → Developer info:** group members and contributions
  (edit `lib/data/developers.dart`).

## Setup

1. **Database:** open the Supabase dashboard → SQL Editor → New query, paste
   all of [`supabase/schema.sql`](supabase/schema.sql) and press Run. It
   creates the tables, security rules, storage buckets and turns on realtime
   for messages. It is safe to run again: **run it again after every update**
   that changes it (the latest, Update 6, adds reposts and saves texts and
   video edits on posts).
2. **Sample accounts (optional):** run [`supabase/seed.sql`](supabase/seed.sql)
   the same way, after `schema.sql`. It adds 34 fictional accounts: news
   channels, sports channels, pages (memes, food, travel, pets, cars),
   subscription platforms (movies, music, games, books) and people, with
   posts, reels, stories, notes, follows, likes and comments. They replace
   the built-in sample channels everywhere (feed, stories, Reels, Explore,
   notes). Run it again any time to bring their stories back (they last a
   week). The accounts can't be logged in to; `supabase/seed_remove.sql`
   deletes them all. To change them, edit `tool/seed/generate_seed.py` and
   run `python tool/seed/generate_seed.py`.
3. **Group members:** replace the placeholders in `lib/data/developers.dart`.
4. `flutter pub get`

## Run on a phone

- **Android (USB debugging):** `flutter run --release`
- **iPhone (sideload):** needs a Mac with Xcode. Minimum iOS is 15.0.
  Open `ios/Runner.xcworkspace`, pick your Apple ID team under Signing, then
  `flutter run --release` with the phone connected.

The phone asks for camera, microphone and photo access the first time you
post or add to your story.
