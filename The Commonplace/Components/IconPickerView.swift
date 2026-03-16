import SwiftUI

// MARK: - Icon Category Definition

struct IconCategory {
    let name: String
    let icons: [String]
}

let allIconCategories: [IconCategory] = [
    IconCategory(name: "Essentials", icons: [
        "folder.fill", "star.fill", "heart.fill", "bookmark.fill",
        "tag.fill", "doc.fill", "tray.fill", "archivebox.fill",
        "pin.fill", "flag.fill", "bell.fill", "paperclip",
        "doc.text.fill", "note.text", "list.bullet", "list.bullet.clipboard.fill",
        "checklist", "tray.2.fill", "doc.on.doc.fill", "externaldrive.fill"
    ]),
    IconCategory(name: "People & Social", icons: [
        "person.fill", "person.2.fill", "person.3.fill",
        "figure.2.and.child.holdinghands", "person.crop.circle.fill",
        "hand.thumbsup.fill", "hand.wave.fill", "hands.clap.fill",
        "face.smiling.fill", "party.popper.fill", "gift.fill",
        "heart.text.square.fill", "bubble.left.fill", "message.fill",
        "envelope.fill", "phone.fill", "video.fill", "megaphone.fill"
    ]),
    IconCategory(name: "Health & Body", icons: [
        "figure.walk", "figure.run", "figure.hiking", "figure.cycling",
        "figure.swimming", "figure.yoga", "figure.strengthtraining.traditional",
        "figure.cooldown", "figure.dance", "figure.martial.arts",
        "dumbbell.fill", "heart.fill", "lungs.fill", "brain.head.profile",
        "brain", "cross.fill", "pill.fill", "staroflife.fill",
        "bandage.fill", "eye.fill", "ear.fill", "hand.raised.fill",
        "stethoscope", "syringe.fill", "thermometer.medium"
    ]),
    IconCategory(name: "Hygiene & Grooming", icons: [
        "shower.fill", "bathtub.fill", "comb.fill",
        "scissors", "hand.raised.fill", "mouth.fill",
        "nose.fill", "hands.sparkles.fill", "bubbles.and.sparkles.fill",
        "washer.fill", "wind", "allergens",
        "toothbrush.fill"
    ]),
    IconCategory(name: "Cleaning & Home", icons: [
        "house.fill", "sofa.fill", "bed.double.fill", "chair.fill",
        "door.left.hand.open", "key.fill", "lock.fill",
        "trash.fill", "trash.slash.fill", "arrow.up.bin.fill",
        "vacuum.fill", "lightbulb.fill", "lightbulb.2.fill",
        "poweroutlet.type.b.fill", "wrench.and.screwdriver.fill",
        "hammer.fill", "screwdriver.fill", "window.casement"
    ]),
    IconCategory(name: "Food & Drink", icons: [
        "fork.knife", "cup.and.saucer.fill", "mug.fill", "wineglass.fill",
        "carrot.fill", "birthday.cake.fill", "popcorn.fill",
        "takeoutbag.and.cup.and.straw.fill", "fish.fill",
        "flame.fill", "drop.fill", "leaf.fill",
        "cart.fill", "bag.fill", "basket.fill"
    ]),
    IconCategory(name: "Nature & Weather", icons: [
        "leaf.fill", "tree.fill", "flame.fill", "drop.fill",
        "snowflake", "sun.max.fill", "moon.fill", "cloud.fill",
        "cloud.rain.fill", "cloud.snow.fill", "cloud.bolt.fill",
        "wind", "tornado", "hurricane",
        "mountain.2.fill", "globe.americas.fill",
        "beach.umbrella.fill", "water.waves", "bubbles.and.sparkles"
    ]),
    IconCategory(name: "Animals & Nature", icons: [
        "pawprint.fill", "tortoise.fill", "hare.fill",
        "bird.fill", "butterfly.fill", "ant.fill",
        "lizard.fill", "fish.fill", "cat.fill", "dog.fill",
        "teddybear.fill", "ladybug.fill", "duck.fill",
        "tree.fill", "fossil.shell.fill"
    ]),
    IconCategory(name: "Art & Creativity", icons: [
        "paintbrush.fill", "paintpalette.fill", "pencil",
        "pencil.and.ruler.fill", "ruler.fill",
        "scissors", "crop", "wand.and.stars",
        "sparkles", "staroflife.fill", "scribble.variable",
        "lasso", "square.and.pencil", "signature",
        "photo.artframe", "camera.filters", "theatermasks.fill",
        "theatermask.and.paintbrush.fill"
    ]),
    IconCategory(name: "Music & Audio", icons: [
        "music.note", "music.mic", "headphones", "airpodspro",
        "speaker.wave.3.fill", "guitars.fill", "piano.fill",
        "drum.fill", "music.note.list", "waveform",
        "metronome.fill", "radio.fill", "hifispeaker.fill",
        "mic.fill", "tuningfork"
    ]),
    IconCategory(name: "Media & Entertainment", icons: [
        "photo.fill", "camera.fill", "video.fill", "film.fill",
        "play.fill", "tv.fill", "book.fill", "newspaper.fill",
        "magazine.fill", "safari.fill", "link", "antenna.radiowaves.left.and.right",
        "airplayvideo", "gamecontroller.fill", "dice.fill", "puzzlepiece.fill"
    ]),
    IconCategory(name: "Learning & Knowledge", icons: [
        "graduationcap.fill", "books.vertical.fill", "bookmark.fill",
        "text.bubble.fill", "quote.bubble.fill", "lightbulb.fill",
        "brain.head.profile", "atom", "scope", "magnifyingglass",
        "backpack.fill", "pencil.and.list.clipboard",
        "globe", "map.fill", "doc.text.magnifyingglass"
    ]),
    IconCategory(name: "Work & Productivity", icons: [
        "briefcase.fill", "chart.bar.fill", "chart.pie.fill",
        "chart.line.uptrend.xyaxis", "calendar", "clock.fill",
        "alarm.fill", "timer", "stopwatch.fill", "hourglass.fill",
        "tray.fill", "envelope.fill", "printer.fill",
        "keyboard.fill", "desktopcomputer", "laptopcomputer",
        "building.2.fill", "building.columns.fill"
    ]),
    IconCategory(name: "Buildings & Locations", icons: [
        "house.fill", "building.fill", "building.2.fill",
        "building.columns.fill", "building.2.crop.circle.fill",
        "storefront.fill", "tent.fill", "archivebox.fill",
        "mappin.circle.fill", "location.fill", "map.fill",
        "signpost.right.fill", "signpost.2.fill",
        "globe.americas.fill", "globe.europe.africa.fill",
        "globe.asia.australia.fill", "airplane.departure",
        "ferry.fill", "parkingsign", "cross.case.fill"
    ]),
    IconCategory(name: "Transport & Travel", icons: [
        "car.fill", "bus.fill", "tram.fill", "airplane",
        "bicycle", "scooter", "ferry.fill", "fuelpump.fill",
        "suitcase.fill", "suitcase.rolling.fill",
        "map.fill", "location.fill", "signpost.right.fill",
        "car.rear.fill", "bolt.car.fill", "truck.box.fill"
    ]),
    IconCategory(name: "Finance", icons: [
        "dollarsign.circle.fill", "creditcard.fill", "banknote.fill",
        "chart.line.uptrend.xyaxis", "building.columns.fill",
        "giftcard.fill", "cart.fill", "bag.fill",
        "chart.bar.fill", "chart.pie.fill", "percent",
        "arrow.up.arrow.down.circle.fill", "safe.fill"
    ]),
    IconCategory(name: "Tech & Devices", icons: [
        "laptopcomputer", "desktopcomputer", "keyboard.fill", "iphone",
        "ipad", "applewatch", "gamecontroller.fill", "cable.connector",
        "externaldrive.fill", "cpu.fill", "wifi", "network",
        "printer.fill", "scanner.fill", "tv.fill",
        "server.rack", "memorychip.fill", "opticaldisc.fill"
    ]),
    IconCategory(name: "Achievement & Goals", icons: [
        "trophy.fill", "medal.fill", "crown.fill", "seal.fill",
        "rosette", "target", "flag.fill", "flag.checkered",
        "star.fill", "star.circle.fill", "bolt.fill",
        "shield.fill", "checkmark.seal.fill", "hands.clap.fill"
    ]),
    IconCategory(name: "Symbols & Misc", icons: [
        "number", "percent", "infinity", "plus.circle.fill",
        "checkmark.circle.fill", "xmark.circle.fill",
        "exclamationmark.circle.fill", "questionmark.circle.fill",
        "arrow.right.circle.fill", "arrow.trianglehead.2.clockwise.rotate.90",
        "lock.fill", "key.fill", "wand.and.stars", "sparkles",
        "moon.stars.fill", "sun.and.horizon.fill", "rainbow"
    ])
]

