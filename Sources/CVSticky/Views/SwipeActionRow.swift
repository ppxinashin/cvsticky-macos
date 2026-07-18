import AppKit
import SwiftUI

struct SwipeRowAction: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    let tint: Color
    var isDisabled = false
    let handler: () -> Void
}

struct SwipeActionRow<Content: View>: View {
    let actions: [SwipeRowAction]
    var isSelected = false
    var isSelectionActive = true
    var rowBackground: Color = Color(nsColor: .controlBackgroundColor)
    var onTap: () -> Void = {}
    @ViewBuilder var content: () -> Content

    @State private var restingOffset: CGFloat = 0
    @State private var dragOffset: CGFloat = 0
    @Environment(\.controlActiveState) private var controlActiveState

    private var maxReveal: CGFloat {
        CGFloat(actions.count) * 46 + 12
    }

    private var revealedOffset: CGFloat {
        min(max(restingOffset + dragOffset, 0), maxReveal)
    }

    private var revealProgress: Double {
        min(max(Double(revealedOffset / 24), 0), 1)
    }

    private var rowCornerRadius: CGFloat {
        (isSelected || revealedOffset > 0) ? 7 : 0
    }

    private var backgroundOpacity: Double {
        isSelected ? 1 : revealProgress
    }

    private var effectiveRowBackground: Color {
        guard isSelected else { return rowBackground }
        return hasEmphasizedSelection
            ? Color.accentColor
            : Color(nsColor: .unemphasizedSelectedContentBackgroundColor)
    }

    private var primaryForegroundStyle: Color {
        guard isSelected else { return Color.primary }
        return hasEmphasizedSelection
            ? Color(nsColor: .alternateSelectedControlTextColor)
            : Color.primary
    }

    private var secondaryForegroundStyle: Color {
        guard isSelected else { return Color.secondary }
        return hasEmphasizedSelection
            ? Color(nsColor: .alternateSelectedControlTextColor).opacity(0.72)
            : Color.secondary
    }

    private var hasEmphasizedSelection: Bool {
        isSelectionActive && controlActiveState == .key
    }

    var body: some View {
        ZStack(alignment: .leading) {
            HStack(spacing: 6) {
                ForEach(actions) { action in
                    Button {
                        guard !action.isDisabled else { return }
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                            restingOffset = 0
                        }
                        action.handler()
                    } label: {
                        Image(systemName: action.systemImage)
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 40, height: 32)
                            .foregroundStyle(.white)
                            .background(action.isDisabled ? Color.secondary.opacity(0.45) : action.tint)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(action.isDisabled)
                    .help(action.title)
                    .accessibilityLabel(action.title)
                }
            }
            .padding(.leading, 6)
            .frame(width: maxReveal, alignment: .leading)
            .frame(width: revealedOffset, alignment: .leading)
            .clipped()
            .opacity(revealProgress)
            .allowsHitTesting(revealedOffset > 16)
            .zIndex(2)

            content()
                .foregroundStyle(primaryForegroundStyle, secondaryForegroundStyle)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: rowCornerRadius, style: .continuous)
                        .fill(effectiveRowBackground)
                        .opacity(backgroundOpacity)
                )
                .clipShape(RoundedRectangle(cornerRadius: rowCornerRadius, style: .continuous))
                .offset(x: revealedOffset)
                .contentShape(Rectangle())
                .onTapGesture {
                    if restingOffset > 0 {
                        close()
                    } else {
                        onTap()
                    }
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 12)
                        .onChanged { value in
                            guard abs(value.translation.width) > abs(value.translation.height) else { return }
                            dragOffset = value.translation.width
                        }
                        .onEnded { value in
                            guard abs(value.translation.width) > abs(value.translation.height) else {
                                dragOffset = 0
                                return
                            }
                            let projected = restingOffset + value.predictedEndTranslation.width
                            dragOffset = 0
                            withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.88, blendDuration: 0.08)) {
                                restingOffset = projected > maxReveal * 0.45 ? maxReveal : 0
                            }
                        }
                )
                .zIndex(1)
        }
        .background {
            ListSelectionHighlightSuppressor()
                .allowsHitTesting(false)
        }
        .clipped()
        .animation(nil, value: dragOffset)
    }

    private func close() {
        withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.88, blendDuration: 0.08)) {
            restingOffset = 0
            dragOffset = 0
        }
    }
}

/// Preserves native List selection semantics while preventing AppKit from
/// painting a second, stationary selection layer behind the swipeable row.
struct ListSelectionHighlightSuppressor: NSViewRepresentable {
    func makeNSView(context: Context) -> SelectionHighlightMarkerView {
        SelectionHighlightMarkerView(frame: .zero)
    }

    func updateNSView(_ nsView: SelectionHighlightMarkerView, context: Context) {
        nsView.scheduleSuppression()
    }
}

final class SelectionHighlightMarkerView: NSView {
    private weak var enclosingTableView: NSTableView?
    private var suppressionScheduled = false

    override var isOpaque: Bool { false }
    override var acceptsFirstResponder: Bool { false }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        enclosingTableView = nil
        scheduleSuppression()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            enclosingTableView = nil
        }
        scheduleSuppression()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    fileprivate func scheduleSuppression() {
        guard window != nil, !suppressionScheduled else { return }
        suppressionScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.suppressionScheduled = false
            guard self.window != nil else { return }
            self.suppressEnclosingTableSelectionHighlight()
        }
    }

    private func suppressEnclosingTableSelectionHighlight() {
        if let enclosingTableView {
            applySuppression(to: enclosingTableView)
            return
        }

        var ancestor = superview
        while let view = ancestor {
            if let tableView = view as? NSTableView {
                enclosingTableView = tableView
                applySuppression(to: tableView)
                return
            }
            ancestor = view.superview
        }
    }

    private func applySuppression(to tableView: NSTableView) {
        guard tableView.selectionHighlightStyle != .none else { return }
        tableView.selectionHighlightStyle = .none
        tableView.needsDisplay = true
    }
}
