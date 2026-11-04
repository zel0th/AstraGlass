import SwiftUI

/// Measures the real header/footer, then gives the wheel all remaining height.
/// Short windows scroll; tall windows keep the summary at the bottom. There is
/// no upper limit on the chart's diameter: ChartWheel fits its available area.
struct ChartDashboardLayout: Layout {
    var viewportHeight: CGFloat
    private let gap: CGFloat = 20
    private let minimumChartHeight: CGFloat = 320

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 500
        let measured = heights(width: width, subviews: subviews)
        return CGSize(width: width, height: max(viewportHeight, measured.header + measured.footer + minimumChartHeight + 2 * gap))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 3 else { return }
        let measured = heights(width: bounds.width, subviews: subviews)
        let chartHeight = max(minimumChartHeight, bounds.height - measured.header - measured.footer - 2 * gap)
        subviews[0].place(at: bounds.origin, proposal: ProposedViewSize(width: bounds.width, height: measured.header))
        subviews[1].place(at: CGPoint(x: bounds.minX, y: bounds.minY + measured.header + gap),
                          proposal: ProposedViewSize(width: bounds.width, height: chartHeight))
        subviews[2].place(at: CGPoint(x: bounds.minX, y: bounds.minY + measured.header + chartHeight + 2 * gap),
                          proposal: ProposedViewSize(width: bounds.width, height: measured.footer))
    }

    private func heights(width: CGFloat, subviews: Subviews) -> (header: CGFloat, footer: CGFloat) {
        guard subviews.count == 3 else { return (0, 0) }
        let proposal = ProposedViewSize(width: width, height: nil)
        return (subviews[0].sizeThatFits(proposal).height, subviews[2].sizeThatFits(proposal).height)
    }
}
