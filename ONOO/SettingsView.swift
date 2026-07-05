//
//  SettingsView.swift
//  One — Ders Defteri
//
//  Bildirim tercihleri ve veri bilgisi.
//

import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Student.name) private var students: [Student]
    @Query(sort: \Lesson.date) private var lessons: [Lesson]
    @Query(sort: \Payment.date) private var payments: [Payment]
    @Query(sort: \Homework.dueDate) private var homeworks: [Homework]

    @AppStorage("remindersEnabled") private var remindersEnabled = true
    @AppStorage("reminderMinutes") private var reminderMinutes = 60
    @AppStorage("homeworkRemindersEnabled") private var homeworkRemindersEnabled = true
    @AppStorage("homeworkReminderHour") private var homeworkReminderHour = 9
    @AppStorage("teacherName") private var teacherName = ""
    @State private var permissionDenied = false
    @State private var exportURLs: [URL] = []

    private let leadOptions = [15, 30, 60, 120]
    private let homeworkHourOptions = [9, 12, 18, 21]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Öğretmen adı", text: $teacherName)
                        .textContentType(.name)
                        .textInputAutocapitalization(.words)
                    Label("Ana sayfada \(teacherDisplayName) olarak görünür.",
                          systemImage: "person.crop.circle")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                } header: {
                    Text("Profil")
                } footer: {
                    Text("Boş bırakırsan ana sayfada Öğretmenim hitabı kullanılır.")
                }

                Section {
                    Toggle("Ders hatırlatıcıları", isOn: $remindersEnabled)
                    if remindersEnabled {
                        Picker("Ne kadar önce?", selection: $reminderMinutes) {
                            ForEach(leadOptions, id: \.self) { m in
                                Text(m >= 60 ? "\(m / 60) saat önce" : "\(m) dakika önce").tag(m)
                            }
                        }
                    }
                    if permissionDenied {
                        Label("Bildirim izni kapalı. iPhone Ayarlar > Bildirimler > One'dan izin verebilirsin.",
                              systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.red)
                    }
                } header: {
                    Text("Ders Bildirimleri")
                } footer: {
                    Text("Planlanan her ders için, ders saatinden önce hatırlatma bildirimi gönderilir.")
                }

                Section {
                    Toggle("Ödev hatırlatıcıları", isOn: $homeworkRemindersEnabled)
                    if homeworkRemindersEnabled {
                        Picker("Bildirim saati", selection: $homeworkReminderHour) {
                            ForEach(homeworkHourOptions, id: \.self) { hour in
                                Text(String(format: "%02d:00", hour)).tag(hour)
                            }
                        }
                    }
                } header: {
                    Text("Ödev Bildirimleri")
                } footer: {
                    Text("Aktif ödevler için teslimden bir gün önce, teslim günü ve gecikirse ertesi gün hatırlatma kurulur.")
                }

                Section("Veriler") {
                    Label {
                        Text("Verilerin iCloud hesabında saklanır ve iCloud'a giriş yapılmış cihazlar arasında otomatik eşitlenir.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.inkSoft)
                    } icon: {
                        Image(systemName: "icloud.fill")
                            .foregroundStyle(Theme.blue)
                    }
                }

                Section {
                    Button {
                        exportURLs = AppDataExport.makeCSVFiles(students: students,
                                                                 lessons: lessons,
                                                                 payments: payments,
                                                                 homeworks: homeworks)
                    } label: {
                        Label("CSV Dosyalarını Hazırla", systemImage: "tablecells")
                    }
                    if !exportURLs.isEmpty {
                        ShareLink(items: exportURLs) {
                            Label("CSV Dosyalarını Paylaş", systemImage: "square.and.arrow.up")
                        }
                    }
                } header: {
                    Text("Dışa Aktar")
                } footer: {
                    Text("Öğrenci, ders, ödeme ve ödev kayıtları ayrı CSV dosyaları olarak hazırlanır.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
            .navigationTitle("Ayarlar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Tamam") { dismiss() }
                }
            }
            .task {
                let settings = await UNUserNotificationCenter.current().notificationSettings()
                permissionDenied = settings.authorizationStatus == .denied
            }
            .onChange(of: remindersEnabled) {
                Task { await AppNotifications.resync(context: context) }
            }
            .onChange(of: reminderMinutes) {
                Task { await AppNotifications.resync(context: context) }
            }
            .onChange(of: homeworkRemindersEnabled) {
                Task { await AppNotifications.resync(context: context) }
            }
            .onChange(of: homeworkReminderHour) {
                Task { await AppNotifications.resync(context: context) }
            }
        }
    }

    private var teacherDisplayName: String {
        let trimmed = teacherName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Öğretmenim" }
        let formatted = trimmed.capitalized(with: Locale(identifier: "tr_TR"))
        return "\(formatted) öğretmenim"
    }
}
