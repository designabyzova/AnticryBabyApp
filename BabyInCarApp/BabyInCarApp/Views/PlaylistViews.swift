//
//  PlaylistViews.swift
//  BabyInCarApp
//
//  Views for playlist management: detail view, create/edit sheet, add to playlist
//

import SwiftUI

// MARK: - Playlist Detail View
struct PlaylistDetailView: View {
    let playlist: Playlist
    let isUserPlaylist: Bool

    @EnvironmentObject var audioEngine: AudioEngine
    @StateObject private var playlistManager = PlaylistManager.shared
    @StateObject private var favoritesManager = FavoritesManager.shared
    @Environment(\.dismiss) var dismiss
    @Environment(\.bottomSafeAreaPadding) private var bottomPadding

    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var isEditMode = false

    // Get the latest version of the playlist
    private var currentPlaylist: Playlist {
        if isUserPlaylist {
            return playlistManager.getPlaylist(by: playlist.id) ?? playlist
        }
        return playlist
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 16) {
                // Header
                playlistHeader

                // Action buttons
                actionButtons

                // Tracks list
                tracksList
            }
            .padding(.bottom, bottomPadding + 20)
        }
        .scrollIndicators(.visible)
        .background(Color.appBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isUserPlaylist {
                    Menu {
                        Button {
                            showingEditSheet = true
                        } label: {
                            Label("Edit Playlist", systemImage: "pencil")
                        }

                        Button {
                            isEditMode.toggle()
                        } label: {
                            Label(isEditMode ? "Done Editing" : "Reorder Tracks", systemImage: "arrow.up.arrow.down")
                        }

                        Divider()

                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            Label("Delete Playlist", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 18))
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditPlaylistSheet(playlist: currentPlaylist)
        }
        .alert("Delete Playlist?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                playlistManager.deletePlaylist(currentPlaylist)
                dismiss()
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }

    // MARK: - Header
    private var playlistHeader: some View {
        VStack(spacing: 12) {
            // Artwork with favorite button
            ZStack(alignment: .topTrailing) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.forCategory(currentPlaylist.dominantCategory ?? .whiteNoise).opacity(0.15))
                        .frame(width: 160, height: 160)

                    Image(systemName: currentPlaylist.dominantCategory?.icon ?? "music.note.list")
                        .font(.system(size: 60))
                        .foregroundColor(Color.forCategory(currentPlaylist.dominantCategory ?? .whiteNoise))
                }

                // Favorite button overlay
                Button {
                    favoritesManager.toggleFavorite(playlist: currentPlaylist)
                } label: {
                    Image(systemName: favoritesManager.isFavorite(playlist: currentPlaylist) ? "heart.fill" : "heart")
                        .font(.system(size: 20))
                        .foregroundColor(favoritesManager.isFavorite(playlist: currentPlaylist) ? .appSecondary : .white)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.3))
                        )
                }
                .offset(x: -8, y: 8)
            }

            // Info
            Text(currentPlaylist.name)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.appText)
                .multilineTextAlignment(.center)

            if !currentPlaylist.description.isEmpty {
                Text(currentPlaylist.description)
                    .font(.system(size: 14))
                    .foregroundColor(.appTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Stats
            HStack(spacing: 16) {
                StatBadge(icon: "music.note", value: "\(currentPlaylist.trackCount) tracks")
                StatBadge(icon: "clock", value: currentPlaylist.formattedTotalDuration)

                if !currentPlaylist.canPlayOffline {
                    StatBadge(icon: "wifi", value: "Streaming")
                }
            }
        }
        .padding(.vertical, 24)
    }

    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack(spacing: 16) {
            // Play button
            Button {
                audioEngine.play(playlist: currentPlaylist)
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Play")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(Color.forCategory(currentPlaylist.dominantCategory ?? .whiteNoise))
                )
            }

            // Shuffle button
            Button {
                audioEngine.isShuffleEnabled = true
                audioEngine.play(playlist: currentPlaylist)
            } label: {
                HStack {
                    Image(systemName: "shuffle")
                    Text("Shuffle")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.forCategory(currentPlaylist.dominantCategory ?? .whiteNoise))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .stroke(Color.forCategory(currentPlaylist.dominantCategory ?? .whiteNoise), lineWidth: 2)
                )
            }
        }
        .padding(.horizontal, 20)
        .disabled(currentPlaylist.isEmpty)
        .opacity(currentPlaylist.isEmpty ? 0.5 : 1)
    }

    // MARK: - Tracks List
    private var tracksList: some View {
        VStack(alignment: .leading, spacing: 8) {
            if currentPlaylist.isEmpty {
                emptyPlaylistView
            } else {
                ForEach(Array(currentPlaylist.tracks.enumerated()), id: \.element.id) { index, track in
                    PlaylistTrackRow(
                        track: track,
                        index: index,
                        isPlaying: audioEngine.currentTrack?.id == track.id && audioEngine.playbackState.isPlaying,
                        isEditing: isEditMode && isUserPlaylist,
                        onPlay: {
                            audioEngine.play(playlist: currentPlaylist, startIndex: index)
                        },
                        onRemove: isUserPlaylist ? {
                            playlistManager.removeTrack(at: index, from: currentPlaylist)
                        } : nil
                    )
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var emptyPlaylistView: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 48))
                .foregroundColor(.appTextSecondary)

            Text("No tracks yet")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.appText)

            Text("Add tracks from the library")
                .font(.system(size: 14))
                .foregroundColor(.appTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Playlist Track Row
struct PlaylistTrackRow: View {
    let track: AudioTrack
    let index: Int
    let isPlaying: Bool
    let isEditing: Bool
    let onPlay: () -> Void
    var onRemove: (() -> Void)?
    @StateObject private var favoritesManager = FavoritesManager.shared

    var body: some View {
        HStack(spacing: 12) {
            // Track number
            if isEditing {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 16))
                    .foregroundColor(.appTextSecondary)
                    .frame(width: 24)
            } else {
                if isPlaying {
                    Image(systemName: "waveform")
                        .font(.system(size: 14))
                        .foregroundColor(.appPrimary)
                        .frame(width: 24)
                } else {
                    Text("\(index + 1)")
                        .font(.system(size: 14))
                        .foregroundColor(.appTextSecondary)
                        .frame(width: 24)
                }
            }

            // Track icon
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.forCategory(track.category).opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: track.category.icon)
                    .font(.system(size: 18))
                    .foregroundColor(Color.forCategory(track.category))
            }

            // Track info
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.system(size: 15, weight: isPlaying ? .semibold : .regular))
                    .foregroundColor(isPlaying ? .appPrimary : .appText)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(track.artist)
                        .font(.system(size: 12))
                        .foregroundColor(.appTextSecondary)

                    Text("•")
                        .foregroundColor(.appTextSecondary)

                    Text(track.formattedDuration)
                        .font(.system(size: 12))
                        .foregroundColor(.appTextSecondary)
                }
            }

            Spacer()

            // Actions
            if isEditing {
                if let onRemove = onRemove {
                    Button(action: onRemove) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.red)
                    }
                }
            } else {
                // Favorite button
                Button {
                    favoritesManager.toggleFavorite(track: track)
                } label: {
                    Image(systemName: favoritesManager.isFavorite(track: track) ? "heart.fill" : "heart")
                        .font(.system(size: 16))
                        .foregroundColor(favoritesManager.isFavorite(track: track) ? .appSecondary : .appTextSecondary)
                }
                .buttonStyle(.plain)

                Button(action: onPlay) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.appPrimary)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.appPrimary.opacity(0.1))
                        )
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isPlaying ? Color.appPrimary.opacity(0.05) : Color.white)
                .shadow(color: .black.opacity(0.02), radius: 2)
        )
    }
}

