import SwiftUI

enum Tool: String, CaseIterable, Identifiable {
    case merge, deletePages, compress

    var id: String { rawValue }

    var title: String {
        switch self {
        case .merge: return "Zusammenfügen"
        case .deletePages: return "Seiten löschen"
        case .compress: return "Komprimieren"
        }
    }

    var symbol: String {
        switch self {
        case .merge: return "doc.on.doc"
        case .deletePages: return "trash"
        case .compress: return "arrow.down.right.and.arrow.up.left"
        }
    }
}

struct ContentView: View {
    @State private var tool: Tool? = .merge

    var body: some View {
        NavigationSplitView {
            List(Tool.allCases, selection: $tool) { tool in
                Label(tool.title, systemImage: tool.symbol).tag(tool)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            switch tool ?? .merge {
            case .merge: MergeView()
            case .deletePages: DeletePagesView()
            case .compress: CompressView()
            }
        }
    }
}
