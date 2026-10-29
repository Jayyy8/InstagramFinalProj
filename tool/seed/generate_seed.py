"""Writes supabase/seed.sql: fictional accounts (news, sports, pages,
subscription platforms and people) with posts, reels, stories, notes,
follows, likes and comments.

    python tool/seed/generate_seed.py

Run the result in the Supabase SQL editor after schema.sql. Everything is
fictional: no real people, brands or channels. Seed accounts have
"@seed.invalid" emails and no password, so nobody can sign in as them;
supabase/seed_remove.sql deletes them all.

Photos: Picsum (Unsplash photos, free to use) and a few public-domain
Wikimedia Commons sports photos. Videos: free sample clips. Songs: Apple's
30-second previews (songs.json).
"""
import json
import os
import random
import uuid

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "supabase", "seed.sql")
SONGS = json.load(open(os.path.join(os.path.dirname(__file__), "songs.json"), encoding="utf-8"))
NS = uuid.UUID("6f1d2a43-6b2e-4c43-9f3e-5eed5eed0001")
rnd = random.Random(2026)


def uid(*parts):
    return str(uuid.uuid5(NS, "/".join(str(p) for p in parts)))


def q(s):
    """SQL string literal."""
    return "'" + str(s).replace("'", "''") + "'"


def pic(i, w=1080, h=1350):
    return f"https://picsum.photos/id/{i}/{w}/{h}"


def commons(file):
    return f"https://commons.wikimedia.org/wiki/Special:FilePath/{file}?width=1080"


def logo(text, bg, fg="ffffff"):
    return (
        "https://ui-avatars.com/api/?format=png&bold=true&size=256&font-size=0.42"
        f"&name={text.replace(' ', '+')}&background={bg}&color={fg}"
    )


# Public-domain sports photos (already used by the app's sample feed).
SPORTS_PD = [
    commons("RoseGardenArenaInterior3.jpg"),
    commons("Basketball_game_at_Camp_Lemonnier_DVIDS164937.jpg"),
    commons("GeorgeMikan.jpg"),
    commons("Soccer-City-Stadium-at-capacity.jpg"),
    commons("Jeonju_World_Cup_Stadium_2016.jpg"),
]

VIDEOS = [
    "https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_1MB.mp4",
    "https://test-videos.co.uk/vids/jellyfish/mp4/h264/720/Jellyfish_720_10s_1MB.mp4",
    "https://test-videos.co.uk/vids/sintel/mp4/h264/720/Sintel_720_10s_1MB.mp4",
    "https://download.samplelib.com/mp4/sample-5s.mp4",
    "https://download.samplelib.com/mp4/sample-10s.mp4",
    "https://download.samplelib.com/mp4/sample-15s.mp4",
    "https://download.samplelib.com/mp4/sample-20s.mp4",
    "https://download.samplelib.com/mp4/sample-30s.mp4",
    "https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4",
    "https://www.w3schools.com/html/movie.mp4",
    "https://filesamples.com/samples/video/mp4/sample_640x360.mp4",
]

