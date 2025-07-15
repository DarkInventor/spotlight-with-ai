import SwiftUI

// MARK: - Modern Spotlight Liquid Glass Effects
// Creating sophisticated glass effects that match the new macOS Spotlight design

extension View {
    /// Search bar liquid glass effect - enhanced for modern Spotlight with refined colors
    @ViewBuilder
    func liquidGlassSearchBar() -> some View {
        self.background {
            ZStack {
                // Base material with enhanced blur - matching app search results
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                
                // Enhanced background fill matching AppSearchResultsView
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
                
                // Subtle inner shadow simulation
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.02))
                    .blur(radius: 1)
                    .offset(y: 1)
            }
        }
        .shadow(
            color: Color.black.opacity(0.10), 
            radius: 16, 
            x: 0, 
            y: 6
        )
    }
    
    /// Results container liquid glass effect - matching app search results
    @ViewBuilder
    func liquidGlassResults() -> some View {
        self.background {
            ZStack {
                // Base material matching AppSearchResultsView exactly
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .environment(\.colorScheme, .light)
        .shadow(
            color: Color.black.opacity(0.1), 
            radius: 8, 
            x: 0, 
            y: 2
        )
    }
    
    /// Button liquid glass effect with interactive states - refined colors
    @ViewBuilder
    func liquidGlassButton(isPressed: Bool = false) -> some View {
        self.background {
            ZStack {
                // Base material matching the refined approach
                RoundedRectangle(cornerRadius: 8)
                    .fill(.ultraThinMaterial)
                
                // Interactive hover state matching AppSearchResultsView
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isPressed ? 
                        Color.blue.opacity(0.08) : 
                        Color.clear
                    )
                
                // Subtle border
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        Color.white.opacity(isPressed ? 0.4 : 0.2),
                        lineWidth: 0.5
                    )
            }
        }
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
    }
    
    /// Attachment indicator liquid glass - refined
    @ViewBuilder
    func liquidGlassAttachment(color: Color = .blue) -> some View {
        self.background {
            ZStack {
                // Base material
                RoundedRectangle(cornerRadius: 6)
                    .fill(.ultraThinMaterial)
                
                // Color tint with refined opacity
                RoundedRectangle(cornerRadius: 6)
                    .fill(color.opacity(0.08))
                
                // Subtle border
                RoundedRectangle(cornerRadius: 6)
                    .stroke(color.opacity(0.2), lineWidth: 0.5)
            }
        }
    }
    
    /// Action button liquid glass with gradient - enhanced colors
    @ViewBuilder
    func liquidGlassActionButton(colors: [Color]) -> some View {
        self.background {
            ZStack {
                // Base gradient
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: colors),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Glass overlay with refined opacity
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .opacity(0.2)
                
                // Highlight
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.2),
                                Color.clear
                            ]),
                            startPoint: .topLeading,
                            endPoint: .center
                        )
                    )
                
                // Border
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
            }
        }
    }
    
    /// Divider liquid glass effect - refined
    @ViewBuilder
    func liquidGlassDivider() -> some View {
        self.background {
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.clear,
                            Color.primary.opacity(0.1),
                            Color.clear
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
        }
    }
}

// MARK: - Advanced Liquid Glass Effects with Refined Colors
extension View {
    /// Morphing liquid glass with animation support - enhanced
    @ViewBuilder
    func liquidGlassMorphing(id: String, in namespace: Namespace.ID) -> some View {
        self.background {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
                    .matchedGeometryEffect(id: "\(id)-background", in: namespace)
                
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.08),
                                Color.clear
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .matchedGeometryEffect(id: "\(id)-overlay", in: namespace)
                
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                    .matchedGeometryEffect(id: "\(id)-border", in: namespace)
            }
        }
    }
    
    /// Interactive liquid glass with hover effects - refined colors
    @ViewBuilder
    func liquidGlassInteractive(isHovered: Bool = false) -> some View {
        self.background {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
                
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        isHovered ? 
                        Color.blue.opacity(0.08) : 
                        Color.clear
                    )
                
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        Color.white.opacity(isHovered ? 0.2 : 0.1),
                        lineWidth: isHovered ? 1 : 0.5
                    )
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
}

// MARK: - Specialized Spotlight Components with Refined Colors
extension View {
    /// Individual result item - matching AppSearchResultsView
    @ViewBuilder
    func spotlightResultItem(isSelected: Bool = false) -> some View {
        self.liquidGlassInteractive(isHovered: isSelected)
    }
}

// MARK: - Backward Compatibility with Enhanced Colors
extension View {
    /// Backward compatibility for existing code
    @ViewBuilder
    func applyLiquidGlass() -> some View {
        self.liquidGlassSearchBar()
    }
    
    /// Backward compatibility with shape parameter
    @ViewBuilder
    func applyLiquidGlass(in shape: some Shape) -> some View {
        self.background(.regularMaterial, in: shape)
    }
} 

// MARK: - Backward Compatibility for liquidGlassRect with refined colors
extension View {
    @ViewBuilder
    func liquidGlassRect(cornerRadius: CGFloat = 16.0) -> some View {
        self.background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.regularMaterial)
        )
    }
} 
