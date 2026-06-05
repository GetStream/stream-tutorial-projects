//
//  Profile.swift
//  TrystMe
//
//  Plain, framework-agnostic models. No Stream imports so any view or service
//  can pass these around freely (the SDK collision rules only bite when two
//  Stream SwiftUI modules are imported in the same file).
//

import Foundation

struct Profile: Identifiable, Hashable {
    let id: String
    let name: String
    let age: Int
    let gender: String
    let lookingFor: String
    let job: String
    let city: String
    let bio: String
    let interests: [String]
    let photos: [URL]
    let avatarURL: URL

    var firstName: String { name.split(separator: " ").first.map(String.init) ?? name }

    /// Real, gender-matched human portraits (Unsplash) keyed by user id. Keeps the
    /// same face across the avatar, the swipe card and the full profile.
    static let unsplashFaces: [String: String] = [
        "alex_rivera": "1507591064344-4c6ce005b128",
        "sophia_lee": "1494790108377-be9c29b29330",
        "mia_chen": "1517841905240-472988babdf9",
        "emma_johnson": "1438761681033-6461ffad8d80",
        "olivia_brown": "1531746020798-e6953c6e8e04",
        "ava_martinez": "1534528741775-53994a69daeb",
        "isabella_garcia": "1524504388940-b1c1722653e1",
        "zoe_anderson": "1487412720507-e7ab37603c6f",
        "liam_smith": "1500648767791-00dcc994a43e",
        "noah_williams": "1507003211169-0a1dd7228f2d",
        "ethan_davis": "1506794778202-cad84cf45f1d",
        "lucas_wilson": "1519345182560-3f2917c472ef",
        "mason_taylor": "1488161628813-04466f872be2",
    ]

    /// Square, face-cropped avatar for lists and chat.
    static func avatar(for id: String) -> URL {
        if let pid = unsplashFaces[id] {
            return URL(string: "https://images.unsplash.com/photo-\(pid)?w=400&h=400&fit=crop&crop=faces&q=70")!
        }
        return URL(string: "https://i.pravatar.cc/400?u=\(id)")!
    }

    /// Tall, face-cropped portrait for swipe cards and the profile carousel.
    static func photos(for id: String) -> [URL] {
        if let pid = unsplashFaces[id] {
            return [URL(string: "https://images.unsplash.com/photo-\(pid)?w=900&h=1200&fit=crop&crop=faces&q=80")!]
        }
        return [URL(string: "https://i.pravatar.cc/800?u=\(id)")!]
    }
}

/// The seeded roster, mirrored locally so Discover renders instantly without a
/// round-trip. The same users exist on both Stream apps (Chat/Video + Feeds).
enum Roster {
    static let currentUserId = "alex_rivera"

    static let all: [Profile] = [
        make("alex_rivera", "Alex Rivera", 28, "nonbinary", "everyone", "Photographer", "San Francisco",
             "Coffee, climbing, and aggressively bad puns. Show me your dog.", ["climbing", "coffee", "film", "hiking"]),
        make("sophia_lee", "Sophia Lee", 26, "female", "men", "Product Designer", "San Francisco",
             "Designer by day, ceramics chaos by night. Looking for a partner in crime (the legal kind).", ["design", "pottery", "matcha", "vinyl"]),
        make("mia_chen", "Mia Chen", 29, "female", "everyone", "ER Doctor", "Oakland",
             "I save lives and lose at board games. Feed me dumplings and we'll get along.", ["medicine", "board games", "dumplings", "running"]),
        make("emma_johnson", "Emma Johnson", 27, "female", "men", "Pastry Chef", "Berkeley",
             "I will absolutely judge your croissant. Sourdough enthusiast & sunset chaser.", ["baking", "wine", "sunsets", "travel"]),
        make("olivia_brown", "Olivia Brown", 25, "female", "everyone", "Yoga Instructor", "San Francisco",
             "Namaste, but make it sarcastic. Beach mornings & spontaneous road trips.", ["yoga", "surfing", "meditation", "plants"]),
        make("ava_martinez", "Ava Martinez", 30, "female", "men", "Architect", "San Jose",
             "I notice your building's bad proportions. Tacos, jazz, and tall plans.", ["architecture", "jazz", "tacos", "cycling"]),
        make("isabella_garcia", "Isabella Garcia", 24, "female", "everyone", "Musician", "San Francisco",
             "Songwriter with too many half-finished demos. Let's get loud, then quiet.", ["music", "guitar", "concerts", "poetry"]),
        make("liam_smith", "Liam Smith", 31, "male", "women", "Software Engineer", "Palo Alto",
             "I debug feelings and code. Will hike anywhere with a good summit view.", ["coding", "hiking", "espresso", "chess"]),
        make("noah_williams", "Noah Williams", 28, "male", "women", "Writer", "San Francisco",
             "Novelist, dog dad, terrible dancer. Bookstores are my love language.", ["writing", "books", "dogs", "coffee"]),
        make("ethan_davis", "Ethan Davis", 29, "male", "everyone", "Founder", "San Francisco",
             "Building something I can't talk about yet. Climbing, ramen, and big questions.", ["startups", "climbing", "ramen", "running"]),
        make("lucas_wilson", "Lucas Wilson", 27, "male", "women", "Teacher", "Oakland",
             "5th grade teacher with the patience of a saint and the jokes of a 5th grader.", ["teaching", "basketball", "guitar", "camping"]),
        make("mason_taylor", "Mason Taylor", 32, "male", "everyone", "Creative Director", "San Francisco",
             "Designer, surfer, amateur barista. I make a mean flat white.", ["design", "surfing", "coffee", "photography"]),
        make("zoe_anderson", "Zoe Anderson", 26, "female", "everyone", "Marine Biologist", "Santa Cruz",
             "I talk to octopuses professionally. Tide pools, tattoos, and true crime.", ["ocean", "diving", "tattoos", "podcasts"]),
    ]

    static let byId: [String: Profile] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    static func profile(_ id: String) -> Profile? { byId[id] }

    /// Users who already DM the current user (seeded conversations) — instant matches.
    static let seededMatches = ["sophia_lee", "mia_chen", "emma_johnson", "olivia_brown"]

    /// People who will "like you back" — swiping right triggers an instant match.
    static let likesYouBack: Set<String> = [
        "sophia_lee", "mia_chen", "emma_johnson", "olivia_brown", "isabella_garcia", "zoe_anderson",
    ]

    private static func make(_ id: String, _ name: String, _ age: Int, _ gender: String,
                             _ lookingFor: String, _ job: String, _ city: String,
                             _ bio: String, _ interests: [String]) -> Profile {
        Profile(id: id, name: name, age: age, gender: gender, lookingFor: lookingFor,
                job: job, city: city, bio: bio, interests: interests,
                photos: Profile.photos(for: id), avatarURL: Profile.avatar(for: id))
    }
}
