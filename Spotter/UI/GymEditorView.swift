import SwiftUI
import UIKit

/// Set up what a gym has: photograph it and let the AI coach recognise the equipment,
/// or tick things off by hand. Used for the home gym and for travel gyms.
struct GymEditor: View {
    @Binding var gym: Gym
    @EnvironmentObject private var store: AppStore

    @State private var pending: [UIImage] = []
    @State private var scanning = false
    @State private var scanMessage: String?
    @State private var scanFailed = false
    @State private var unrecognised: [String] = []
    @State private var editing: EquipmentItem?
    @State private var hasKey = Keychain.hasKey

    var body: some View {
        VStack(spacing: 18) {
            Card {
                Text("Gym name").font(.caption).foregroundStyle(.secondary)
                TextField("Gym name", text: $gym.name)
                    .font(.title3.weight(.semibold))
                    .textInputAutocapitalization(.words)
            }

            scanCard

            Card {
                HStack {
                    Text("Or start from a preset").font(.subheadline)
                    Spacer()
                    Menu {
                        ForEach(GymPreset.allCases) { preset in
                            Button(preset.title) { apply(preset) }
                        }
                    } label: {
                        Label("Presets", systemImage: "square.stack.3d.up")
                    }
                }
                Text("Then walk the floor and untick anything this gym doesn't have.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ForEach(EquipmentType.Category.allCases) { category in
                checklist(category)
            }
        }
        .sheet(item: $editing) { item in
            EquipmentItemEditor(item: item) { updated in
                if let index = gym.equipment.firstIndex(where: { $0.id == updated.id }) {
                    gym.equipment[index] = updated
                }
            }
        }
        .onAppear { hasKey = Keychain.hasKey }
    }

    // MARK: Photo scan

    private var scanCard: some View {
        Card {
            Label("Photograph the equipment", systemImage: "camera.viewfinder")
                .font(.headline)
            Text(hasKey
                 ? "Walk around and snap each machine, rack and bench — wide shots with several machines are fine. The coach works out what's there and keeps the photos so it can show you your own machines."
                 : "Add a Claude API key (Settings › AI coach) and the coach will recognise equipment from your photos. Without one, tick the list below and add a photo to each item yourself.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if hasKey {
                PhotoSourceButtons { images in
                    pending.append(contentsOf: images)
                    scanMessage = nil
                }

                if !pending.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(pending.enumerated()), id: \.offset) { index, image in
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 72, height: 72)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay(alignment: .topTrailing) {
                                        Button {
                                            pending.remove(at: index)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .symbolRenderingMode(.palette)
                                                .foregroundStyle(.white, .black.opacity(0.6))
                                        }
                                        .padding(3)
                                    }
                            }
                        }
                    }
                    Button {
                        Task { await scan() }
                    } label: {
                        if scanning {
                            HStack(spacing: 8) {
                                ProgressView().tint(.white)
                                Text("Looking at your photos…")
                            }
                        } else {
                            Label("Identify equipment in \(pending.count) photo\(pending.count == 1 ? "" : "s")", systemImage: "sparkles")
                        }
                    }
                    .buttonStyle(BigButtonStyle())
                    .disabled(scanning)
                }
            }

            if let scanMessage {
                Label(scanMessage, systemImage: scanFailed ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(scanFailed ? Color.red : Color.green)
            }
            if !unrecognised.isEmpty {
                Text("Also spotted, but not something I program with yet: " + unrecognised.joined(separator: ", ") + ".")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func scan() async {
        scanning = true
        scanMessage = nil
        defer { scanning = false }
        do {
            let result = try await store.scanEquipment(photos: pending)
            var added = 0
            for found in result.added {
                if let index = gym.equipment.firstIndex(where: { $0.type == found.type && $0.photoFile == nil }) {
                    gym.equipment[index].label = found.label
                    gym.equipment[index].notes = found.notes
                    gym.equipment[index].photoFile = found.photoFile
                    added += 1
                } else if !gym.equipment.contains(where: { $0.type == found.type && $0.label == found.label }) {
                    gym.equipment.append(found)
                    added += 1
                }
            }
            unrecognised = result.unrecognised
            pending = []
            scanFailed = false
            scanMessage = added == 0
                ? "Nothing new found in those photos."
                : "Found \(added) piece\(added == 1 ? "" : "s") of equipment. Check the list below."
        } catch {
            scanFailed = true
            scanMessage = error.localizedDescription
        }
    }

    private func apply(_ preset: GymPreset) {
        for type in preset.equipment { gym.add(type) }
    }

    // MARK: Checklist

    private func checklist(_ category: EquipmentType.Category) -> some View {
        let types = EquipmentType.allCases.filter { $0.category == category }
        return VStack(spacing: 8) {
            SectionTitle(category.rawValue)
            VStack(spacing: 0) {
                ForEach(types) { type in
                    let items = gym.equipment.filter { $0.type == type }
                    HStack(spacing: 12) {
                        Button {
                            if items.isEmpty { gym.add(type) } else { gym.remove(type) }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: items.isEmpty ? "circle" : "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(items.isEmpty ? Color.secondary : Color.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(type.displayName).foregroundStyle(Color.primary)
                                    if let label = items.first(where: { !$0.label.isEmpty })?.label {
                                        Text(label).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if let first = items.first {
                            Button {
                                editing = items.first(where: { $0.photoFile != nil }) ?? first
                            } label: {
                                if let withPhoto = items.first(where: { $0.photoFile != nil }) {
                                    StoredPhoto(file: withPhoto.photoFile)
                                        .frame(width: 40, height: 40)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                } else {
                                    Image(systemName: "camera")
                                        .frame(width: 40, height: 40)
                                        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    if type != types.last { Divider().padding(.leading, 50) }
                }
            }
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

/// Edit one piece of equipment: what it's called here, notes, and a photo of it.
struct EquipmentItemEditor: View {
    @State var item: EquipmentItem
    var onSave: (EquipmentItem) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    StoredPhoto(file: item.photoFile, fallbackSymbol: "camera")
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .listRowInsets(EdgeInsets())
                    PhotoSourceButtons(maxSelection: 1) { images in
                        if let jpeg = images.first?.downscaledJPEG() {
                            item.photoFile = AppStore.savePhoto(jpeg)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                } header: {
                    Text("Photo of this one in your gym")
                }
                Section("What it looks like here") {
                    TextField("e.g. Grey Technogym, back corner", text: $item.label)
                }
                Section("Notes") {
                    TextField("Seat setting, weight range, quirks…", text: $item.notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle(item.type.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(item)
                        dismiss()
                    }
                }
            }
        }
    }
}
