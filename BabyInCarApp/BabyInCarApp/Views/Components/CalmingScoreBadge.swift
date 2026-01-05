//
//  CalmingScoreBadge.swift
//  BabyInCarApp
//
//  Created for FS-017: Smart Emergency Playlist System
//

import SwiftUI

struct CalmingScoreBadge: View {
    let score: Double  // 0.0 - 1.0

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "heart.fill")
                .font(.caption2)
            Text(String(format: "%.0f%%", score * 100))
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(.red)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color.red.opacity(0.1))
        .cornerRadius(4)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 10) {
        CalmingScoreBadge(score: 0.95)
        CalmingScoreBadge(score: 0.75)
        CalmingScoreBadge(score: 0.50)
    }
    .padding()
}