# Picsum photo ids by subject (picked by looking at the whole library).
P = {
    "city": [43, 57, 84, 88, 122, 164, 188, 212, 214, 221, 238, 257, 259, 274, 283, 288, 299, 322, 348,
             351, 354, 371, 376, 382, 391, 398, 410, 411, 419, 437, 441, 448, 520, 522, 670, 690, 692, 703,
             736, 737, 740, 742, 743, 760, 799, 800, 818, 857, 862, 864, 868, 939, 985, 1029, 1047, 1067, 1075],
    "sky": [53, 141, 272, 542, 705, 741, 1019, 990, 724, 901, 1022, 883, 894, 896, 918, 987],
    "sport": [585, 840, 1058, 839, 841, 1077, 770, 904, 281, 390, 157],
    "food": [30, 42, 63, 75, 102, 225, 292, 312, 326, 365, 425, 429, 431, 488, 493, 517, 627, 635, 674,
             766, 835, 889, 999, 1060, 1080, 824],
    "tech": [0, 1, 2, 3, 4, 5, 6, 8, 9, 20, 26, 36, 48, 60, 119, 160, 180, 201, 366, 367, 370, 445, 526,
             527, 528, 529, 532, 668, 373, 816],
    "music": [39, 158, 452, 453, 836, 1082, 117, 145, 828, 959],
    "travel": [10, 11, 12, 13, 15, 17, 28, 29, 46, 49, 54, 74, 77, 142, 162, 174, 182, 191, 323, 328, 380,
               392, 401, 434, 436, 450, 477, 482, 483, 509, 510, 511, 512, 515, 519, 521, 523, 525, 547,
               558, 563, 564, 575, 603, 639, 645, 648, 664, 676, 678, 684, 688, 702, 772, 773, 806, 829,
               830, 849, 871, 873, 883, 902, 905, 906, 908, 916, 918, 921, 928, 929, 961, 980, 1015, 1016,
               1018, 1035, 1036, 1039, 1040, 1043, 1050],
    "animal": [40, 169, 200, 219, 237, 433, 582, 584, 593, 659, 718, 783, 837, 943, 1003, 1020, 1024,
               1025, 1062, 1074, 1084, 581, 1069, 881, 937],
    "people": [64, 65, 91, 129, 177, 203, 319, 331, 338, 375, 399, 447, 473, 550, 602, 628, 646, 660, 661,
               669, 777, 778, 786, 804, 815, 822, 823, 832, 838, 856, 863, 1001, 1005, 1010, 1011, 1012,
               1027, 996, 978],
    "car": [111, 133, 183, 655, 1070, 1071, 1072, 605, 757, 352],
    "film": [250, 355, 435, 454, 495, 861, 1079, 91, 823, 628],
    "space": [537, 683, 903, 974, 967, 1022, 724, 681, 831, 869],
    "books": [24, 367, 1010, 1073, 998, 403, 486, 885, 832],
}

