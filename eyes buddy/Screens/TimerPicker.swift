import SwiftUI
import UIKit

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
                Text(L(isEditing ? "Tap a time to change it." : "Tap a time to set the timer."))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(EyeStyle.secondaryText)
                Spacer()
                Button(L(isEditing ? "Done" : "Edit times")) { isEditing.toggle() }
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
                chip(L("Custom"), selected: isCustom, editable: false) {
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
                QuickActions.shared.refresh()
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
///
/// Built on UIKit's `UIPickerView` with its own fixed data source. SwiftUI's wheel `Picker` keeps a
/// separate copy of its rows, and on iOS 17 UIKit can ask for a row after SwiftUI has already dropped
/// them (seen when the whole screen is rebuilt on a language change), which crashes with an
/// index-out-of-range error.
struct TimeWheel: UIViewRepresentable {
    @Binding var seconds: Int

    func makeCoordinator() -> Coordinator { Coordinator(seconds: $seconds) }

    func makeUIView(context: Context) -> UIPickerView {
        let picker = UIPickerView()
        picker.dataSource = context.coordinator
        picker.delegate = context.coordinator
        picker.overrideUserInterfaceStyle = .dark
        context.coordinator.show(seconds, in: picker)
        return picker
    }

    func updateUIView(_ picker: UIPickerView, context: Context) {
        context.coordinator.seconds = $seconds
        context.coordinator.show(seconds, in: picker)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIPickerView, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 300, height: 140)
    }

    final class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
        var seconds: Binding<Int>
        /// Hours (0...7, a Live Activity lasts at most 8 h), minutes, seconds.
        private let rowCounts = [SharedSettings.maxTotal / 3600, 60, 60]

        init(seconds: Binding<Int>) { self.seconds = seconds }

        /// Moves the wheels to `total`, only touching those that differ.
        func show(_ total: Int, in picker: UIPickerView) {
            let rows = [total / 3600, total % 3600 / 60, total % 60]
            for (component, row) in rows.enumerated() where picker.selectedRow(inComponent: component) != row {
                picker.selectRow(row, inComponent: component, animated: false)
            }
        }

        func numberOfComponents(in pickerView: UIPickerView) -> Int { rowCounts.count }

        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            rowCounts[component]
        }

        func pickerView(_ pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat {
            max(pickerView.bounds.width / CGFloat(rowCounts.count), 80)
        }

        func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat { 40 }

        func pickerView(
            _ pickerView: UIPickerView,
            viewForRow row: Int,
            forComponent component: Int,
            reusing view: UIView?
        ) -> UIView {
            let label = (view as? UILabel) ?? UILabel()
            label.textAlignment = .center
            label.font = .monospacedDigitSystemFont(ofSize: 20, weight: .heavy)
            label.textColor = .white
            let units = [L("wheel.h"), L("wheel.min"), L("wheel.s")]
            label.text = "\(row) \(units[component])"
            return label
        }

        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            let rows = (0..<rowCounts.count).map { pickerView.selectedRow(inComponent: $0) }
            // Never lets the timer drop to zero.
            let total = SharedSettings.clampTotal(rows[0] * 3600 + rows[1] * 60 + rows[2])
            seconds.wrappedValue = total
            show(total, in: pickerView)
        }
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
                Button(L("Cancel")) { dismiss() }
                Spacer()
                Text(L("Quick time")).font(.system(size: 17, weight: .heavy))
                Spacer()
                Button(L("Save")) { onSave(value); dismiss() }
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
