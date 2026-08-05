//
//  ClipImporter.swift
//  TennisAnalyzer
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// A movie picked from the Photos library, copied into a local temp file we own.
/// `PhotosPicker` only hands back a transferable payload for the duration of the
/// transfer, so `FileRepresentation` is used to persist it before the picker's
/// own temp copy is cleaned up.
struct TransferableClip: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { clip in
            SentTransferredFile(clip.url)
        } importing: { received in
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension)
            try FileManager.default.copyItem(at: received.file, to: destination)
            return Self(url: destination)
        }
    }
}

/// `PhotosPicker` needs no `NSPhotoLibraryUsageDescription` — it runs out-of-process
/// (PHPicker) and only hands the app the items the user explicitly selected.
struct ClipImportButton: View {
    var onImport: (URL) -> Void

    @State private var selection: PhotosPickerItem?
    @State private var isImporting = false

    var body: some View {
        PhotosPicker(selection: $selection, matching: .videos) {
            Label(isImporting ? "Importing…" : "Upload Clip", systemImage: "square.and.arrow.up")
        }
        .disabled(isImporting)
        .onChange(of: selection) { _, newValue in
            guard let newValue else { return }
            isImporting = true
            Task {
                defer {
                    isImporting = false
                    selection = nil
                }
                if let clip = try? await newValue.loadTransferable(type: TransferableClip.self) {
                    onImport(clip.url)
                }
            }
        }
    }
}
