import SwiftUI

@main
struct CVStickyApp: App {
    @StateObject private var clipboardStore = ClipboardStore()
    @StateObject private var noteStore = NoteStore()

    var body: some Scene {
        WindowGroup("剪贴笺", id: "main") {
            MainView()
                .environmentObject(clipboardStore)
                .environmentObject(noteStore)
                .onAppear { clipboardStore.start() }
        }
        .defaultSize(width: 1180, height: 760)

        MenuBarExtra("剪贴笺", systemImage: "clipboard") {
            ClipboardMenuView()
                .environmentObject(clipboardStore)
                .environmentObject(noteStore)
                .onAppear { clipboardStore.start() }
        }
        .menuBarExtraStyle(.window)
    }
}
