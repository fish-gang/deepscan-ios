import SwiftUI

// Static reference data for every species the on-device classifier can
// produce. Looked up by scientific name (binomial, case-insensitive) so
// ResultsView can show a friendly common name plus background details on
// top of the bare model output. `unknown_fish` / `no_fish` deliberately
// have no entry — ResultsView already routes those through its empty state.
struct FishSpecies {
    let scientificName: String
    let commonName: String
    let emoji: String
    // Asset-catalog name of a reference illustration, shown swimming in the
    // results "porthole" so the user can compare it against their photo.
    // nil when we don't have artwork for the species yet (falls back to the
    // emoji-only title with no porthole).
    let illustration: String?
    let family: String
    let origin: String
    let howToSpot: String
    let special: String
    let funFact: String

    static func lookup(scientificName: String) -> FishSpecies? {
        database[scientificName.lowercased()]
    }

    static let database: [String: FishSpecies] = [
        "acanthurus coeruleus": FishSpecies(
            scientificName: "Acanthurus coeruleus",
            commonName: "Atlantic Blue Tang",
            emoji: "🐟",
            illustration: "fish_bluetang",
            family: "Acanthuridae · Surgeonfishes",
            origin: "Western Atlantic & Caribbean reefs",
            howToSpot: "Solid powder-blue, oval body with a small pointed snout.",
            special: "Razor-sharp 'scalpels' near the tail give the surgeonfish family its name.",
            funFact: "Juveniles are bright yellow and slowly turn deep blue as they grow up."
        ),
        "amphiprion ocellaris": FishSpecies(
            scientificName: "Amphiprion ocellaris",
            commonName: "Ocellaris Clownfish",
            emoji: "🐠",
            illustration: "fish_clownfish",
            family: "Pomacentridae · Damselfishes",
            origin: "Indo-Pacific reefs, Andaman Sea to Japan",
            howToSpot: "Bright orange body with three thick white bands edged in black.",
            special: "Immune to anemone stings — its skin mucus protects it as it shelters inside.",
            funFact: "Made famous by Finding Nemo — and every clownfish is born male."
        ),
        "arothron meleagris": FishSpecies(
            scientificName: "Arothron meleagris",
            commonName: "Guineafowl Pufferfish",
            emoji: "🐡",
            illustration: "fish_pufferfish",
            family: "Tetraodontidae · Pufferfishes",
            origin: "Tropical Indo-Pacific & Eastern Pacific",
            howToSpot: "Dark body covered in dense white polka dots, like guineafowl plumage.",
            special: "Inflates into a spiky ball when threatened; fused teeth form a beak that cracks coral.",
            funFact: "Carries tetrodotoxin — over 1,000× more potent than cyanide."
        ),
        "carcharhinus melanopterus": FishSpecies(
            scientificName: "Carcharhinus melanopterus",
            commonName: "Blacktip Reef Shark",
            emoji: "🦈",
            illustration: "fish_reefshark",
            family: "Carcharhinidae · Requiem Sharks",
            origin: "Indo-Pacific coastlines & shallow reefs",
            howToSpot: "Sleek gray body with unmistakable jet-black fin tips.",
            special: "A perfectly adapted shallow-water hunter, but rarely a threat to humans.",
            funFact: "Juveniles are often spotted patrolling water just ankle-deep."
        ),
        "chaetodon lunula": FishSpecies(
            scientificName: "Chaetodon lunula",
            commonName: "Raccoon Butterflyfish",
            emoji: "🦋",
            illustration: "fish_butterflyfish",
            family: "Chaetodontidae · Butterflyfishes",
            origin: "Indo-Pacific, from Hawaii to East Africa",
            howToSpot: "Yellow body with a black 'raccoon mask' across the eyes.",
            special: "Long beak-like snout picks tiny invertebrates from coral crevices.",
            funFact: "Mates for life — you'll almost always see them swimming as a pair."
        ),
        "chromis viridis": FishSpecies(
            scientificName: "Chromis viridis",
            commonName: "Blue-Green Chromis",
            emoji: "✨",
            illustration: "fish_chromis",
            family: "Pomacentridae · Damselfishes",
            origin: "Indo-Pacific coral reefs",
            howToSpot: "Tiny, slender fish with an iridescent blue-green sheen.",
            special: "Males turn yellow during courtship and fiercely guard their eggs.",
            funFact: "Forms shimmering schools that look like underwater confetti."
        ),
        "naso unicornis": FishSpecies(
            scientificName: "Naso unicornis",
            commonName: "Bluespine Unicornfish",
            emoji: "🦄",
            illustration: "fish_unicornfish",
            family: "Acanthuridae · Surgeonfishes",
            origin: "Indo-Pacific, Africa to Hawaii",
            howToSpot: "Olive-gray body with a long horn projecting from the forehead.",
            special: "Bright blue spines near the tail flare out as a warning.",
            funFact: "Grows its forehead 'horn' as it matures — its purpose is still debated."
        ),
        "pomacanthus imperator": FishSpecies(
            scientificName: "Pomacanthus imperator",
            commonName: "Emperor Angelfish",
            emoji: "👑",
            illustration: "fish_angelfish",
            family: "Pomacanthidae · Marine Angelfishes",
            origin: "Indo-Pacific reefs",
            howToSpot: "Electric blue and yellow horizontal stripes with a black face mask.",
            special: "Widely considered one of the most beautiful reef fish in the world.",
            funFact: "Juveniles look like a different species — dark blue with white spirals."
        ),
        "pterois volitans": FishSpecies(
            scientificName: "Pterois volitans",
            commonName: "Red Lionfish",
            emoji: "🦁",
            illustration: "fish_lionfish",
            family: "Scorpaenidae · Scorpionfishes",
            origin: "Native to the Indo-Pacific; invasive in the Atlantic",
            howToSpot: "Bold red-and-white zebra stripes with feathery, fan-shaped fins.",
            special: "Hovers motionless before vacuuming prey in with a lightning-fast gulp.",
            funFact: "Carries up to 18 venomous spines — the sting is painful but rarely fatal."
        ),
        "rhinecanthus aculeatus": FishSpecies(
            scientificName: "Rhinecanthus aculeatus",
            commonName: "Lagoon (Picasso) Triggerfish",
            emoji: "🎨",
            illustration: nil,
            family: "Balistidae · Triggerfishes",
            origin: "Indo-Pacific lagoons & shallow reefs",
            howToSpot: "Bold geometric pattern: yellow, black, and blue stripes around the eyes.",
            special: "Locks into coral crevices with a trigger-like dorsal spine for safety.",
            funFact: "Hawaii's state fish — 'humuhumunukunukuāpuaʻa'."
        ),
        "scarus ghobban": FishSpecies(
            scientificName: "Scarus ghobban",
            commonName: "Blue-Barred Parrotfish",
            emoji: "🦜",
            illustration: nil,
            family: "Scaridae · Parrotfishes",
            origin: "Indo-Pacific, Africa to the Eastern Pacific",
            howToSpot: "Pastel blue with yellow scales and a fused, beak-like mouth.",
            special: "Sleeps inside a self-made mucus bubble that masks its scent from predators.",
            funFact: "A single parrotfish can produce hundreds of pounds of white sand per year."
        ),
        "thalassoma lunare": FishSpecies(
            scientificName: "Thalassoma lunare",
            commonName: "Moon Wrasse",
            emoji: "🌙",
            illustration: "fish_moonwrasse",
            family: "Labridae · Wrasses",
            origin: "Indo-Pacific coral reefs",
            howToSpot: "Bright green body with a glowing crescent-moon-shaped yellow tail.",
            special: "Active by day; buries itself in sand to sleep at night.",
            funFact: "Can change sex from female to male as it matures."
        ),
    ]
}