# ───────────── Accounts ─────────────
# kind: page (verified, logo avatar) or person (photo avatar).
ACCOUNTS = [
    # News
    dict(h="worldnews.now", n="World News Now", cat="News & media website", kind="page",
         avatar=logo("WN", "C62828"), subj=["city", "sky"],
         bio="Breaking stories from around the world, around the clock.\nLive coverage every night at 9 PM."),
    dict(h="globe24.news", n="Globe 24", cat="Media/news company", kind="page",
         avatar=logo("G24", "0D47A1"), subj=["city", "travel"],
         bio="24/7 news, explained simply.\nTap the link for today's briefing."),
    dict(h="metrodaily.ph", n="Metro Daily PH", cat="Newspaper", kind="page",
         avatar=logo("MD", "263238"), subj=["city"],
         bio="Your city, your stories. Traffic, weather and local news every morning."),
    dict(h="brightline.news", n="Brightline News", cat="News & media website", kind="page",
         avatar=logo("BL", "FF6F00"), subj=["city", "people"],
         bio="Good news only. Stories that make your day a little better."),
    dict(h="weatherwatch.live", n="Weather Watch", cat="Weather", kind="page",
         avatar=logo("WW", "0288D1"), subj=["sky", "travel"],
         bio="Forecasts, storm tracking and the best sky photos from our followers."),
    dict(h="techpulse.daily", n="TechPulse", cat="Science, technology & engineering", kind="page",
         avatar=logo("TP", "6A1B9A"), subj=["tech", "space"],
         bio="Gadgets, apps and the future, in 60 seconds a day."),
    # Sports
    dict(h="hoops.daily", n="Hoops Daily", cat="Sports", kind="page",
         avatar=logo("HD", "E65100"), subj=["sport", "sportpd"],
         bio="All basketball, all day. Highlights, scores and game-night vibes."),
    dict(h="matchday.live", n="Matchday Live", cat="Sports", kind="page",
         avatar=logo("ML", "2E7D32"), subj=["sport", "sportpd"],
         bio="Football from every league. Kickoff alerts, goals and match photos."),
    dict(h="courtside.hq", n="Courtside HQ", cat="Sports team", kind="page",
         avatar=logo("CS", "4527A0"), subj=["sport", "sportpd", "city"],
         bio="Courtside seats to the best games. Tag us in your arena photos."),
    dict(h="ringside.fight", n="Ringside", cat="Sports", kind="page",
         avatar=logo("RS", "B71C1C"), subj=["sport", "people"],
         bio="Boxing and MMA: fight nights, training camps and weigh-ins."),
    dict(h="pitchside.fc", n="Pitchside FC", cat="Amateur sports team", kind="page",
         avatar=logo("PFC", "1B5E20"), subj=["sport", "sportpd"],
         bio="Weekend league champions (twice). Training Tuesdays and Thursdays."),
    dict(h="fastlane.athletics", n="Fastlane Athletics", cat="Sports & recreation", kind="page",
         avatar=logo("FA", "00838F"), subj=["sport", "travel"],
         bio="Running, cycling and swimming. Every finish line counts."),
    # Social media pages
    dict(h="planet.docs", n="Planet Docs", cat="Media", kind="page",
         avatar=logo("PD", "00695C"), subj=["travel", "animal"],
         bio="Nature documentaries in bite-size pieces. Our planet is wild."),
    dict(h="dailymemes.ph", n="Daily Memes PH", cat="Entertainment website", kind="page",
         avatar=logo("DM", "F9A825", "000000"), subj=["animal", "people", "food"],
         bio="Your daily dose of good vibes and bad jokes. DM us your memes."),
    dict(h="foodiefinds.ph", n="Foodie Finds", cat="Food & beverage", kind="page",
         avatar=logo("FF", "D84315"), subj=["food"],
         bio="Hidden gems, street food and weekend brunch spots. Hungry yet?"),
    dict(h="wanderlust.trips", n="Wanderlust Trips", cat="Travel company", kind="page",
         avatar=logo("WT", "0277BD"), subj=["travel"],
         bio="Where to next? Travel ideas, itineraries and views worth the climb."),
    dict(h="petsofmanila", n="Pets of Manila", cat="Pet", kind="page",
         avatar=logo("PM", "8D6E63"), subj=["animal"],
         bio="The goodest boys and girls in the metro. Tag us to be featured!"),
    dict(h="carculture.club", n="Car Culture Club", cat="Automotive", kind="page",
         avatar=logo("CC", "212121"), subj=["car", "city"],
         bio="Classics, road trips and Sunday drives. Car meets every month."),
    # Subscription platforms
    dict(h="streamly", n="Streamly", cat="Movie/television studio", kind="page",
         avatar=logo("S", "E50914"), subj=["film", "people"],
         bio="Movies and series, all in one place. New on Streamly every Friday."),
    dict(h="tunebox.music", n="Tunebox", cat="Music streaming", kind="page",
         avatar=logo("TB", "1DB954", "000000"), subj=["music", "people"],
         bio="Millions of songs. Playlists for every mood. Press play."),
    dict(h="gamevault.plus", n="GameVault+", cat="Video game", kind="page",
         avatar=logo("GV", "311B92"), subj=["tech", "space"],
         bio="Hundreds of games, one subscription. New drops every week."),
    dict(h="readmore.app", n="ReadMore", cat="App page", kind="page",
         avatar=logo("RM", "5D4037"), subj=["books", "food"],
         bio="Read anywhere. E-books and audiobooks for the curious."),
    # People
    dict(h="andrea.santos", n="Andrea Santos", cat="Digital creator", kind="person",
         avatar=pic(64, 300, 300), subj=["travel", "food", "people"],
         bio="coffee first ☕ | weekend wanderer | Manila"),
    dict(h="miguel.reyes", n="Miguel Reyes", cat="", kind="person",
         avatar=pic(177, 300, 300), subj=["travel", "sport"],
         bio="Hikes, hoops and long drives."),
    dict(h="bea.cruz", n="Bea Cruz", cat="Photographer", kind="person",
         avatar=pic(1027, 300, 300), subj=["people", "city", "sky"],
         bio="📷 shooting city lights and golden hours"),
    dict(h="jp.delarosa", n="JP dela Rosa", cat="", kind="person",
         avatar=pic(1005, 300, 300), subj=["car", "city"],
         bio="engineer by day, car guy by night"),
    dict(h="kaye.villanueva", n="Kaye Villanueva", cat="Artist", kind="person",
         avatar=pic(646, 300, 300), subj=["music", "people"],
         bio="singer-songwriter 🎶 new song soon"),
    dict(h="marco.lim", n="Marco Lim", cat="", kind="person",
         avatar=pic(338, 300, 300), subj=["tech", "space"],
         bio="building apps, breaking things"),
    dict(h="sofia.garcia", n="Sofia Garcia", cat="Blogger", kind="person",
         avatar=pic(669, 300, 300), subj=["food", "books"],
         bio="books, brunch and a lot of plants 🌿"),
    dict(h="nico.tan", n="Nico Tan", cat="", kind="person",
         avatar=pic(804, 300, 300), subj=["sport", "travel"],
         bio="runner 🏃 5 marathons and counting"),
    dict(h="rina.mendoza", n="Rina Mendoza", cat="", kind="person",
         avatar=pic(1011, 300, 300), subj=["travel", "animal"],
         bio="beach > mountains (fight me)"),
    dict(h="paolo.aquino", n="Paolo Aquino", cat="Gamer", kind="person",
         avatar=pic(823, 300, 300), subj=["tech", "film"],
         bio="streams on weekends 🎮"),
    dict(h="lianne.ocampo", n="Lianne Ocampo", cat="", kind="person",
         avatar=pic(778, 300, 300), subj=["people", "sky", "food"],
         bio="soft life era ✨"),
    dict(h="joshua.ramos", n="Joshua Ramos", cat="", kind="person",
         avatar=pic(1001, 300, 300), subj=["animal", "travel"],
         bio="dog dad 🐶 x2"),
]

