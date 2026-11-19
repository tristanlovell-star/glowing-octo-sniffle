import Foundation

/// The overall shape the car's body is built from.
enum BodyStyle: String, Codable {
    case coupe        // long bonnet, 2+2 (GR86, Mustang, Supra, Z)
    case roadster     // small two-seater (MX-5)
    case rearEngine   // sloping fastback (911)
    case midEngine    // short nose, long rear deck (Corvette, Ferrari, Lamborghini)
    case hatch        // GR Yaris, Golf R, Civic Type R
    case sedan        // Model 3, M3
    case suv          // Ioniq 5 N
    case ute          // Ranger Raptor
}

enum Drive: String, Codable {
    case rwd = "RWD", fwd = "FWD", awd = "AWD"
}

enum PaintFinish: String, Codable {
    case solid, metallic, pearl, matte, chrome
}

struct RGB: Codable, Hashable {
    var r: Double, g: Double, b: Double
    init(_ hex: UInt32) {
        r = Double((hex >> 16) & 0xFF) / 255
        g = Double((hex >> 8) & 0xFF) / 255
        b = Double(hex & 0xFF) / 255
    }
}

struct Paint: Codable, Hashable, Identifiable {
    var name: String
    var color: RGB
    var finish: PaintFinish
    var id: String { name }

    init(_ name: String, _ hex: UInt32, _ finish: PaintFinish = .metallic) {
        self.name = name
        self.color = RGB(hex)
        self.finish = finish
    }
}

/// A trim level: changes how the car performs and, a little, how it looks.
struct Trim: Codable, Hashable, Identifiable {
    var name: String
    var powerKW: Double
    var massKg: Double
    var topSpeedKmh: Double
    var drive: Drive
    /// Tyre grip, roughly in g. Road tyres ~0.95, track tyres ~1.15.
    var grip: Double
    /// Factory rear wing on this trim.
    var factoryWing: Bool = false
    var id: String { name }
}

struct CarModel: Identifiable, Hashable {
    var id: String
    var make: String
    var model: String
    var style: BodyStyle
    var lengthM: Double
    var widthM: Double
    var heightM: Double
    var wheelbaseM: Double
    var groundClearanceM: Double = 0.12
    var trims: [Trim]
    var paints: [Paint]
    var defaultWheelInches: Int

    var displayName: String { "\(make) \(model)" }
}

enum WheelStyle: String, Codable, CaseIterable, Identifiable {
    case fiveSpoke = "5-Spoke"
    case tenSpoke = "10-Spoke"
    case mesh = "Mesh"
    case turbine = "Turbine"
    case rally = "Rally Dish"
    case yspoke = "Y-Spoke"
    var id: String { rawValue }
}

enum WheelFinish: String, Codable, CaseIterable, Identifiable {
    case silver = "Silver"
    case gloss = "Gloss Black"
    case gunmetal = "Gunmetal"
    case bronze = "Bronze"
    case gold = "Gold"
    case chrome = "Chrome"
    case white = "White"
    case body = "Body Colour"
    var id: String { rawValue }
}

enum CaliperColor: String, Codable, CaseIterable, Identifiable {
    case red = "Red", yellow = "Yellow", blue = "Blue", green = "Green", orange = "Orange", black = "Black", silver = "Silver"
    var id: String { rawValue }
    var rgb: RGB {
        switch self {
        case .red: return RGB(0xD01818)
        case .yellow: return RGB(0xF2C200)
        case .blue: return RGB(0x1E5BD8)
        case .green: return RGB(0x2FA84F)
        case .orange: return RGB(0xF06A10)
        case .black: return RGB(0x161616)
        case .silver: return RGB(0xB8BCC2)
        }
    }
}

enum StripeStyle: String, Codable, CaseIterable, Identifiable {
    case none = "None"
    case racing = "Twin Racing"
    case centre = "Centre"
    case side = "Side"
    var id: String { rawValue }
}

enum AccentColor: String, Codable, CaseIterable, Identifiable {
    case white = "White", black = "Black", red = "Red", gold = "Gold", silver = "Silver", blue = "Blue", orange = "Orange", green = "Green"
    var id: String { rawValue }
    var rgb: RGB {
        switch self {
        case .white: return RGB(0xF4F4F4)
        case .black: return RGB(0x141414)
        case .red: return RGB(0xC8102E)
        case .gold: return RGB(0xC9A227)
        case .silver: return RGB(0xA9AEB4)
        case .blue: return RGB(0x1F4FB8)
        case .orange: return RGB(0xF26B1D)
        case .green: return RGB(0x1E8C45)
        }
    }
}

