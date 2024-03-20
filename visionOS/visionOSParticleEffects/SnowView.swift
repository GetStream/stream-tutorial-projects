//
//  SnowView.swift
//  VisionParticleEffects


import SwiftUI
import RealityKit
import RealityKitContent

struct SnowView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Model3D(named: "Snow") { model in
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
    SnowView()
}