CAPTIONS = {
    "city": [
        "City council approves new bike lanes for the downtown loop.",
        "Rush hour from above. How long was your commute today?",
        "The new night market opens this weekend near the river.",
        "Rain or shine, the city keeps moving.",
        "Skyline check: clear views all the way to the bay tonight.",
        "Residents celebrate the reopening of the old public library.",
    ],
    "sky": [
        "Weekend forecast: clouds in the morning, sunshine by the afternoon.",
        "Storm clouds rolling in. Stay safe and stay indoors tonight.",
        "This sunset though. Shared by one of our followers 🌅",
        "Heat advisory today: drink water and stay in the shade.",
        "Clear skies ahead for the meteor shower this week.",
    ],
    "sport": [
        "Game night! Who's watching? 🏀",
        "Last-second winner. What a finish.",
        "Training day. No days off.",
        "Full house tonight. The energy is unreal.",
        "Highlights from the weekend league 🔥",
        "Swipe for the best moments from the final.",
    ],
    "sportpd": [
        "Packed arena for the season opener.",
        "Throwback to one of the greatest games ever played.",
        "Stadium at capacity. Matchday hits different.",
        "Under the lights. Who you got tonight?",
    ],
    "food": [
        "Found the best street food in the city 🍢 Save this for later!",
        "Weekend brunch done right.",
        "Coffee and a good book. That's the plan.",
        "Rate this from 1 to 10 👇",
        "Homemade and still warm. Recipe in the comments.",
        "Dessert first, always.",
    ],
    "tech": [
        "Desk setup of the week. Rate it 1-10 💻",
        "5 apps that will save you hours this month.",
        "The future of work is… a really good chair.",
        "Shipping a new feature today 🚀",
        "Minimal setup, maximum focus.",
    ],
    "music": [
        "New playlist just dropped. Link in bio 🎧",
        "Live music is the best medicine.",
        "What song is stuck in your head today?",
        "Front row energy ✨",
    ],
    "travel": [
        "Woke up to this view. Worth the 5 AM alarm.",
        "Save this for your next trip ✈️",
        "Somewhere between the mountains and the sea.",
        "Hidden waterfall alert 💧 Swipe for directions.",
        "Road trip season is officially open.",
        "Tag someone you'd go here with.",
    ],
    "animal": [
        "Meet today's very good boy 🐶",
        "Nature is amazing. Sound on for this one.",
        "Caught napping on the job.",
        "Wild and free 🐾",
        "This face though 🥺",
    ],
    "people": [
        "Good days start with good people.",
        "Golden hour hits different.",
        "Little moments, big memories.",
        "Weekend mood 😌",
        "Photo dump from this week 📸",
    ],
    "car": [
        "Sunday drive in a classic.",
        "Spotted at this month's car meet 🚗",
        "They don't make them like this anymore.",
        "Open road, good playlist, no plans.",
    ],
    "film": [
        "New on Streamly this Friday 🍿 Who's watching?",
        "Movie night essentials: snacks, blanket, no spoilers.",
        "Behind the scenes from our latest series 🎬",
        "Comment your all-time favorite movie 👇",
    ],
    "space": [
        "Look up tonight: the stars are out in full force ✨",
        "The universe is big. Your problems are small.",
        "Night sky over the mountains, no filter.",
    ],
    "books": [
        "This month's top reads 📚",
        "Bookmark this list for your next weekend.",
        "One more chapter. Okay, maybe two.",
    ],
}

