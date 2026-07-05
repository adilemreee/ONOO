//
//  ReportsView.swift
//  One — Ders Defteri
//
//  Raporlar: aylık gelir, öğrenci bazında saat, ders durumu ve tahsilat oranı.
//

import SwiftUI
import SwiftData
import Charts

struct ReportsView: View {
    @Query(sort: \Lesson.date) private var lessons: [Lesson]
    @Query(sort: \Payment.date) private var payments: [Payment]
    @Query(sort: \Student.name) private var students: [Student]

    private struct MonthStat: Identifiable {
        let month: Date
        let label: String
        let earned: Double
        let collected: Double
        var id: Date { month }
    }

    private struct StudentHours: Identifiable {
        let name: String
        let hours: Double
        let color: Color
        var id: String { name }
    }

    private struct StatusStat: Identifiable {
        let status: LessonStatus
        let count: Int
        var id: String { status.rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                overviewGrid
                incomeChart
                hoursChart
                statusChart
                collectionCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Theme.paper.ignoresSafeArea())
        .navigationTitle("Raporlar")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Genel bakış

    private var overviewGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
            StatCard(icon: "graduationcap.fill", title: "Aktif Öğrenci",
                     value: "\(students.filter { !$0.isArchived }.count)", tint: Theme.blue)
            StatCard(icon: "checkmark.circle.fill", title: "İşlenen Ders",
                     value: "\(completedLessons.count)", tint: Theme.green)
            StatCard(icon: "clock.fill", title: "Toplam Süre",
                     value: Fmt.hours(totalMinutes), tint: Theme.amber)
            StatCard(icon: "banknote.fill", title: "Toplam Tahsilat",
                     value: Fmt.money(totalCollected), tint: Theme.board)
        }
        .padding(.top, 8)
    }

    // MARK: - Aylık gelir grafiği

    private var incomeChart: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Aylık Gelir", systemImage: "chart.bar.fill")
            Chart(monthStats) { stat in
                BarMark(
                    x: .value("Ay", stat.label),
                    y: .value("Tutar", stat.earned)
                )
                .position(by: .value("Tür", "Ders tutarı"))
                .foregroundStyle(by: .value("Tür", "Ders tutarı"))
                .cornerRadius(4)

                BarMark(
                    x: .value("Ay", stat.label),
                    y: .value("Tutar", stat.collected)
                )
                .position(by: .value("Tür", "Tahsil edilen"))
                .foregroundStyle(by: .value("Tür", "Tahsil edilen"))
                .cornerRadius(4)
            }
            .chartForegroundStyleScale([
                "Ders tutarı": Theme.blue,
                "Tahsil edilen": Theme.green
            ])
            .chartLegend(position: .bottom, spacing: 10)
            .frame(height: 220)
            .card()
        }
    }

    // MARK: - Öğrenci bazında saat

    @ViewBuilder
    private var hoursChart: some View {
        if !studentHours.isEmpty {
            VStack(spacing: 12) {
                SectionHeader(title: "Öğrenci Bazında Süre", systemImage: "person.2.fill")
                Chart(studentHours) { item in
                    BarMark(
                        x: .value("Saat", item.hours),
                        y: .value("Öğrenci", item.name)
                    )
                    .foregroundStyle(item.color)
                    .cornerRadius(4)
                    .annotation(position: .trailing) {
                        Text(String(format: "%.1f sa", item.hours).replacingOccurrences(of: ".", with: ","))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
                .chartXAxis(.hidden)
                .frame(height: CGFloat(studentHours.count) * 44 + 20)
                .card()
            }
        }
    }

    // MARK: - Ders durumu dağılımı

    @ViewBuilder
    private var statusChart: some View {
        if !statusStats.isEmpty {
            VStack(spacing: 12) {
                SectionHeader(title: "Ders Durumları", systemImage: "chart.pie.fill")
                HStack(spacing: 20) {
                    Chart(statusStats) { item in
                        SectorMark(
                            angle: .value("Adet", item.count),
                            innerRadius: .ratio(0.62),
                            angularInset: 2
                        )
                        .cornerRadius(4)
                        .foregroundStyle(item.status.tint)
                    }
                    .frame(width: 150, height: 150)
                    .overlay {
                        VStack(spacing: 0) {
                            Text("\(lessons.count)")
                                .font(.title3.weight(.bold))
                                .fontDesign(.serif)
                                .foregroundStyle(Theme.ink)
                            Text("ders")
                                .font(.caption2)
                                .foregroundStyle(Theme.inkSoft)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(statusStats) { item in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(item.status.tint)
                                    .frame(width: 9, height: 9)
                                Text(item.status.title)
                                    .font(.caption)
                                    .foregroundStyle(Theme.ink)
                                Spacer()
                                Text("\(item.count)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Theme.inkSoft)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .card()
            }
        }
    }

    // MARK: - Tahsilat oranı

    private var collectionCard: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Tahsilat Oranı", systemImage: "percent")
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(percentText)
                        .font(.title2.weight(.bold))
                        .fontDesign(.serif)
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text("\(Fmt.money(totalCollected)) / \(Fmt.money(totalEarned))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.inkSoft)
                }
                ProgressView(value: collectionRatio)
                    .tint(collectionRatio >= 0.9 ? Theme.green : (collectionRatio >= 0.6 ? Theme.amber : Theme.red))
                Text(collectionRatio >= 0.9
                     ? "Harika! Tahsilatların yolunda. 👏"
                     : "Bekleyen \(Fmt.money(max(totalEarned - totalCollected, 0))) alacağın var.")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
            }
            .card()
        }
    }

    // MARK: - Hesaplamalar

    private var completedLessons: [Lesson] {
        lessons.filter { $0.status == .completed }
    }

    private var totalMinutes: Int {
        completedLessons.reduce(0) { $0 + $1.duration }
    }

    private var totalEarned: Double {
        completedLessons.reduce(0) { $0 + $1.fee }
    }

    private var totalCollected: Double {
        payments.reduce(0) { $0 + $1.amount }
    }

    private var collectionRatio: Double {
        guard totalEarned > 0 else { return 1 }
        return min(totalCollected / totalEarned, 1)
    }

    private var percentText: String {
        "%\(Int((collectionRatio * 100).rounded()))"
    }

    private var monthStats: [MonthStat] {
        let months = (0..<6).reversed().map { Date().startOfMonth.adding(months: -$0) }
        return months.map { month in
            let next = month.adding(months: 1)
            let earned = completedLessons
                .filter { $0.date >= month && $0.date < next }
                .reduce(0.0) { $0 + $1.fee }
            let collected = payments
                .filter { $0.date >= month && $0.date < next }
                .reduce(0.0) { $0 + $1.amount }
            return MonthStat(month: month,
                             label: Fmt.monthShort.string(from: month),
                             earned: earned,
                             collected: collected)
        }
    }

    private var studentHours: [StudentHours] {
        students
            .map { StudentHours(name: $0.name.split(separator: " ").first.map(String.init) ?? $0.name,
                                hours: Double($0.totalMinutes) / 60.0,
                                color: $0.color) }
            .filter { $0.hours > 0 }
            .sorted { $0.hours > $1.hours }
    }

    private var statusStats: [StatusStat] {
        LessonStatus.allCases
            .map { status in StatusStat(status: status, count: lessons.filter { $0.status == status }.count) }
            .filter { $0.count > 0 }
    }
}
