#!/usr/bin/env python3
"""Seed TrystMe demo data into the Chat/Video app and the Feeds app via the Stream CLI."""
import json
import os
import subprocess
import sys

CURRENT_USER = "alex_rivera"
CHANNEL_TYPE = "tryst"

# id, name, age, gender, looking_for, job, city, bio, interests
ROSTER = [
    ("alex_rivera", "Alex Rivera", 28, "nonbinary", "everyone", "Photographer", "San Francisco",
     "Coffee, climbing, and aggressively bad puns. Show me your dog.", ["climbing", "coffee", "film", "hiking"]),
    ("sophia_lee", "Sophia Lee", 26, "female", "men", "Product Designer", "San Francisco",
     "Designer by day, ceramics chaos by night. Looking for a partner in crime (the legal kind).", ["design", "pottery", "matcha", "vinyl"]),
    ("mia_chen", "Mia Chen", 29, "female", "everyone", "ER Doctor", "Oakland",
     "I save lives and lose at board games. Feed me dumplings and we'll get along.", ["medicine", "board games", "dumplings", "running"]),
    ("emma_johnson", "Emma Johnson", 27, "female", "men", "Pastry Chef", "Berkeley",
     "I will absolutely judge your croissant. Sourdough enthusiast & sunset chaser.", ["baking", "wine", "sunsets", "travel"]),
    ("olivia_brown", "Olivia Brown", 25, "female", "everyone", "Yoga Instructor", "San Francisco",
     "Namaste, but make it sarcastic. Beach mornings & spontaneous road trips.", ["yoga", "surfing", "meditation", "plants"]),
    ("ava_martinez", "Ava Martinez", 30, "female", "men", "Architect", "San Jose",
     "I notice your building's bad proportions. Tacos, jazz, and tall plans.", ["architecture", "jazz", "tacos", "cycling"]),
    ("isabella_garcia", "Isabella Garcia", 24, "female", "everyone", "Musician", "San Francisco",
     "Songwriter with too many half-finished demos. Let's get loud, then quiet.", ["music", "guitar", "concerts", "poetry"]),
    ("liam_smith", "Liam Smith", 31, "male", "women", "Software Engineer", "Palo Alto",
     "I debug feelings and code. Will hike anywhere with a good summit view.", ["coding", "hiking", "espresso", "chess"]),
    ("noah_williams", "Noah Williams", 28, "male", "women", "Writer", "San Francisco",
     "Novelist, dog dad, terrible dancer. Bookstores are my love language.", ["writing", "books", "dogs", "coffee"]),
    ("ethan_davis", "Ethan Davis", 29, "male", "everyone", "Founder", "San Francisco",
     "Building something I can't talk about yet. Climbing, ramen, and big questions.", ["startups", "climbing", "ramen", "running"]),
    ("lucas_wilson", "Lucas Wilson", 27, "male", "women", "Teacher", "Oakland",
     "5th grade teacher with the patience of a saint and the jokes of a 5th grader.", ["teaching", "basketball", "guitar", "camping"]),
    ("mason_taylor", "Mason Taylor", 32, "male", "everyone", "Creative Director", "San Francisco",
     "Designer, surfer, amateur barista. I make a mean flat white.", ["design", "surfing", "coffee", "photography"]),
    ("zoe_anderson", "Zoe Anderson", 26, "female", "everyone", "Marine Biologist", "Santa Cruz",
     "I talk to octopuses professionally. Tide pools, tattoos, and true crime.", ["ocean", "diving", "tattoos", "podcasts"]),
]

CHAT_ENV = {
    "STREAM_API_KEY": os.environ["STREAM_API_KEY"],
    "STREAM_API_SECRET": os.environ["STREAM_API_SECRET"],
}
FEEDS_ENV = {
    "STREAM_API_KEY": os.environ["STREAM_FEEDS_API_KEY"],
    "STREAM_API_SECRET": os.environ["STREAM_FEEDS_API_SECRET"],
}


def avatar(uid):
    return f"https://i.pravatar.cc/400?u={uid}"


def photos(uid):
    return [f"https://picsum.photos/seed/{uid}{i}/600/800" for i in range(1, 4)]


def call(endpoint, env, body=None, path_args=None):
    cmd = ["stream", "api", endpoint, "-o", "json"]
    if path_args:
        for k, v in path_args.items():
            cmd.append(f"{k}={v}")
    if body is not None:
        cmd += ["--body", json.dumps(body)]
    full_env = dict(os.environ)
    full_env.update(env)
    res = subprocess.run(cmd, capture_output=True, text=True, env=full_env)
    if res.returncode != 0:
        print(f"  ! {endpoint} failed: {res.stderr.strip()[:200]}")
        return None
    return res.stdout


