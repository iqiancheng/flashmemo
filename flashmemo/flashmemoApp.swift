import SwiftUI
import SwiftData

@main
struct FlashMemoApp: App {
    let container: ModelContainer
    
    init() {
        do {
            let schema = Schema([Memo.self])
            let modelConfiguration: ModelConfiguration
            
            if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppConfig.appGroupIdentifier) {
                let databaseURL = containerURL.appendingPathComponent("FlashMemo.store")
                modelConfiguration = ModelConfiguration(schema: schema, url: databaseURL)
            } else {
                modelConfiguration = ModelConfiguration(schema: schema)
            }
            
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            TimelineView()
        }
        .modelContainer(container)
    }
}
