import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var healthKit = HealthKitManager()

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(healthKit.statusMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    healthKit.requestAuthorization()
                } label: {
                    Label("HealthKitの許可を求める", systemImage: "heart.text.square")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

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

                ScrollView {
                    Text(healthKit.summaryText)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding()
            .navigationTitle("HealthBridge")
        }
    }
}

#Preview {
    ContentView()
}