def user_obj(rec):
    uid, name, age, gender, looking, job, city, bio, interests = rec
    return {
        "id": uid,
        "name": name,
        "image": avatar(uid),
        "custom": {
            "bio": bio, "age": age, "gender": gender, "looking_for": looking,
            "job": job, "city": city, "interests": interests, "photos": photos(uid),
        },
    }


def seed_chat_users():
    print("Seeding chat/video users...")
    users = {rec[0]: user_obj(rec) for rec in ROSTER}
    call("UpdateUsers", CHAT_ENV, body={"users": users})
    print(f"  upserted {len(users)} users on chat app")


def seed_feeds_users():
    print("Seeding feeds users...")
    users = {rec[0]: user_obj(rec) for rec in ROSTER}
    call("UpdateUsers", FEEDS_ENV, body={"users": users})
    print(f"  upserted {len(users)} users on feeds app")


# (other_user_id, [ (sender_id, text), ... ])
MATCHES = [
    ("sophia_lee", [
        ("sophia_lee", "Okay your dog photo sealed the deal 😄"),
        ("alex_rivera", "He's the real catch, I'm just his manager."),
        ("sophia_lee", "Coffee this weekend? I know a place with terrible art and great espresso."),
    ]),
    ("mia_chen", [
        ("mia_chen", "Dumpling crawl. You in?"),
        ("alex_rivera", "I was born ready. Loser pays?"),
        ("mia_chen", "You're going down 🥟"),
    ]),
    ("emma_johnson", [
        ("emma_johnson", "I made too many croissants again. Emergency."),
        ("alex_rivera", "I'm a trained professional. Send location."),
    ]),
    ("olivia_brown", [
        ("olivia_brown", "Sunrise yoga on the beach Saturday?"),
        ("alex_rivera", "If 'sunrise' can mean 9am, absolutely."),
    ]),
]


def seed_channels():
    print("Seeding match channels + messages...")
    for other, msgs in MATCHES:
        cid = f"match-{CURRENT_USER}-{other}"
        other_name = next(r[1] for r in ROSTER if r[0] == other)
        call("GetOrCreateChannel", CHAT_ENV,
             path_args={"type": CHANNEL_TYPE, "id": cid},
             body={"data": {"members": [CURRENT_USER, other],
                            "created_by_id": CURRENT_USER},
                   })
        for sender, text in msgs:
            call("SendMessage", CHAT_ENV,
                 path_args={"type": CHANNEL_TYPE, "id": cid},
                 body={"message": {"text": text, "user_id": sender}})
        print(f"  match with {other_name}: {len(msgs)} messages")


POSTS = [
    ("sophia_lee", "Finally fired my first batch of mugs that didn't explode. Growth. 🏺"),
    ("mia_chen", "36-hour shift done. Reward: the largest bowl of ramen known to science."),
    ("emma_johnson", "New laminated dough technique unlocked. 81 layers of pure chaos. 🥐"),
    ("olivia_brown", "Caught the sunrise mid-handstand today. The ocean said hi back. 🌊"),
    ("isabella_garcia", "Wrote a song about a bad date. It's a banger. You're welcome."),
    ("liam_smith", "Summited at 6am, back at my desk by 9. Optimization is a lifestyle."),
    ("noah_williams", "Chapter 12 fought me for a week. I won. Barely. ✍️"),
    ("ethan_davis", "Two failed prototypes, one good idea. Net positive day."),
    ("zoe_anderson", "An octopus changed color when it saw me today. We're basically dating now. 🐙"),
    ("ava_martinez", "Sketched a cantilever over tacos. Both turned out structurally sound."),
    ("alex_rivera", "Golden hour on the bridge again. Never gets old. 📷"),
]


def seed_activities():
    print("Seeding feed posts...")
    for uid, text in POSTS:
        call("AddActivity", FEEDS_ENV,
             body={"type": "post", "text": text, "user_id": uid,
                   "feeds": [f"user:{uid}"], "create_users": True})
    print(f"  added {len(POSTS)} posts")


def seed_follows():
    print("Seeding follow graph...")
    # current user's timeline follows these users
    following = ["sophia_lee", "mia_chen", "isabella_garcia", "noah_williams", "zoe_anderson", "ethan_davis"]
    for t in following:
        call("Follow", FEEDS_ENV,
             body={"source": f"timeline:{CURRENT_USER}", "target": f"user:{t}",
                   "create_users": True, "create_notification_activity": True})
    # these users follow the current user
    followers = ["emma_johnson", "olivia_brown", "liam_smith", "lucas_wilson"]
    for f in followers:
        call("Follow", FEEDS_ENV,
             body={"source": f"timeline:{f}", "target": f"user:{CURRENT_USER}",
                   "create_users": True, "create_notification_activity": True})
    print(f"  {CURRENT_USER} follows {len(following)}, followed by {len(followers)}")


if __name__ == "__main__":
    seed_chat_users()
    seed_feeds_users()
    seed_channels()
    seed_activities()
    seed_follows()
    print("\nSeeding complete.")
