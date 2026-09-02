import SwiftUI

/// The three materials the quick panel can wear. Glass rides the native glass window; the others draw themselves.
enum PanelStyle: String, CaseIterable, Identifiable {
    case glass, soft, leather
    var id: String { rawValue }

    var title: String {
        switch self {
        case .glass: return "Glass"
        case .soft: return "Soft"
        case .leather: return "Leather"
        }
    }

    var subtitle: String {
        switch self {
        case .glass: return "Control Center, macOS 26"
        case .soft: return "Light and tactile"
        case .leather: return "Stitched leather, brass"
        }
    }

    /// Transparent margin around the tiles: shadow room for the drawn sheets, fade-out room for the glass blur.
    var sheetInset: CGFloat { self == .glass ? 16 : 18 }
}

// MARK: - Palette

private extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: alpha)
    }
}

struct PanelTheme {
    let style: PanelStyle
    /// Snapshot mode: Liquid Glass can't render offscreen, so draw the flat fallback tiles instead.
    static var flatGlass = false

    static let softBg = Color(hex: 0xE4E7EE)
    static let softDark = Color(hex: 0xA3ACBE, alpha: 0.55)
    static let softLight = Color.white.opacity(0.95)
    static let softAccent = Color(hex: 0x2F6BFF)
    static let leatherText = Color(hex: 0xF7E8D6)
    static let brass = Color(hex: 0xFFD98A)

    var text: Color {
        switch style { case .glass: return .primary; case .soft: return Color(hex: 0x2B2F3A); case .leather: return PanelTheme.leatherText }
    }
    var subtext: Color {
        switch style { case .glass: return .secondary; case .soft: return Color(hex: 0x7A8090); case .leather: return PanelTheme.leatherText.opacity(0.7) }
    }
    var value: Color {
        switch style { case .glass: return .secondary; case .soft: return Color(hex: 0x4A5060); case .leather: return PanelTheme.brass }
    }
    func glyph(on: Bool) -> Color {
        switch style {
        case .glass: return .white
        case .soft: return on ? PanelTheme.softAccent : Color(hex: 0x4A5060)
        case .leather: return on ? Color(hex: 0x5A2E12) : Color(hex: 0xD9C3A5)
        }
    }

    /// Background for the round icon buttons.
    @ViewBuilder func circle(on: Bool) -> some View {
        switch style {
        case .glass:
            Circle().fill(on ? Color.accentColor : Color.white.opacity(0.18))
        case .soft:
            Circle().fill(PanelTheme.softBg)
                .innerShadow(Circle(), color: PanelTheme.softDark, radius: 4, x: 3, y: 3)
                .innerShadow(Circle(), color: PanelTheme.softLight, radius: 4, x: -3, y: -3)
        case .leather:
            Circle().fill(RadialGradient(
                colors: on ? [Color(hex: 0xFFF2C8), Color(hex: 0xD8B25A), Color(hex: 0x9A7422)]
                           : [Color(hex: 0x8A6A4A), Color(hex: 0x4A2F1A), Color(hex: 0x2C1A0D)],
                center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 26))
                .shadow(color: .black.opacity(0.5), radius: 2, y: 2)
        }
    }
}

// MARK: - Sheet, tiles, buttons

extension View {
    func panelSheet(_ style: PanelStyle) -> some View { modifier(SheetModifier(style: style)) }
    func panelTile<S: InsettableShape>(_ shape: S, style: PanelStyle) -> some View { modifier(TileModifier(style: style, shape: shape)) }

    /// Fake inner shadow: a blurred stroke masked to the shape.
    func innerShadow<S: InsettableShape>(_ shape: S, color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        overlay(shape.stroke(color, lineWidth: radius * 2).blur(radius: radius).offset(x: x, y: y).mask(shape))
    }
}

private struct SheetModifier: ViewModifier {
    let style: PanelStyle
    func body(content: Content) -> some View {
        switch style {
        case .glass:
            // No sheet: the tiles float on a feathered blur (drawn by the window), like Control Center's modules.
            if #available(macOS 26.0, *), !PanelTheme.flatGlass {
                GlassEffectContainer(spacing: 10) { content }.padding(style.sheetInset)
            } else {
                content.padding(style.sheetInset)
            }
        case .soft:
            content
                .background(RoundedRectangle(cornerRadius: 28).fill(PanelTheme.softBg))
                .shadow(color: .black.opacity(0.32), radius: 22, y: 12)
                .padding(style.sheetInset)
        case .leather:
            content
                .background(LeatherSurface(cornerRadius: 26))
                .shadow(color: .black.opacity(0.5), radius: 22, y: 12)
                .padding(style.sheetInset)
        }
    }
}

