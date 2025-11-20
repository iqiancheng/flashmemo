import Foundation
import SwiftData

@Model
class UserSettings {
    @Attribute(.unique) var id: UUID
    var preferredLanguages: [String] // Language codes in priority order
    @Relationship(deleteRule: .cascade) var properNouns: [ProperNoun]?
    var polishModelRawValue: String // Store enum as String for SwiftData
    var openAIAPIKey: String?
    var openAIBaseURL: String?
    var userName: String?
    var userEmail: String?
    var createdAt: Date
    var updatedAt: Date
    
    var polishModel: PolishModelType {
        get {
            PolishModelType(rawValue: polishModelRawValue) ?? .appleAFM
        }
        set {
            polishModelRawValue = newValue.rawValue
        }
    }
    
    var properNounsArray: [ProperNoun] {
        get {
            properNouns ?? []
        }
        set {
            properNouns = newValue
        }
    }
    
    init(
        id: UUID = UUID(),
        preferredLanguages: [String] = ["en"],
        properNouns: [ProperNoun] = [],
        polishModel: PolishModelType = .appleAFM,
        openAIAPIKey: String? = nil,
        openAIBaseURL: String? = nil,
        userName: String? = nil,
        userEmail: String? = nil
    ) {
        self.id = id
        self.preferredLanguages = preferredLanguages
        self.properNouns = properNouns.isEmpty ? nil : properNouns
        self.polishModelRawValue = polishModel.rawValue
        self.openAIAPIKey = openAIAPIKey
        self.openAIBaseURL = openAIBaseURL
        self.userName = userName
        self.userEmail = userEmail
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

@Model
class ProperNoun {
    @Attribute(.unique) var id: UUID
    var term: String
    var definition: String
    var createdAt: Date
    
    init(id: UUID = UUID(), term: String, definition: String) {
        self.id = id
        self.term = term
        self.definition = definition
        self.createdAt = Date()
    }
}

enum PolishModelType: String, Codable, CaseIterable {
    case appleAFM = "Apple AFM"
    case openAICompatible = "OpenAI Compatible API"
    
    var description: String {
        switch self {
        case .appleAFM:
            return "Apple's on-device AI model for text polishing"
        case .openAICompatible:
            return "Use OpenAI or compatible API for text polishing"
        }
    }
    
    var icon: String {
        switch self {
        case .appleAFM:
            return "sparkles"
        case .openAICompatible:
            return "network"
        }
    }
}

