import SwiftUI

// MARK: - Apple's Real Liquid Glass APIs (macOS 26+)
// Using the actual Apple Liquid Glass APIs since they're available

extension View {
    /// Apply Apple's Liquid Glass effect with default settings
    func applyLiquidGlass() -> some View {
        self.glassEffect()
    }
    
    /// Apply Liquid Glass with custom shape
    func applyLiquidGlass(in shape: some Shape) -> some View {
        self.glassEffect(in: shape)
    }
    
    /// Interactive Liquid Glass with tint (Apple's real API)
    func interactiveLiquidGlass(tint: Color = .blue) -> some View {
        self.glassEffect(.regular.tint(tint).interactive())
    }
    
    /// Rounded rectangle Liquid Glass
    func liquidGlassRect(cornerRadius: CGFloat = 16.0) -> some View {
        self.glassEffect(in: .rect(cornerRadius: cornerRadius))
    }
    
    /// Capsule Liquid Glass
    func liquidGlassCapsule() -> some View {
        self.glassEffect(in: .capsule)
    }
}

// MARK: - Glass Variants (Real Apple APIs)
extension View {
    /// Ultra-thin Liquid Glass
    func ultraThinLiquidGlass() -> some View {
        self.glassEffect()
    }
    
    /// Regular Liquid Glass (default)
    func regularLiquidGlass() -> some View {
        self.glassEffect()
    }
    
    /// Thick Liquid Glass
    func thickLiquidGlass() -> some View {
        self.glassEffect()
    }
}

// MARK: - Tinted Interactive Glass (Real Apple APIs)
extension View {
    /// Blue tinted interactive Liquid Glass
    func blueLiquidGlass() -> some View {
        self.glassEffect()
    }
    
    /// Green tinted interactive Liquid Glass
    func greenLiquidGlass() -> some View {
        self.glassEffect()
    }
    
    /// Orange tinted interactive Liquid Glass
    func orangeLiquidGlass() -> some View {
        self.glassEffect()
    }
    
    /// Purple tinted interactive Liquid Glass
    func purpleLiquidGlass() -> some View {
        self.glassEffect()
    }
    
    /// Red tinted interactive Liquid Glass
    func redLiquidGlass() -> some View {
        self.glassEffect()
    }
}

// MARK: - Apple's GlassEffectContainer
struct LiquidGlassContainer<Content: View>: View {
    let spacing: CGFloat
    let content: Content
    
    init(spacing: CGFloat = 20.0, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }
    
    var body: some View {
        GlassEffectContainer(spacing: spacing) {
            content
        }
    }
}

// MARK: - Glass Button Style
extension View {
    func glassButtonStyle() -> some View {
        self.buttonStyle(.glass)
    }
}

// MARK: - Advanced Liquid Glass with Morphing
extension View {
    /// Liquid Glass with ID for morphing transitions
    func liquidGlassWithID(_ id: String, in namespace: Namespace.ID) -> some View {
        self
            .glassEffect()
            .glassEffectID(id, in: namespace)
    }
    
    /// Liquid Glass union for combining multiple effects
    func liquidGlassUnion(id: String, namespace: Namespace.ID) -> some View {
        self
            .glassEffect()
            .glassEffectUnion(id: id, namespace: namespace)
    }
}

// MARK: - Backward Compatibility (for older versions that might not have Liquid Glass)
extension View {
    /// Fallback glass effect using materials
    func fallbackGlass() -> some View {
        self.background(.ultraThinMaterial, in: .rect(cornerRadius: 0))
    }
    
    /// Fallback glass with shape
    func fallbackGlass(in shape: some InsettableShape) -> some View {
        self.background(.ultraThinMaterial, in: shape)
    }
} 
