//
//  OneApp.swift
//  One — Ders Defteri
//

import SwiftUI
import SwiftData

@main
struct OneApp: App {
    let container: ModelContainer
    @State private var showSplash = true
    @State private var proStore = ProStore()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    init() {
        let schema = Schema([Student.self, Lesson.self, Payment.self, Homework.self, TopicProgress.self, RecurringLessonTemplate.self])
        do {
            // Veriler iCloud'a (CloudKit) senkronize edilir
            let cloudConfig = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            container = try ModelContainer(for: schema, configurations: [cloudConfig])
        } catch {
            // iCloud kullanılamıyorsa yerel depolamaya düş
            do {
                let localConfig = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
                container = try ModelContainer(for: schema, configurations: [localConfig])
            } catch {
                fatalError("Model container oluşturulamadı: \(error)")
            }
        }
        Self.configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                if !hasCompletedOnboarding {
                    OnboardingView()
                        .transition(.opacity)
                        .zIndex(1)
                }
                if showSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(2)
                }
            }
            .task {
                try? await Task.sleep(for: .seconds(1.9))
                withAnimation(.easeOut(duration: 0.5)) {
                    showSplash = false
                }
            }
            .environment(proStore)
        }
        .modelContainer(container)
    }

    /// Navigasyon başlıklarına "defter" hissi veren serif yazı tipi
    private static func configureAppearance() {
        func serif(_ size: CGFloat, _ weight: UIFont.Weight) -> UIFont {
            let base = UIFont.systemFont(ofSize: size, weight: weight)
            if let descriptor = base.fontDescriptor.withDesign(.serif) {
                return UIFont(descriptor: descriptor, size: size)
            }
            return base
        }
        let nav = UINavigationBar.appearance()
        nav.largeTitleTextAttributes = [
            .font: serif(32, .bold),
            .foregroundColor: Theme.inkUI
        ]
        nav.titleTextAttributes = [
            .font: serif(17, .semibold),
            .foregroundColor: Theme.inkUI
        ]
    }
}