enum RoofStyle: String, Codable, CaseIterable, Identifiable {
    case body = "Body Colour"
    case black = "Black"
    case carbon = "Carbon"
    var id: String { rawValue }
}

enum WingStyle: String, Codable, CaseIterable, Identifiable {
    case factory = "Factory"
    case none = "None"
    case lip = "Ducktail"
    case gt = "GT Wing"
    var id: String { rawValue }
}

/// Fun colours available on every car.
let specialPaints: [Paint] = [
    Paint("Chrome", 0xD9DDE2, .chrome),
    Paint("Gold Rush", 0xD4A62A, .chrome),
    Paint("Lime Time", 0x8BE000, .pearl),
    Paint("Hot Pink", 0xFF3EA5, .pearl),
    Paint("Purple Flake", 0x6A2BD9, .metallic),
    Paint("Matte Black", 0x1A1A1A, .matte),
    Paint("Matte Army", 0x4B5320, .matte),
    Paint("Electric Teal", 0x00B3B3, .pearl),
]

enum CarCatalog {
    static let all: [CarModel] = [
        CarModel(id: "gr86", make: "Toyota", model: "GR86", style: .coupe,
                 lengthM: 4.265, widthM: 1.775, heightM: 1.31, wheelbaseM: 2.575,
                 trims: [
                    Trim(name: "GR86", powerKW: 174, massKg: 1270, topSpeedKmh: 226, drive: .rwd, grip: 0.95),
                    Trim(name: "GR86 GTS", powerKW: 174, massKg: 1290, topSpeedKmh: 226, drive: .rwd, grip: 1.00, factoryWing: true),
                 ],
                 paints: [Paint("Ignition Red", 0xB5121B), Paint("Neptune Blue", 0x1D4F91), Paint("Ice Silver", 0xC4C8CC),
                          Paint("Halo White", 0xF2F2EE, .pearl), Paint("Crystal Black", 0x0E0E10), Paint("Track bRED", 0xD2232A, .solid)],
                 defaultWheelInches: 18),
        CarModel(id: "mx5", make: "Mazda", model: "MX-5", style: .roadster,
                 lengthM: 3.915, widthM: 1.735, heightM: 1.235, wheelbaseM: 2.31,
                 trims: [
                    Trim(name: "1.5 Roadster", powerKW: 97, massKg: 1010, topSpeedKmh: 204, drive: .rwd, grip: 0.92),
                    Trim(name: "2.0 GT", powerKW: 135, massKg: 1060, topSpeedKmh: 219, drive: .rwd, grip: 0.95),
                    Trim(name: "2.0 GT RS", powerKW: 135, massKg: 1055, topSpeedKmh: 219, drive: .rwd, grip: 1.02),
                 ],
                 paints: [Paint("Soul Red Crystal", 0xA3111C, .pearl), Paint("Zircon Sand", 0xC9BFA5), Paint("Machine Grey", 0x5D6166),
                          Paint("Deep Crystal Blue", 0x1B2A45), Paint("Snowflake White", 0xF1F0EA, .pearl), Paint("Jet Black", 0x101010)],
                 defaultWheelInches: 17),
        CarModel(id: "911", make: "Porsche", model: "911", style: .rearEngine,
                 lengthM: 4.54, widthM: 1.85, heightM: 1.30, wheelbaseM: 2.45,
                 trims: [
                    Trim(name: "Carrera", powerKW: 290, massKg: 1505, topSpeedKmh: 294, drive: .rwd, grip: 1.02),
                    Trim(name: "Carrera GTS", powerKW: 398, massKg: 1595, topSpeedKmh: 312, drive: .rwd, grip: 1.07),
                    Trim(name: "Turbo S", powerKW: 523, massKg: 1715, topSpeedKmh: 322, drive: .awd, grip: 1.10),
                    Trim(name: "GT3", powerKW: 375, massKg: 1420, topSpeedKmh: 311, drive: .rwd, grip: 1.18, factoryWing: true),
                 ],
                 paints: [Paint("Guards Red", 0xC4161C, .solid), Paint("Shark Blue", 0x1C64C8, .solid), Paint("Python Green", 0x55B84A, .solid),
                          Paint("GT Silver", 0xB3B6B8), Paint("Lava Orange", 0xE65A12, .solid), Paint("Carrara White", 0xEDEDE8), Paint("Jet Black", 0x0D0D0F)],
                 defaultWheelInches: 20),
        CarModel(id: "mustang", make: "Ford", model: "Mustang", style: .coupe,
                 lengthM: 4.81, widthM: 1.92, heightM: 1.40, wheelbaseM: 2.72,
                 trims: [
                    Trim(name: "GT", powerKW: 339, massKg: 1800, topSpeedKmh: 250, drive: .rwd, grip: 0.98),
                    Trim(name: "Dark Horse", powerKW: 373, massKg: 1830, topSpeedKmh: 270, drive: .rwd, grip: 1.05, factoryWing: true),
                 ],
                 paints: [Paint("Race Red", 0xC8102E, .solid), Paint("Grabber Blue", 0x0B6DD6, .solid), Paint("Yellow Splash", 0xF5D10A, .solid),
                          Paint("Vapor Blue", 0x8EA3B4), Paint("Eruption Green", 0x35513D), Paint("Oxford White", 0xF3F3F1, .solid), Paint("Shadow Black", 0x111214)],
                 defaultWheelInches: 19),
        CarModel(id: "corvette", make: "Chevrolet", model: "Corvette", style: .midEngine,
                 lengthM: 4.63, widthM: 1.93, heightM: 1.23, wheelbaseM: 2.72,
                 trims: [
                    Trim(name: "Stingray", powerKW: 369, massKg: 1655, topSpeedKmh: 312, drive: .rwd, grip: 1.05),
                    Trim(name: "E-Ray", powerKW: 488, massKg: 1750, topSpeedKmh: 296, drive: .awd, grip: 1.08),
                    Trim(name: "Z06", powerKW: 500, massKg: 1660, topSpeedKmh: 315, drive: .rwd, grip: 1.15, factoryWing: true),
                 ],
                 paints: [Paint("Torch Red", 0xC8151B, .solid), Paint("Rapid Blue", 0x1072C9), Paint("Accelerate Yellow", 0xF3C300),
                          Paint("Amplify Orange", 0xE8551B), Paint("Hypersonic Grey", 0x6B6F74), Paint("Arctic White", 0xF4F4F2, .solid), Paint("Black", 0x0E0E0E)],
                 defaultWheelInches: 20),
        CarModel(id: "gryaris", make: "Toyota", model: "GR Yaris", style: .hatch,
                 lengthM: 3.995, widthM: 1.805, heightM: 1.455, wheelbaseM: 2.56,
                 trims: [
                    Trim(name: "GR Yaris", powerKW: 224, massKg: 1280, topSpeedKmh: 230, drive: .awd, grip: 1.00),
                    Trim(name: "Rallye", powerKW: 224, massKg: 1280, topSpeedKmh: 230, drive: .awd, grip: 1.05),
                 ],
                 paints: [Paint("Emotional Red", 0xB01020, .pearl), Paint("Frosted White", 0xF0F0EC, .pearl), Paint("Precious Black", 0x111111),
                          Paint("Gravity Grey", 0x4C4F54), Paint("Precious Metal", 0x8A8D90)],
                 defaultWheelInches: 18),
        CarModel(id: "typer", make: "Honda", model: "Civic Type R", style: .hatch,
                 lengthM: 4.595, widthM: 1.89, heightM: 1.405, wheelbaseM: 2.735,
                 trims: [
                    Trim(name: "Type R", powerKW: 235, massKg: 1430, topSpeedKmh: 275, drive: .fwd, grip: 1.05, factoryWing: true),
                 ],
                 paints: [Paint("Championship White", 0xF5F5F2, .solid), Paint("Rallye Red", 0xC8102E, .solid), Paint("Boost Blue", 0x2E5CC6, .pearl),
                          Paint("Sonic Grey", 0x8E9399, .pearl), Paint("Crystal Black", 0x0F1012, .pearl)],
                 defaultWheelInches: 19),
        CarModel(id: "golfr", make: "Volkswagen", model: "Golf R", style: .hatch,
                 lengthM: 4.29, widthM: 1.79, heightM: 1.46, wheelbaseM: 2.63,
                 trims: [
                    Trim(name: "Golf R", powerKW: 245, massKg: 1550, topSpeedKmh: 250, drive: .awd, grip: 1.00),
                    Trim(name: "Golf R Black Edition", powerKW: 245, massKg: 1550, topSpeedKmh: 270, drive: .awd, grip: 1.02),
                 ],
                 paints: [Paint("Lapiz Blue", 0x1E50B4), Paint("Kings Red", 0xA3121E), Paint("Pure White", 0xF2F2F0, .solid),
                          Paint("Moonstone Grey", 0x7A7F84, .solid), Paint("Deep Black", 0x0F0F12, .pearl)],
                 defaultWheelInches: 19),
        CarModel(id: "m3", make: "BMW", model: "M3", style: .sedan,
                 lengthM: 4.80, widthM: 1.90, heightM: 1.43, wheelbaseM: 2.86,
                 trims: [
                    Trim(name: "Competition", powerKW: 390, massKg: 1730, topSpeedKmh: 290, drive: .awd, grip: 1.06),
                    Trim(name: "CS", powerKW: 405, massKg: 1765, topSpeedKmh: 302, drive: .awd, grip: 1.12),
                 ],
                 paints: [Paint("Isle of Man Green", 0x0F5A3C), Paint("São Paulo Yellow", 0xF2C70A, .solid), Paint("Toronto Red", 0xA6121F),
                          Paint("Portimão Blue", 0x1748A0), Paint("Brooklyn Grey", 0x8B9094, .solid), Paint("Frozen Black", 0x202124, .matte)],
                 defaultWheelInches: 19),
        CarModel(id: "model3", make: "Tesla", model: "Model 3", style: .sedan,
                 lengthM: 4.72, widthM: 1.85, heightM: 1.44, wheelbaseM: 2.875,
                 trims: [
                    Trim(name: "Rear-Wheel Drive", powerKW: 208, massKg: 1765, topSpeedKmh: 201, drive: .rwd, grip: 0.92),
                    Trim(name: "Long Range", powerKW: 366, massKg: 1830, topSpeedKmh: 201, drive: .awd, grip: 0.95),
                    Trim(name: "Performance", powerKW: 460, massKg: 1836, topSpeedKmh: 262, drive: .awd, grip: 1.03, factoryWing: true),
                 ],
                 paints: [Paint("Ultra Red", 0xB0101C, .pearl), Paint("Pearl White", 0xF3F3F0, .pearl), Paint("Stealth Grey", 0x45484C),
                          Paint("Quicksilver", 0xB7BBBF), Paint("Deep Blue", 0x1B3B78), Paint("Diamond Black", 0x0C0C0E)],
                 defaultWheelInches: 19),
        CarModel(id: "ioniq5n", make: "Hyundai", model: "Ioniq 5 N", style: .suv,
                 lengthM: 4.715, widthM: 1.94, heightM: 1.585, wheelbaseM: 3.0, groundClearanceM: 0.15,
                 trims: [
                    Trim(name: "Ioniq 5 N", powerKW: 478, massKg: 2200, topSpeedKmh: 260, drive: .awd, grip: 1.02),
                 ],
                 paints: [Paint("Performance Blue", 0x2A6FD6, .matte), Paint("Soultronic Orange", 0xE0571B, .pearl), Paint("Atlas White", 0xF2F2F0, .solid),
                          Paint("Abyss Black", 0x0E0F12, .pearl), Paint("Gravity Gold", 0x8C7A55, .matte), Paint("Cyber Grey", 0x5C6066)],
                 defaultWheelInches: 21),
        CarModel(id: "raptor", make: "Ford", model: "Ranger Raptor", style: .ute,
                 lengthM: 5.36, widthM: 2.03, heightM: 1.93, wheelbaseM: 3.27, groundClearanceM: 0.28,
                 trims: [
                    Trim(name: "Raptor", powerKW: 292, massKg: 2475, topSpeedKmh: 180, drive: .awd, grip: 0.85),
                 ],
                 paints: [Paint("Code Orange", 0xEF6C1A, .solid), Paint("Conquer Grey", 0x6D7276, .solid), Paint("Blue Lightning", 0x1E4FA8),
                          Paint("Arctic White", 0xF2F2F0, .solid), Paint("Shadow Black", 0x101113)],
                 defaultWheelInches: 17),
        CarModel(id: "supra", make: "Toyota", model: "GR Supra", style: .coupe,
                 lengthM: 4.38, widthM: 1.865, heightM: 1.29, wheelbaseM: 2.47,
                 trims: [
                    Trim(name: "GT", powerKW: 285, massKg: 1520, topSpeedKmh: 250, drive: .rwd, grip: 1.00),
                    Trim(name: "Final Edition", powerKW: 324, massKg: 1495, topSpeedKmh: 250, drive: .rwd, grip: 1.08, factoryWing: true),
                 ],
                 paints: [Paint("Renaissance Red", 0xC2141C), Paint("Lightning Yellow", 0xF2D200, .solid), Paint("Nitro Yellow", 0xE6E000, .solid),
                          Paint("Refraction Blue", 0x1C4FA0), Paint("Turbulence Grey", 0x5E6268), Paint("Absolute Zero", 0xF3F3F0, .solid)],
                 defaultWheelInches: 19),
        CarModel(id: "z", make: "Nissan", model: "Z", style: .coupe,
                 lengthM: 4.38, widthM: 1.845, heightM: 1.315, wheelbaseM: 2.55,
                 trims: [
                    Trim(name: "Z", powerKW: 298, massKg: 1600, topSpeedKmh: 250, drive: .rwd, grip: 0.98),
                    Trim(name: "Z NISMO", powerKW: 309, massKg: 1640, topSpeedKmh: 250, drive: .rwd, grip: 1.05, factoryWing: true),
                 ],
                 paints: [Paint("Ikazuchi Yellow", 0xF0C419, .solid), Paint("Seiran Blue", 0x1E4E9E), Paint("Passion Red", 0xB0121D, .pearl),
                          Paint("Boulder Grey", 0x7A7D80, .pearl), Paint("Brilliant Silver", 0xBFC2C5), Paint("Everest White", 0xF2F2EF, .pearl)],
                 defaultWheelInches: 19),
        CarModel(id: "296", make: "Ferrari", model: "296 GTB", style: .midEngine,
                 lengthM: 4.565, widthM: 1.958, heightM: 1.187, wheelbaseM: 2.6, groundClearanceM: 0.10,
                 trims: [
                    Trim(name: "296 GTB", powerKW: 610, massKg: 1470, topSpeedKmh: 330, drive: .rwd, grip: 1.12),
                    Trim(name: "Assetto Fiorano", powerKW: 610, massKg: 1440, topSpeedKmh: 330, drive: .rwd, grip: 1.20, factoryWing: true),
                 ],
                 paints: [Paint("Rosso Corsa", 0xD40000, .solid), Paint("Giallo Modena", 0xF7D000, .solid), Paint("Rosso Imola", 0x9E1218),
                          Paint("Blu Tour de France", 0x1B3A8A), Paint("Argento Nürburgring", 0xA7ABAF), Paint("Bianco Avus", 0xF4F4F2, .solid), Paint("Nero Daytona", 0x0D0D0F)],
                 defaultWheelInches: 20),
        CarModel(id: "temerario", make: "Lamborghini", model: "Temerario", style: .midEngine,
                 lengthM: 4.706, widthM: 1.996, heightM: 1.201, wheelbaseM: 2.658, groundClearanceM: 0.10,
                 trims: [
                    Trim(name: "Temerario", powerKW: 677, massKg: 1690, topSpeedKmh: 343, drive: .awd, grip: 1.14),
                    Trim(name: "Alleggerita", powerKW: 677, massKg: 1665, topSpeedKmh: 343, drive: .awd, grip: 1.20, factoryWing: true),
                 ],
                 paints: [Paint("Verde Mantis", 0x6FCF1E, .pearl), Paint("Arancio Borealis", 0xF26A0F, .pearl), Paint("Giallo Inti", 0xF5C400, .pearl),
                          Paint("Viola Pasifae", 0x5A2D82), Paint("Blu Cepheus", 0x123C8C), Paint("Bianco Monocerus", 0xF3F3F0, .solid), Paint("Nero Noctis", 0x0B0B0C, .solid)],
                 defaultWheelInches: 20),
    ]

    static func model(id: String) -> CarModel {
        all.first { $0.id == id } ?? all[0]
    }
}
