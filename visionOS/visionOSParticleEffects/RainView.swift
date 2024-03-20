//
//  RainView.swift
//  VisionParticleEffects

import SwiftUI
import RealityKit
import RealityKitContent

struct RainView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Model3D(named: "Rain") { model in
                    model
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    ProgressView()
                }
            }
        }
    }
}

#Preview {
    RainView()
}
