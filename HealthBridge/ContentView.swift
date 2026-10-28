import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var healthKit = HealthKitManager()

    private let cardCornerRadius: CGFloat = 14

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    statusCard
                    actionsCard
                    summaryCard
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("HealthBridge")
        }
    }

    private var statusCard: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "heart.text.square.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.pink.gradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("ヘルスケア連携")
                    .font(.headline)
                Text(healthKit.statusMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(cardBackground)
    }

    private var actionsCard: some View {
        VStack(spacing: 12) {
            Button {
                healthKit.requestAuthorization()
            } label: {
                Label("HealthKitの許可を求める", systemImage: "heart.text.square")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.pink)

            Button {
                healthKit.fetchTodaySummary()
            } label: {
                Label("今日のデータを再取得する", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                UIPasteboard.general.string = healthKit.summaryText
            } label: {
                Label("JSONをコピーする", systemImage: "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .controlSize(.large)
        .padding(16)
        .background(cardBackground)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("今日のサマリー(JSON)", systemImage: "doc.text")
                .font(.headline)
                .foregroundStyle(.primary)

            ScrollView {
                Text(healthKit.summaryText)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(minHeight: 160, maxHeight: 320)
            .background(
                Color(.tertiarySystemBackground),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
        }
        .padding(16)
        .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground))
    }
}

#Preview {
    ContentView()
}
