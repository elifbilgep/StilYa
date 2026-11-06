//
//  WoodenShelf.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 13.03.2026.
//

import SwiftUI

struct WoodenShelf: View {
    var colorScheme: ClosetColorScheme = .darkWoodScheme

    var body: some View {
        VStack(spacing: 0) {
            // Top highlight
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            colorScheme.doorLight.opacity(0.7),
                            colorScheme.shelf
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 2)

            // Main shelf body
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            colorScheme.shelf,
                            colorScheme.frameMid,
                            colorScheme.frameDark
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 7)

            // Bottom edge
            Rectangle()
                .fill(colorScheme.foot.opacity(0.5))
                .frame(height: 2)
        }
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 3)
    }
}