LOCATIONS = {
    "city": ["Makati, Metro Manila", "Bonifacio Global City", "Quezon City", "Downtown", "Pasig City"],
    "sky": ["Metro Manila", "Tagaytay", "Baguio City"],
    "sport": ["City Arena", "National Stadium", "Sports Complex", "Riverside Park"],
    "sportpd": ["City Arena", "National Stadium"],
    "food": ["Binondo, Manila", "Poblacion, Makati", "Maginhawa Street", "Cubao Expo"],
    "tech": ["BGC", "Ortigas Center", ""],
    "music": ["Music Hall", "Open-air stage", ""],
    "travel": ["El Nido, Palawan", "Siargao", "Batanes", "Sagada", "Coron", "La Union", "Bohol"],
    "animal": ["", "Animal shelter", "Dog park"],
    "people": ["", "Intramuros", "Tagaytay"],
    "car": ["Car meet", "Marcos Highway", ""],
    "film": ["", "Studio 3"],
    "space": ["Mt. Pulag", "Batangas", ""],
    "books": ["", "Book café"],
}

COMMENTS = [
    "This is amazing 😍", "So good!", "Need this right now", "🔥🔥🔥", "Wow 👏", "Saving this",
    "Take me there 😭", "Love this!", "Couldn't agree more", "This made my day", "Iconic",
    "Where is this?", "Ang ganda!", "Sana all", "Goals 🙌", "Haha same", "Big mood",
    "Can't wait!", "Best one yet", "Who else is watching? 👀",
]

NOTES = [
    "coffee then chaos ☕", "who's free this weekend?", "new song stuck in my head",
    "5K done before sunrise 🏃", "need a beach trip asap", "game night anyone? 🎮",
    "reading again 📚", "rain + lugaw = perfect", "road trip playlist ideas?",
    "my dog ate my homework (really)", "golden hour hunting 📷", "soft life loading…",
]


def photo_for(subject, used):
    if subject == "sportpd":
        return rnd.choice(SPORTS_PD)
    pool = P[subject]
    choices = [i for i in pool if i not in used] or pool
    i = rnd.choice(choices)
    used.add(i)
    return pic(i)


def song_json(song, sticker=None):
    d = {
        "title": song["title"],
        "artist": song["artist"],
        "preview_url": song["preview_url"],
        "artwork_url": song["artwork_url"],
    }
    if sticker is not None:
        d["sticker"] = sticker
    return d


def jb(obj):
    return q(json.dumps(obj, ensure_ascii=False)) + "::jsonb"


lines = []
w = lines.append
w("-- Seed data: fictional accounts with posts, reels, stories and notes.")
w("-- Generated by tool/seed/generate_seed.py. Run it in the Supabase SQL")
w("-- editor AFTER supabase/schema.sql (all updates). Safe to run again: it")
w("-- refreshes the stories and notes so they don't expire.")
w("-- Seed accounts use @seed.invalid emails and no password: nobody can log")
w("-- in as them. supabase/seed_remove.sql deletes all of them.")
w("")
w("begin;")
w("")
w("-- Verified badge, category and a seed marker on profiles.")
w("alter table public.profiles add column if not exists is_verified boolean not null default false;")
w("alter table public.profiles add column if not exists category text;")
w("alter table public.profiles add column if not exists is_seed boolean not null default false;")
w("")