private struct TileModifier<S: InsettableShape>: ViewModifier {
    let style: PanelStyle
    let shape: S
    func body(content: Content) -> some View {
        switch style {
        case .glass:
            if #available(macOS 26.0, *), !PanelTheme.flatGlass {
                content.glassEffect(.regular, in: shape)
                    .overlay(shape.strokeBorder(Color.white.opacity(0.12)))
            } else {
                content.background(shape.fill(Color.white.opacity(0.10)))
                    .overlay(shape.strokeBorder(Color.white.opacity(0.16)))
            }
        case .soft:
            content.background(
                shape.fill(PanelTheme.softBg)
                    .shadow(color: PanelTheme.softDark, radius: 9, x: 6, y: 6)
                    .shadow(color: PanelTheme.softLight, radius: 9, x: -6, y: -6)
            )
        case .leather:
            content.background(
                shape.fill(LinearGradient(colors: [Color(hex: 0x7A3F1F), Color(hex: 0x5C2C12)], startPoint: .top, endPoint: .bottom))
                    .innerShadow(shape, color: .black.opacity(0.55), radius: 4, x: 0, y: 3)
            )
            .overlay(shape.strokeBorder(Color(hex: 0xFFDCB4, alpha: 0.15)))
        }
    }
}

/// Leather sheet: warm gradient, diagonal grain, a highlight, and a dashed stitch just inside the edge.
struct LeatherSurface: View {
    let cornerRadius: CGFloat
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(LinearGradient(colors: [Color(hex: 0x8A4A26), Color(hex: 0x6A3418), Color(hex: 0x55290F)],
                                     startPoint: .top, endPoint: .bottom))
            Canvas { ctx, size in
                var path = Path()
                var x: CGFloat = -size.height
                while x < size.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x + size.height, y: size.height))
                    x += 4
                }
                ctx.stroke(path, with: .color(.black.opacity(0.06)), lineWidth: 1.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(RadialGradient(colors: [.white.opacity(0.14), .clear], center: UnitPoint(x: 0.2, y: 0),
                                     startRadius: 0, endRadius: 320))
            RoundedRectangle(cornerRadius: cornerRadius - 6)
                .strokeBorder(Color(hex: 0xFFE1BE, alpha: 0.45), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                .padding(7)
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(LinearGradient(colors: [.white.opacity(0.3), .black.opacity(0.4)], startPoint: .top, endPoint: .bottom), lineWidth: 1)
        }
    }
}

/// Settings/Quit/Pin buttons in each material.
struct PanelButton: View {
    let title: String
    let style: PanelStyle
    var prominent = false
    let action: () -> Void

    var body: some View {
        switch style {
        case .glass:
            Button(title, action: action).glassButton(prominent: prominent)
        case .soft:
            Button(action: action) {
                Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(prominent ? PanelTheme.softAccent : Color(hex: 0x4A5060))
                    .padding(.horizontal, 14).padding(.vertical, 7)
            }
            .buttonStyle(.plain)
            .panelTile(Capsule(), style: .soft)
        case .leather:
            Button(action: action) {
                Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(prominent ? PanelTheme.brass : PanelTheme.leatherText)
                    .padding(.horizontal, 14).padding(.vertical, 7)
            }
            .buttonStyle(.plain)
            .background(Capsule().fill(LinearGradient(colors: [Color(hex: 0x7A3F1F), Color(hex: 0x5C2C12)], startPoint: .top, endPoint: .bottom)))
            .overlay(Capsule().strokeBorder(Color(hex: 0xFFE1BE, alpha: 0.35), style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
            .shadow(color: .black.opacity(0.5), radius: 2, y: 2)
        }
    }
}

extension View {
    /// Liquid Glass buttons on macOS 26, bordered elsewhere.
    @ViewBuilder func glassButton(prominent: Bool = false) -> some View {
        if #available(macOS 26.0, *), !PanelTheme.flatGlass {
            if prominent { buttonStyle(.glassProminent) } else { buttonStyle(.glass) }
        } else {
            if prominent { buttonStyle(.borderedProminent) } else { buttonStyle(.bordered) }
        }
    }
}

/// Static miniature of the panel for the Appearance cards.
struct PanelPreview: View {
    let style: PanelStyle
    private var theme: PanelTheme { PanelTheme(style: style) }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "circle.lefthalf.filled").font(.system(size: 9, weight: .medium))
                    .foregroundStyle(theme.glyph(on: true))
                    .frame(width: 20, height: 20).background(theme.circle(on: true))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Focal").font(.system(size: 8, weight: .semibold)).foregroundStyle(theme.text)
                    Text("On").font(.system(size: 7)).foregroundStyle(theme.subtext)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6).padding(.vertical, 5)
            .panelTile(Capsule(), style: style)
            VStack(alignment: .leading, spacing: 5) {
                Text("Strength").font(.system(size: 8, weight: .semibold)).foregroundStyle(theme.text)
                ThinSlider(value: .constant(0.8), range: 0.2...1, disabled: false, style: style, compact: true)
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .panelTile(RoundedRectangle(cornerRadius: 10), style: style)
        }
        .padding(7)
        .frame(width: 128)
        .background(previewSheet)
    }

    @ViewBuilder private var previewSheet: some View {
        switch style {
        case .glass:
            RoundedRectangle(cornerRadius: 14).fill(Color(white: 0.16))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.12)))
        case .soft:
            RoundedRectangle(cornerRadius: 14).fill(PanelTheme.softBg)
        case .leather:
            LeatherSurface(cornerRadius: 14)
        }
    }
}
