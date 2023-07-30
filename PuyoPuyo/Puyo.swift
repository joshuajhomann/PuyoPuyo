//
//  Puyo.swift
//  PuyoPuyo
//
//  Created by Joshua Homann on 7/30/23.
//

import SwiftUI

struct Puyo: View {
    var cell: GameModel.Puyo
    var body: some View {
        Image(.puyo)
            .resizable()
            .hueRotation(cell.color.angle)
            .saturation(1.5)
            .brightness(-0.1)
    }
}