people = [a for a in ACCOUNTS if a["kind"] == "person"]
pages = [a for a in ACCOUNTS if a["kind"] == "page"]
for a in ACCOUNTS:
    a["id"] = uid("user", a["h"])

w("-- ───── Accounts ─────")
for a in ACCOUNTS:
    email = a["h"].replace("_", "-") + "@seed.invalid"
    w(
        "insert into auth.users (instance_id, id, aud, role, email, encrypted_password, "
        "email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, "
        "confirmation_token, recovery_token, email_change_token_new, email_change) values ("
        f"'00000000-0000-0000-0000-000000000000', {q(a['id'])}, 'authenticated', 'authenticated', "
        f"{q(email)}, '', now(), '{{\"provider\":\"email\",\"providers\":[\"email\"]}}'::jsonb, "
        f"{jb({'full_name': a['n']})}, now() - interval '400 days', now(), '', '', '', '') "
        "on conflict (id) do nothing;"
    )
w("")
for a in ACCOUNTS:
    w(
        "insert into public.profiles (id, username, full_name, bio, avatar_url, is_verified, category, is_seed) "
        f"values ({q(a['id'])}, {q(a['h'])}, {q(a['n'])}, {q(a['bio'])}, {q(a['avatar'])}, "
        f"{'true' if a['kind'] == 'page' else 'false'}, {q(a['cat']) if a['cat'] else 'null'}, true) "
        "on conflict (id) do update set username = excluded.username, full_name = excluded.full_name, "
        "bio = excluded.bio, avatar_url = excluded.avatar_url, is_verified = excluded.is_verified, "
        "category = excluded.category, is_seed = true;"
    )
w("")

# ───── Posts and reels ─────
w("-- ───── Posts and reels ─────")
all_posts = []
video_i = 0
for a in ACCOUNTS:
    used = set()
    n_posts = 9 if a["kind"] == "page" else 6
    n_videos = 2 if a["kind"] == "page" else 1
    video_slots = set(rnd.sample(range(n_posts), n_videos))
    for i in range(n_posts):
        subject = rnd.choice(a["subj"])
        pid = uid("post", a["h"], i)
        hours = rnd.randint(2, 24 * 40)
        caption = rnd.choice(CAPTIONS[subject])
        location = rnd.choice(LOCATIONS[subject])
        cols = ["id", "user_id", "caption", "location", "image_url", "image_urls", "media_type", "created_at"]
        if i in video_slots:
            url = VIDEOS[video_i % len(VIDEOS)]
            video_i += 1
            urls = [url]
            media = "video"
        else:
            count = rnd.choice([1, 1, 1, 2, 3])
            urls = [photo_for(subject, used) for _ in range(count)]
            media = "image"
        vals = [q(pid), q(a["id"]), q(caption), q(location), q(urls[0]),
                "array[" + ", ".join(q(u) for u in urls) + "]::text[]", q(media),
                f"now() - interval '{hours} hours'"]
        # Some posts have a song; a few show its sticker.
        if rnd.random() < 0.3:
            song = rnd.choice(SONGS)
            if rnd.random() < 0.4:
                sticker = {"x": 0.5, "y": round(rnd.uniform(0.7, 0.85), 2), "scale": 1,
                           "hidden": False, "style": rnd.choice(["card", "card", "cover"]),
                           "color": rnd.randint(0, 4), "start_ms": 0, "clip_ms": 15000}
                cols += ["music", "edits"]
                aspect = 16 / 9 if media == "video" else 0.8
                vals += [jb(song_json(song, sticker)),
                         jb({"aspects": [round(aspect, 4)] * len(urls)})]
            else:
                cols.append("music")
                vals.append(jb(song_json(song)))
        # "Only if missing" works whatever constraints the table has.
        w(
            f"insert into public.posts ({', '.join(cols)}) select {', '.join(vals)} "
            f"where not exists (select 1 from public.posts where id = {q(pid)});"
        )
        all_posts.append((pid, a))
w("")

