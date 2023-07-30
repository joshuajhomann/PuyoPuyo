//
//  ContentView.swift
//  PuyoPyuo
//
//  Created by Joshua Homann on 6/25/23.
//

import Observation
import SwiftUI

struct ContentView: View {
    var body: some View {
        Rectangle()
            .overlay(Image(.niihau21).resizable().aspectRatio(4032.0/3024.0, contentMode: .fill))
            .overlay(GameView())
    }
}

#Preview {
    ContentView()
}
