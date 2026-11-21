import SwiftUI
import UIKit

/// A conversation with the AI coach, who can see the profile, gym, program, log and Health data.
struct CoachView: View {
    @EnvironmentObject private var store: AppStore

    @State private var draft = ""
    @State private var attachment: String?
    @State private var streaming: String?
    @State private var errorText: String?
    @State private var showCamera = false
    @State private var hasKey = Keychain.hasKey
    @FocusState private var focused: Bool

    private let starters = [
        "How am I progressing?",
        "I've only got 20 minutes today — what should I do?",
        "Something's sore. What should I change?",
        "Is it time to change my program?",
    ]

    var body: some View {
        NavigationStack {
            Group {
                if hasKey {
                    chat
                } else {
                    noKey
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if hasKey && !store.data.chat.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear") { store.data.chat = [] }.disabled(streaming != nil)
                    }
                }
            }
            .onAppear {
                hasKey = Keychain.hasKey
                takeDraft()
            }
            .onChange(of: store.coachDraft) { _, _ in takeDraft() }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in
                    if let jpeg = image.downscaledJPEG() { attachment = AppStore.savePhoto(jpeg) }
                }
                .ignoresSafeArea()
            }
        }
    }

    private func takeDraft() {
        guard let queued = store.coachDraft else { return }
        store.coachDraft = nil
        draft = queued.text
        attachment = queued.photoFile
        if hasKey { send() }
    }

    private var noKey: some View {
        ScrollView {
            VStack(spacing: 16) {
                Card {
                    Label("AI coach is off", systemImage: "sparkles").font(.headline)
                    Text("Add a Claude API key in Settings (the gear on the Today tab) to chat with a coach who knows your program, your gym and your training log, and can look at photos of machines you're unsure about.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                SectionTitle("Meanwhile, from the built-in coach")
                ForEach(Coach.insights(data: store.data, library: store.library)) { InsightCard(insight: $0) }
            }
            .padding(16)
        }
    }

    private var chat: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    if store.data.chat.isEmpty && streaming == nil {
                        VStack(spacing: 10) {
                            Image(systemName: "bubble.left.and.text.bubble.right.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.orange)
                                .padding(.top, 30)
                            Text("Ask your coach anything")
                                .font(.headline)
                            Text("It can see your program, training log, equipment and Apple Health data. Send a photo of a machine to find out how to use it.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            ForEach(starters, id: \.self) { starter in
                                Button {
                                    draft = starter
                                    send()
                                } label: {
                                    Text(starter)
                                        .font(.subheadline)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(12)
                                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                    ForEach(store.data.chat) { message in
                        Bubble(role: message.role, text: message.text, photoFile: message.photoFile)
                            .id(message.id)
                    }
                    if let streaming {
                        Bubble(role: .assistant, text: streaming.isEmpty ? "…" : streaming, photoFile: nil)
                            .id("streaming")
                    }
                    if let errorText {
                        Label(errorText, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 8)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(12)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: store.data.chat.count) { _, _ in
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            .onChange(of: streaming) { _, _ in
                proxy.scrollTo("bottom", anchor: .bottom)
            }
            .safeAreaInset(edge: .bottom) { composer }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let attachment {
                HStack {
                    StoredPhoto(file: attachment)
                        .frame(width: 54, height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    Text("Photo attached").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        self.attachment = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                }
            }
            HStack(alignment: .bottom, spacing: 8) {
                Button {
                    showCamera = true
                } label: {
                    Image(systemName: "camera.fill")
                        .frame(width: 38, height: 38)
                        .background(Color(.tertiarySystemFill), in: Circle())
                }
                TextField("Message your coach", text: $draft, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($focused)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 19, style: .continuous))
                Button {
                    send()
                } label: {
                    Image(systemName: "arrow.up")
                        .fontWeight(.bold)
                        .frame(width: 38, height: 38)
                        .background(canSend ? Color.orange : Color(.tertiarySystemFill), in: Circle())
                        .foregroundStyle(canSend ? Color.white : Color.secondary)
                }
                .disabled(!canSend)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var canSend: Bool {
        streaming == nil && (!draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || attachment != nil)
    }

    private func send() {
        guard canSend else { return }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        store.data.chat.append(ChatMessage(role: .user, text: text, photoFile: attachment))
        draft = ""
        attachment = nil
        errorText = nil
        streaming = ""
        let history = store.data.chat
        let context = store.coachContext()
        Task {
            do {
                let reply = try await ClaudeClient().chat(history: history, context: context) { partial in
                    streaming = partial
                }
                store.data.chat.append(ChatMessage(role: .assistant, text: reply))
            } catch {
                errorText = error.localizedDescription
            }
            streaming = nil
        }
    }
}

private struct Bubble: View {
    var role: ChatMessage.Role
    var text: String
    var photoFile: String?

    var body: some View {
        HStack {
            if role == .user { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 8) {
                if photoFile != nil {
                    StoredPhoto(file: photoFile)
                        .frame(width: 200, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                if !text.isEmpty {
                    MarkdownText(text: text)
                        .font(.subheadline)
                        .textSelection(.enabled)
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .background(role == .user ? Color.orange : Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .foregroundStyle(role == .user ? Color.white : Color.primary)
            if role == .assistant { Spacer(minLength: 40) }
        }
    }
}