# ───── Follows: people follow pages and each other ─────
w("-- ───── Follows ─────")
follows = set()
for p in people:
    for page in rnd.sample(pages, rnd.randint(8, 14)):
        follows.add((p["id"], page["id"]))
    for other in rnd.sample([x for x in people if x is not p], rnd.randint(4, 7)):
        follows.add((p["id"], other["id"]))
for page in pages:
    for other in rnd.sample([x for x in pages if x is not page], 2):
        follows.add((page["id"], other["id"]))
w("insert into public.follows (follower_id, following_id) values")
w(",\n".join(f"  ({q(f)}, {q(t)})" for f, t in sorted(follows)))
w("on conflict do nothing;")
w("")

# ───── Likes and comments ─────
w("-- ───── Likes and comments ─────")
for pid, author in all_posts:
    fans = [p for p in people if p is not author]
    likers = rnd.sample(fans, rnd.randint(3, len(fans)))
    w(
        "insert into public.likes (post_id, user_id) values "
        + ", ".join(f"({q(pid)}, {q(fan['id'])})" for fan in likers)
        + " on conflict do nothing;"
    )
    for j, fan in enumerate(rnd.sample(fans, rnd.randint(0, 4))):
        cid = uid("comment", pid, j)
        w(
            "insert into public.comments (id, post_id, user_id, body, created_at) select "
            f"{q(cid)}, {q(pid)}, {q(fan['id'])}, {q(rnd.choice(COMMENTS))}, "
            f"now() - interval '{rnd.randint(1, 48)} hours' "
            f"where not exists (select 1 from public.comments where id = {q(cid)});"
        )
w("")

# ───── Stories (kept fresh: re-running moves them to "a few hours ago") ─────
w("-- ───── Stories ─────")
for a in ACCOUNTS:
    n = rnd.randint(2, 3) if a["kind"] == "page" else rnd.choice([0, 1, 1, 2])
    used = set()
    for i in range(n):
        sid = uid("story", a["h"], i)
        subject = rnd.choice(a["subj"])
        if rnd.random() < 0.2:
            media, mtype, dur = VIDEOS[rnd.randrange(len(VIDEOS))], "video", 10000
        else:
            media, mtype, dur = photo_for(subject, used).replace("1080/1350", "1080/1920"), "image", 5000
        music = "null"
        if rnd.random() < 0.45:
            sticker = {"x": 0.5, "y": round(rnd.uniform(0.62, 0.8), 2), "scale": 1, "hidden": False,
                       "style": rnd.choice(["card", "cover", "vinyl"]), "color": rnd.randint(0, 4),
                       "start_ms": 0, "clip_ms": 15000}
            music = jb(song_json(rnd.choice(SONGS), sticker))
            if mtype == "image":
                dur = 15000
        hours = rnd.randint(1, 20)
        # Running the seed again moves the story back to "a few hours ago".
        w(
            f"update public.stories set created_at = now() - interval '{hours} hours', "
            f"expires_at = now() + interval '7 days' where id = {q(sid)};"
        )
        w(
            "insert into public.stories (id, user_id, media_url, media_type, duration_ms, music, created_at, expires_at) "
            f"select {q(sid)}, {q(a['id'])}, {q(media)}, {q(mtype)}, {dur}, {music}, "
            f"now() - interval '{hours} hours', now() + interval '7 days' "
            f"where not exists (select 1 from public.stories where id = {q(sid)});"
        )
w("")

# ───── Notes (people) ─────
w("-- ───── Notes ─────")
for i, p in enumerate(people):
    if i % 4 == 3:
        continue
    music = jb(song_json(rnd.choice(SONGS))) if rnd.random() < 0.4 else "null"
    # One note per person: replace it (the app does the same).
    w(f"delete from public.notes where user_id = {q(p['id'])};")
    w(
        "insert into public.notes (user_id, content, music, created_at, expires_at) values "
        f"({q(p['id'])}, {q(NOTES[i % len(NOTES)])}, {music}, now() - interval '{rnd.randint(1, 10)} hours', "
        "now() + interval '7 days');"
    )

w("")
w("commit;")
open(OUT, "w", encoding="utf-8", newline="\n").write("\n".join(lines) + "\n")
print(f"{len(ACCOUNTS)} accounts, {len(all_posts)} posts, {len(follows)} follows -> {OUT}")
