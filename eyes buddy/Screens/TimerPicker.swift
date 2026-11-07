import SwiftUI

/// Timer length chooser: seven editable quick times plus a custom hours/minutes/seconds wheel.
struct TimerPicker: View {
    @Binding var seconds: Int

    @State private var customSelected = false
    @State private var quickTimes = SharedSettings.quickTimes
    @State private var isEditing = false
    @State private var editingSlot: Slot?

    private struct Slot: Identifiable { let id: Int }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 4)

    var body: some View {
        let isCustom = customSelected || !quickTimes.contains(seconds)

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(isEditing ? "Tap a time to change it." : "Tap a time to set the timer.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(EyeStyle.secondaryText)
                Spacer()
                Button(isEditing ? "Done" : "Edit times") { isEditing.toggle() }
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(minHeight: EyeStyle.minTapTarget)
            }

            LazyVGrid(columns: columns, spacing: 1) {
                ForEach(quickTimes.indices, id: \.self) { index in
                    let value = quickTimes[index]
                    chip(DurationFormat.short(value), selected: !isCustom && seconds == value, editable: isEditing) {
                        if isEditing {
                            editingSlot = Slot(id: index)
                        } else {
                            customSelected = false
                            seconds = value
                        }
                    }
                }
                chip("Custom", selected: isCustom, editable: false) {
                    isEditing = false
                    customSelected = true
                }
            }
            .background(EyeStyle.rule)

            if isCustom && !isEditing {
                TimeWheel(seconds: $seconds)
            }
        }
        .sheet(item: $editingSlot) { slot in
            QuickTimeEditor(initial: quickTimes[slot.id]) { newValue in
                quickTimes[slot.id] = newValue
                SharedSettings.quickTimes = quickTimes
            }
            .presentationDetents([.height(380)])
        }
    }

    private func chip(_ title: String, selected: Bool, editable: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if editable {
                    Image(systemName: "pencil").font(.system(size: 11, weight: .heavy))
                }
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: EyeStyle.minTapTarget + 8)
            .foregroundStyle(selected ? Color.black : .white)
            .background(selected ? Color.white : EyeStyle.ground)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Alarm-style scrolling hours / minutes / seconds wheels.
struct TimeWheel: View {
    @Binding var seconds: Int

    var body: some View {
        HStack(spacing: 0) {
            wheel(0...(SharedSettings.maxTotal / 3600 - 1), unit: "h", value: seconds / 3600) {
                set(hours: $0, minutes: seconds % 3600 / 60, seconds: seconds % 60)
            }
            wheel(0...59, unit: "min", value: seconds % 3600 / 60) {
                set(hours: seconds / 3600, minutes: $0, seconds: seconds % 60)
            }
            wheel(0...59, unit: "s", value: seconds % 60) {
                set(hours: seconds / 3600, minutes: seconds % 3600 / 60, seconds: $0)
            }
        }
        .frame(height: 140)
    }

    private func wheel(_ range: ClosedRange<Int>, unit: String, value: Int, onChange: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 0) {
            Picker(unit, selection: Binding(get: { value }, set: onChange)) {
                ForEach(range, id: \.self) { n in
                    Text("\(n)")
                        .font(.system(size: 22, weight: .heavy).monospacedDigit())
                        .tag(n)
                }
            }
            .pickerStyle(.wheel)
            Text(unit)
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(EyeStyle.secondaryText)
                .frame(width: 34, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
    }

    /// Never lets the timer drop to zero.
    private func set(hours: Int, minutes: Int, seconds s: Int) {
        seconds = SharedSettings.clampTotal(hours * 3600 + minutes * 60 + s)
    }
}

/// Sheet for changing one of the seven quick times.
private struct QuickTimeEditor: View {
    let initial: Int
    let onSave: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var value: Int

    init(initial: Int, onSave: @escaping (Int) -> Void) {
        self.initial = initial
        self.onSave = onSave
        _value = State(initialValue: initial)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Text("Quick time").font(.system(size: 17, weight: .heavy))
                Spacer()
                Button("Save") { onSave(value); dismiss() }
            }
            .font(.system(size: 17, weight: .heavy))
            Text(DurationFormat.short(value))
                .font(.system(size: 34, weight: .heavy))
            TimeWheel(seconds: $value)
        }
        .padding(EyeStyle.margin)
        .foregroundStyle(.white)
        .background(EyeStyle.ground)
        .preferredColorScheme(.dark)
    }
}
