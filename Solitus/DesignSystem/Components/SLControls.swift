import SwiftUI

/// A segmented control in the app's style (DESIGN.md 7.4): a recessed track
/// with a raised selected piece.
struct SLSegmented<Value: Hashable>: View {
    let options: [(value: Value, title: String)]
    @Binding var selection: Value

    @Environment(\.slTheme) private var theme
    @Namespace private var namespace

    var body: some View {
        let metrics = theme.metrics
        HStack(spacing: 0) {
            ForEach(options, id: \.value) { option in
                let isSelected = option.value == selection
                Button {
                    withAnimation(.snappy(duration: 0.22)) {
                        selection = option.value
                    }
                } label: {
                    Text(option.title)
                        .font(theme.font(.body))
                        .foregroundStyle(isSelected ? theme.palette.textPrimary : theme.palette.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 6)
                        .frame(maxWidth: .infinity, minHeight: metrics.minTapTarget - 6)
                        .background {
                            if isSelected {
                                SLSurface(role: .raised)
                                    .matchedGeometryEffect(id: "selected", in: namespace)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .padding(3)
        .background(SLSurface(role: .well))
    }
}

/// A stepper in the app's style: round raised buttons either side of the
/// value.
struct SLStepper: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step = 1
    /// How the value is written, such as "85%" or "2 days".
    var format: (Int) -> String = { String($0) }

    @Environment(\.slTheme) private var theme

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(theme.font(.body))
                .foregroundStyle(theme.palette.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 4)
            button("minus", enabled: value - step >= range.lowerBound) { value -= step }
                .accessibilityLabel("Less")
            Text(format(value))
                .font(theme.font(.body).weight(.semibold))
                .foregroundStyle(theme.palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(minWidth: 58)
                .contentTransition(.numericText())
            button("plus", enabled: value + step <= range.upperBound) { value += step }
                .accessibilityLabel("More")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
        .accessibilityValue(format(value))
    }

    private func button(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        let tap = theme.metrics.minTapTarget
        return Button {
            withAnimation(.snappy(duration: 0.15)) { action() }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.palette.textPrimary)
                .frame(width: 36, height: 36)
                .background(SLSurface(role: .raised, cornerRadius: 18))
                .frame(width: tap, height: tap)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
    }
}

/// A switch in the app's style: a recessed track with a bead.
struct SLToggle: View {
    let label: String
    var note: String?
    @Binding var isOn: Bool

    @Environment(\.slTheme) private var theme

    var body: some View {
        let palette = theme.palette
        Button {
            withAnimation(.snappy(duration: 0.2)) {
                isOn.toggle()
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(theme.font(.body))
                        .foregroundStyle(palette.textPrimary)
                    if let note {
                        Text(note)
                            .font(theme.font(.secondary))
                            .foregroundStyle(palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 4)
                ZStack(alignment: isOn ? .trailing : .leading) {
                    SLSurface(role: .well, cornerRadius: 16)
                    if isOn {
                        SLSurface(role: .raised, cornerRadius: 16)
                    }
                    Circle()
                        .fill(isOn ? palette.textPrimary : palette.textFaint)
                        .frame(width: 24, height: 24)
                        .padding(4)
                }
                .frame(width: 54, height: 32)
            }
            .frame(minHeight: theme.metrics.minTapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(note ?? "")
    }
}

/// A raised chip: a preferred time or day, a weekday, a tint swatch's frame.
struct SLChip: View {
    let title: String
    var isSelected = false
    let action: () -> Void

    @Environment(\.slTheme) private var theme

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(theme.font(.body))
                .foregroundStyle(isSelected ? theme.palette.textPrimary : theme.palette.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, minHeight: theme.metrics.minTapTarget)
                .background(SLSurface(role: isSelected ? .raised : .well, cornerRadius: theme.metrics.wellRadius))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// A text field in a recessed well.
struct SLTextField: View {
    let placeholder: String
    @Binding var text: String

    @Environment(\.slTheme) private var theme

    var body: some View {
        TextField(placeholder, text: $text, prompt: Text(placeholder).foregroundStyle(theme.palette.textFaint))
            .font(theme.font(.body))
            .foregroundStyle(theme.palette.textPrimary)
            .tint(theme.palette.textPrimary)
            .submitLabel(.done)
            .padding(.horizontal, 12)
            .frame(minHeight: theme.metrics.minTapTarget)
            .background(SLSurface(role: .well))
    }
}

/// A titled group of controls on a form or settings page.
struct SLGroup<Content: View>: View {
    let title: String
    let content: Content

    @Environment(\.slTheme) private var theme

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(theme.font(.secondary))
                .foregroundStyle(theme.palette.textSecondary)
                .padding(.horizontal, 4)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(theme.metrics.innerPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SLSurface(role: .panel))
        }
    }
}

/// A line of small explanatory text under a control.
struct SLNote: View {
    let text: String

    @Environment(\.slTheme) private var theme

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(theme.font(.secondary))
            .foregroundStyle(theme.palette.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