// MARK: - Stat Badge
struct StatBadge: View {
    let icon: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
            Text(value)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(.appTextSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.appTextSecondary.opacity(0.1))
        )
    }
}

// MARK: - Create Playlist Sheet
struct CreatePlaylistSheet: View {
    @StateObject private var playlistManager = PlaylistManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var description = ""
    var initialTracks: [AudioTrack] = []
    @FocusState private var focusedField: CreatePlaylistField?

    private enum CreatePlaylistField {
        case name, description
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Playlist Name", text: $name)
                        .font(.system(size: 16))
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .description
                        }

                    TextField("Description (optional)", text: $description)
                        .font(.system(size: 16))
                        .focused($focusedField, equals: .description)
                        .submitLabel(.done)
                        .onSubmit {
                            focusedField = nil
                        }
                }

                if !initialTracks.isEmpty {
                    Section {
                        HStack {
                            Image(systemName: "music.note.list")
                                .foregroundColor(.appPrimary)
                            Text("\(initialTracks.count) track(s) will be added")
                                .font(.system(size: 14))
                                .foregroundColor(.appTextSecondary)
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("New Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let _ = playlistManager.createPlaylist(
                            name: name,
                            description: description,
                            tracks: initialTracks
                        )
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.appPrimary)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Edit Playlist Sheet
struct EditPlaylistSheet: View {
    let playlist: Playlist

    @StateObject private var playlistManager = PlaylistManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var name: String
    @State private var description: String
    @FocusState private var focusedField: EditPlaylistField?

    private enum EditPlaylistField {
        case name, description
    }

    init(playlist: Playlist) {
        self.playlist = playlist
        _name = State(initialValue: playlist.name)
        _description = State(initialValue: playlist.description)
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Playlist Name", text: $name)
                        .font(.system(size: 16))
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .description
                        }

                    TextField("Description (optional)", text: $description)
                        .font(.system(size: 16))
                        .focused($focusedField, equals: .description)
                        .submitLabel(.done)
                        .onSubmit {
                            focusedField = nil
                        }
                }

                Section {
                    HStack {
                        Image(systemName: "music.note.list")
                            .foregroundColor(.appPrimary)
                        Text("\(playlist.trackCount) tracks")
                            .font(.system(size: 14))
                            .foregroundColor(.appTextSecondary)

                        Spacer()

                        Text(playlist.formattedTotalDuration)
                            .font(.system(size: 14))
                            .foregroundColor(.appTextSecondary)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Edit Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updatedPlaylist = playlist
                        updatedPlaylist.name = name
                        updatedPlaylist.description = description
                        updatedPlaylist.updatedAt = Date()
                        playlistManager.updatePlaylist(updatedPlaylist)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.appPrimary)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Add to Playlist Sheet
struct AddToPlaylistSheet: View {
    let track: AudioTrack

    @StateObject private var playlistManager = PlaylistManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var showingCreatePlaylist = false

    var body: some View {
        NavigationView {
            List {
                // Create new playlist option
                Button {
                    showingCreatePlaylist = true
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.appPrimary.opacity(0.1))
                                .frame(width: 50, height: 50)

                            Image(systemName: "plus")
                                .font(.system(size: 20))
                                .foregroundColor(.appPrimary)
                        }

                        Text("Create New Playlist")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.appPrimary)
                    }
                }

                // Existing playlists
                if !playlistManager.userPlaylists.isEmpty {
                    Section("Your Playlists") {
                        ForEach(playlistManager.userPlaylists) { playlist in
                            Button {
                                playlistManager.addTrack(track, to: playlist)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.forCategory(playlist.dominantCategory ?? .whiteNoise).opacity(0.15))
                                            .frame(width: 50, height: 50)

                                        Image(systemName: playlist.dominantCategory?.icon ?? "music.note.list")
                                            .font(.system(size: 20))
                                            .foregroundColor(Color.forCategory(playlist.dominantCategory ?? .whiteNoise))
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(playlist.name)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(.appText)

                                        Text("\(playlist.trackCount) tracks")
                                            .font(.system(size: 12))
                                            .foregroundColor(.appTextSecondary)
                                    }

                                    Spacer()

                                    if playlist.contains(track) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                            .disabled(playlist.contains(track))
                        }
                    }
                }
            }
            .navigationTitle("Add to Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreatePlaylist) {
            CreatePlaylistSheet(initialTracks: [track])
        }
    }
}

