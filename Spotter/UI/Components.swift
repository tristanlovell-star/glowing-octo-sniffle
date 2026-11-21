import SwiftUI
import PhotosUI
import UIKit

// MARK: - Cards

struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct SectionTitle: View {
    var text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
}

struct BigButtonStyle: ButtonStyle {
    var prominent = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(prominent ? Color.orange : Color(.tertiarySystemFill),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .foregroundStyle(prominent ? Color.white : Color.primary)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

// MARK: - Exercise demo photos

/// The bundled start/finish demonstration photos for an exercise.
struct ExerciseDemo: View {
    var exercise: Exercise
    var height: CGFloat = 150

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(exercise.images.enumerated()), id: \.offset) { index, name in
                ZStack(alignment: .bottomLeading) {
                    BundledImage(name: name)
                        .frame(maxWidth: .infinity)
                        .frame(height: height)
                        .clipped()
                    Text(index == 0 ? "Start" : "Finish")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.black.opacity(0.6), in: Capsule())
                        .foregroundStyle(.white)
                        .padding(6)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}

struct BundledImage: View {
    var name: String

    var body: some View {
        if let url = Bundle.main.url(forResource: name, withExtension: "jpg"),
           let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            ZStack {
                Color(.tertiarySystemFill)
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// A photo the user took, loaded from the app's storage.
struct StoredPhoto: View {
    var file: String?
    var fallbackSymbol = "photo"

    var body: some View {
        if let image = AppStore.loadPhoto(file) {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            ZStack {
                Color(.tertiarySystemFill)
                Image(systemName: fallbackSymbol).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Camera

struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    static var isAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = Self.isAvailable ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onImage(image) }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

/// "Take photo" and "Choose from library" buttons that hand back UIImages.
struct PhotoSourceButtons: View {
    var maxSelection = 12
    var onImages: ([UIImage]) -> Void

    @State private var showCamera = false
    @State private var picked: [PhotosPickerItem] = []

    var body: some View {
        HStack(spacing: 10) {
            Button {
                showCamera = true
            } label: {
                Label("Take photo", systemImage: "camera.fill")
            }
            .buttonStyle(BigButtonStyle(prominent: true))

            PhotosPicker(selection: $picked, maxSelectionCount: maxSelection, matching: .images) {
                Label("Library", systemImage: "photo.on.rectangle")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(Color.primary)
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { onImages([$0]) }
                .ignoresSafeArea()
        }
        .onChange(of: picked) { _, items in
            guard !items.isEmpty else { return }
            Task {
                var images: [UIImage] = []
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        images.append(image)
                    }
                }
                picked = []
                if !images.isEmpty { onImages(images) }
            }
        }
    }
}

// MARK: - Small helpers

struct Pill: View {
    var text: String
    var color: Color = .orange

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
    }
}

extension PlannedExercise {
    func prescriptionText(_ exercise: Exercise?) -> String {
        let unit = exercise?.loadType == .timed ? " sec" : ""
        let range = repMin == repMax ? "\(repMin)" : "\(repMin)–\(repMax)"
        return "\(sets) × \(range)\(unit)"
    }
}

extension SessionExercise {
    func prescriptionText(_ exercise: Exercise?) -> String {
        let unit = exercise?.loadType == .timed ? " sec" : ""
        let range = repMin == repMax ? "\(repMin)" : "\(repMin)–\(repMax)"
        return "\(targetSets) × \(range)\(unit)"
    }
}

extension Date {
    var shortDay: String {
        formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }
}

/// Renders the coach's light markdown (bold, lists) as text.
struct MarkdownText: View {
    var text: String

    var body: some View {
        if let attributed = try? AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            Text(attributed)
        } else {
            Text(text)
        }
    }
}