// MARK: - IconPickerView

struct IconPickerView: View {
    @Binding var selectedIcon: String
    var accentColor: Color = .accentColor
    
    @State private var iconSearch = ""
    
    var filteredCategories: [IconCategory] {
        if iconSearch.isEmpty { return allIconCategories }
        let query = iconSearch.lowercased()
        return allIconCategories.compactMap { category in
            let matched = category.icons.filter {
                $0.localizedCaseInsensitiveContains(query) &&
                UIImage(systemName: $0) != nil
            }
            return matched.isEmpty ? nil : IconCategory(name: category.name, icons: matched)
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search icons...", text: $iconSearch)
                    .autocorrectionDisabled()
                if !iconSearch.isEmpty {
                    Button { iconSearch = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(uiColor: .systemGray6))
            .clipShape(Capsule())
            .padding(.horizontal, 4)
            
            // Icon grid with category headers
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(filteredCategories, id: \.name) { category in
                        // Category header
                        HStack {
                            Text(category.name.uppercased())
                                .font(.system(size: 10, weight: .semibold))
                                .kerning(0.8)
                                .foregroundStyle(.secondary)
                            Rectangle()
                                .fill(Color(uiColor: .systemGray4))
                                .frame(height: 0.5)
                        }
                        .padding(.top, 12)
                        .padding(.bottom, 6)
                        .padding(.horizontal, 4)
                        
                        // Icons
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                            ForEach(Array(category.icons.enumerated()), id: \.offset) { _, icon in
                                if UIImage(systemName: icon) != nil {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(selectedIcon == icon
                                                  ? accentColor.opacity(0.2)
                                                  : Color(uiColor: .systemGray6))
                                            .frame(height: 44)
                                        Image(systemName: icon)
                                            .font(.title3)
                                            .foregroundStyle(selectedIcon == icon ? accentColor : Color.secondary)
                                    }
                                    .onTapGesture { selectedIcon = icon }
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .padding(.vertical, 4)
                .padding(.bottom, 12)
            }
            .frame(height: 400)
        }
    }
}