// MARK: - User Playlists Section (for Library View)
struct UserPlaylistsSection: View {
    @StateObject private var playlistManager = PlaylistManager.shared
    @EnvironmentObject var audioEngine: AudioEngine

    @State private var showingCreatePlaylist = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "music.note.list")
                    .foregroundColor(.appPrimary)

                Text("My Playlists")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.appText)

                Spacer()

                Button {
                    showingCreatePlaylist = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.appPrimary)
                }
            }
            .padding(.horizontal, 20)

            if playlistManager.userPlaylists.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 36))
                        .foregroundColor(.appTextSecondary)

                    Text("No playlists yet")
                        .font(.system(size: 14))
                        .foregroundColor(.appTextSecondary)

                    Button {
                        showingCreatePlaylist = true
                    } label: {
                        Text("Create Playlist")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.appPrimary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                // Playlists scroll
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(playlistManager.userPlaylists) { playlist in
                            NavigationLink(destination: PlaylistDetailView(playlist: playlist, isUserPlaylist: true)) {
                                UserPlaylistCard(playlist: playlist)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .sheet(isPresented: $showingCreatePlaylist) {
            CreatePlaylistSheet()
        }
    }
}

// MARK: - User Playlist Card
struct UserPlaylistCard: View {
    let playlist: Playlist

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.forCategory(playlist.dominantCategory ?? .whiteNoise).opacity(0.15))
                    .frame(width: 140, height: 140)

                Image(systemName: playlist.dominantCategory?.icon ?? "music.note.list")
                    .font(.system(size: 44))
                    .foregroundColor(Color.forCategory(playlist.dominantCategory ?? .whiteNoise))

                // Track count badge
                VStack {
                    HStack {
                        Spacer()
                        Text("\(playlist.trackCount)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.5))
                            )
                            .padding(8)
                    }
                    Spacer()
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.appText)
                    .lineLimit(1)

                Text(playlist.formattedTotalDuration)
                    .font(.system(size: 12))
                    .foregroundColor(.appTextSecondary)
            }
        }
        .frame(width: 140)
    }
}

#Preview {
    NavigationStack {
        PlaylistDetailView(
            playlist: Playlist(name: "Test Playlist", description: "A test playlist"),
            isUserPlaylist: true
        )
        .environmentObject(AudioEngine.shared)
    }
}
