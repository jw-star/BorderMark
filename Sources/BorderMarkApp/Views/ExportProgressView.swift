import SwiftUI

/// 导出弹窗：进行中显示进度和取消，结束后显示结果。
struct ExportProgressView: View {
    private static let width: CGFloat = 400
    private static let failureListMaxHeight: CGFloat = 140

    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(spacing: 18) {
            if state.exportPhase == .finished {
                finished
            } else {
                running
            }
        }
        .padding(24)
        .frame(width: Self.width)
        .interactiveDismissDisabled(state.exportPhase == .running)
    }

    // MARK: - 进行中

    private var running: some View {
        let report = state.exportReport
        return VStack(spacing: 14) {
            Text(report.isBatch ? "正在批量导出" : "正在导出")
                .font(.headline)
            ProgressView(value: report.progress)
                .accessibilityLabel("导出进度")
            HStack {
                Text("已完成 \(report.finished) / \(report.total) 张")
                    .monospacedDigit()
                Spacer()
                Text("\(Int((report.progress * 100).rounded()))%")
                    .monospacedDigit()
            }
            .font(.callout)
            .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("取消", role: .cancel) { state.cancelExport() }
                    .keyboardShortcut(.cancelAction)
                    .help("不再开始新的照片；正在处理的几张会做完")
            }
        }
    }

    // MARK: - 结束

    private var finished: some View {
        let report = state.exportReport
        let hasProblem = !report.failures.isEmpty || report.wasCancelled
        return VStack(spacing: 14) {
            Image(systemName: hasProblem ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(hasProblem ? Color.orange : Color.green)
                .accessibilityHidden(true)
            Text(title(for: report))
                .font(.headline)
            Text(detail(for: report))
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if !report.failures.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(report.failures.enumerated()), id: \.offset) { _, failure in
                            Text(failure)
                                .font(.caption)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: Self.failureListMaxHeight)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
            }

            HStack {
                if report.succeeded > 0 {
                    Button("在访达中显示") { state.revealExportLocation() }
                }
                Spacer()
                Button("完成") { state.dismissExportReport() }
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func title(for report: ExportReport) -> String {
        if report.wasCancelled { return "导出已取消" }
        if report.succeeded == 0 { return "导出失败" }
        return report.failures.isEmpty ? "导出完成" : "部分导出失败"
    }

    private func detail(for report: ExportReport) -> String {
        var parts = ["成功 \(report.succeeded) 张"]
        if !report.failures.isEmpty { parts.append("失败 \(report.failures.count) 张") }
        if report.wasCancelled { parts.append("未处理 \(report.total - report.finished) 张") }
        let summary = parts.joined(separator: "，")
        guard report.succeeded > 0, let location = report.location else { return summary }
        let folder = report.isBatch ? location : location.deletingLastPathComponent()
        return "\(summary)\n保存在 \(folder.lastPathComponent)"
    }
}
