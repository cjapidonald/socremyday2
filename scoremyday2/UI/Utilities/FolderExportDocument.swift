import SwiftUI
import UniformTypeIdentifiers

struct FolderExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.folder] }

    var items: [String: Data]

    init(items: [String: Data]) {
        self.items = items
    }

    init(configuration: ReadConfiguration) throws {
        items = [:]
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let wrappers = items.mapValues { FileWrapper(regularFileWithContents: $0) }
        return FileWrapper(directoryWithFileWrappers: wrappers)
    }
}
