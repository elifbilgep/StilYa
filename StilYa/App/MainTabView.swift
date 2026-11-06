//
//  MainTabView.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 7.12.2025.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var localizationManager: LocalizationManager

    var body: some View {
        HomeView()
            .navigationBarBackButtonHidden(true)
    }
}
