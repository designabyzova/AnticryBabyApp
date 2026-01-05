//
//  TempoBadge.swift
//  BabyInCarApp
//
//  Created for FS-017: Smart Emergency Playlist System
//

import SwiftUI

struct TempoBadge: View {
    let bpm: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "metronome")
                .font(.caption2)
            Text("\(bpm) BPM")
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(.purple)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color.purple.opacity(0.1))
        .cornerRadius(4)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 10) {
        TempoBadge(bpm: 120)
        TempoBadge(bpm: 60)
        TempoBadge(bpm: 40)
    }
    .padding()
}
