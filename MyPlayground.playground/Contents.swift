import SwiftUI
import PlaygroundSupport


struct V: View {
    @State var angle: Double = 0.0
    var body: some View {
        Slider(value: $angle)
        Image(.puyo)
            .hueRotation(.radians(.pi * 2 * angle))
    }
}

struct V2: View {
    @State private var angle = Angle.radians(.pi * 2)
    var body: some View {
        ZStack {
            puyo.hueRotation(.radians(.pi))
            puyo
                .rotationEffect(-angle)
                .offset(x: 100)
                .rotationEffect(angle)
                .animation(.linear(duration: 5), value: angle)
                .onAppear { angle = .zero }
        }
        .frame(width: 300, height: 300, alignment: .center)
    }
    var puyo: some View {
        Image(.puyo)
            .resizable()
            .frame(width: 100, height: 100)
    }
}

PlaygroundPage.current.setLiveView(V2())
