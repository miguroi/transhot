import Foundation

enum SupportedLanguage: String, CaseIterable, Identifiable {
    case english = "English"
    case indonesian = "Indonesian"
    case japanese = "Japanese"
    case korean = "Korean"
    case chineseSimplified = "Chinese (Simplified)"
    case chineseTraditional = "Chinese (Traditional)"
    case spanish = "Spanish"
    case french = "French"
    case german = "German"
    case portuguese = "Portuguese"
    case russian = "Russian"
    case arabic = "Arabic"
    case hindi = "Hindi"
    case thai = "Thai"
    case vietnamese = "Vietnamese"

    var id: String { rawValue }
}
