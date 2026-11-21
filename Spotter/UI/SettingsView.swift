import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var apiKey = ""
    @State private var hasKey = Keychain.hasKey
    @State private var showTravel = false
    @State private var editingGym: Gym?
    @State private var confirmReset = false
    @State private var profileChanged = false

    var body: some View {
        NavigationStack {
            Form {
                Section("You") {
                    NavigationLink {
                        ScrollView {
                            ProfileForm(profile: $store.data.profile).padding(16)
                        }
                        .scrollDismissesKeyboard(.interactively)
                        .background(Color(.systemGroupedBackground))
                        .navigationTitle("About you")
                        .navigationBarTitleDisplayMode(.inline)
                        .onDisappear { profileChanged = true }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.data.profile.name.isEmpty ? "Profile" : store.data.profile.name)
                            Text("\(store.data.profile.goal.title) · \(store.data.profile.experience.title) · \(store.data.profile.daysPerWeek)×\(store.data.profile.sessionMinutes) min")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if profileChanged {
                        Text("Changed your goal or schedule? Use Redesign on the Program tab to rebuild your plan around it.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    if hasKey {
                        Label("Claude API key saved", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
                        Button("Remove key", role: .destructive) {
                            Keychain.apiKey = nil
                            hasKey = false
                        }
                    } else {
                        SecureField("sk-ant-…", text: $apiKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button("Save key") {
                            Keychain.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                            apiKey = ""
                            hasKey = Keychain.hasKey
                        }
                        .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                } header: {
                    Text("AI coach")
                } footer: {
                    Text("Powers photo recognition, program design and coach chat. Create a key at console.anthropic.com. It's kept in this iPhone's Keychain; your photos and training data are sent to Anthropic's API only when you use those features.")
                }

                Section {
                    if store.data.healthEnabled {
                        Label("Connected", systemImage: "heart.fill").foregroundStyle(.pink)
                        Toggle("Save workouts to Health", isOn: $store.data.saveWorkoutsToHealth)
                        Button("Refresh now") { Task { await store.refreshHealth() } }
                        if let lines = store.data.health?.summaryLines {
                            ForEach(lines, id: \.self) { Text($0).font(.footnote).foregroundStyle(.secondary) }
                        }
                    } else if HealthKitManager.shared.isAvailable {
                        Button("Connect Apple Health") { Task { await store.connectHealth() } }
                    } else {
                        Text("Not available on this device").foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Apple Health")
                } footer: {
                    Text("If you also record strength workouts on an Apple Watch, turn off saving here to avoid duplicates — Spotter still reads your heart rate from the Watch.")
                }

                Section {
                    ForEach(store.data.gyms) { gym in
                        Button {
                            editingGym = gym
                        } label: {
                            HStack {
                                Image(systemName: gym.kind == .travel ? "airplane" : "house.fill")
                                    .foregroundStyle(gym.kind == .travel ? Color.blue : Color.orange)
                                    .frame(width: 26)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(gym.name).foregroundStyle(Color.primary)
                                    Text("\(gym.equipment.count) pieces of equipment").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if gym.id == store.activeGym?.id { Pill(text: "Training here", color: .green) }
                            }
                        }
                        .swipeActions {
                            if gym.kind == .travel {
                                Button("Delete", role: .destructive) { delete(gym) }
                                if gym.id != store.data.activeGymID {
                                    Button("Train here") { store.data.activeGymID = gym.id }.tint(.blue)
                                }
                            }
                        }
                    }
                    if store.isTravelling {
                        Button("End travel mode") { store.endTravel() }
                    }
                    Button {
                        showTravel = true
                    } label: {
                        Label("Set up a travel gym", systemImage: "airplane.departure")
                    }
                } header: {
                    Text("Gyms")
                } footer: {
                    Text("Swipe a travel gym to train there again or delete it.")
                }

                Section {
                    Button("Erase everything and start again", role: .destructive) { confirmReset = true }
                } footer: {
                    Text("Exercise photos and instructions are from the public-domain Free Exercise DB.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .sheet(isPresented: $showTravel) {
                TravelSetupView().environmentObject(store)
            }
            .sheet(item: $editingGym) { gym in
                GymEditSheet(gym: gym).environmentObject(store)
            }
            .confirmationDialog("Erase all data?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Erase everything", role: .destructive) {
                    store.resetEverything()
                    dismiss()
                }
            } message: {
                Text("This deletes your profile, gyms, programs, workout history and API key from this iPhone.")
            }
        }
    }

    private func delete(_ gym: Gym) {
        if store.data.activeGymID == gym.id { store.endTravel() }
        store.data.programs.removeAll { $0.gymID == gym.id }
        store.data.gyms.removeAll { $0.id == gym.id }
    }
}

/// Travel mode: describe the hotel gym, get a temporary program that mirrors the home one.
struct TravelSetupView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var gym = Gym(name: "Hotel gym", kind: .travel)
    @State private var working = false
    @State private var note: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Card {
                        Label("Travel mode", systemImage: "airplane").font(.headline).foregroundStyle(.blue)
                        Text("Photograph or tick off what this gym has. Spotter re-maps your usual program onto it — same days, same structure — and switches back when you're home. Nothing here? Leave the list empty for a bodyweight plan.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    GymEditor(gym: $gym)
                    if let note {
                        Card {
                            Label("Used the built-in planner", systemImage: "info.circle").font(.subheadline.weight(.semibold))
                            Text(note).font(.footnote).foregroundStyle(.secondary)
                            Button("OK") { dismiss() }.buttonStyle(BigButtonStyle(prominent: false))
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 80)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .safeAreaInset(edge: .bottom) {
                Button {
                    Task { await start() }
                } label: {
                    if working {
                        HStack {
                            ProgressView().tint(.white)
                            Text("Building your travel plan…")
                        }
                    } else {
                        Label("Build travel program", systemImage: "wand.and.stars")
                    }
                }
                .buttonStyle(BigButtonStyle())
                .disabled(working)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.bar)
            }
            .navigationTitle("Travel gym")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(working) }
            }
            .interactiveDismissDisabled(working)
        }
    }

    private func start() async {
        working = true
        if gym.name.trimmingCharacters(in: .whitespaces).isEmpty { gym.name = "Travel gym" }
        store.upsert(gym)
        store.data.activeGymID = gym.id
        note = await store.designProgram(for: gym)
        working = false
        if note == nil { dismiss() }
    }
}
