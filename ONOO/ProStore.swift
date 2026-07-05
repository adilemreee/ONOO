//
//  ProStore.swift
//  One — Ders Defteri
//
//  StoreKit 2 abonelik yönetimi: ürünler, satın alma, yetki kontrolü.
//

import SwiftUI
import StoreKit

@MainActor
@Observable
final class ProStore {
    static let monthlyID = "one.pro.monthly"
    static let yearlyID = "one.pro.yearly"
    static let productIDs: Set<String> = [monthlyID, yearlyID]

    /// Satın alımlar açık mı? false iken tüm özellikler herkese açıktır,
    /// paywall ve kilitler görünmez. App Store Connect ürünleri hazır olunca true yap.
    static let purchasesEnabled = false

    /// Ücretsiz sürümde izin verilen aktif öğrenci sayısı
    static let freeStudentLimit = 2

    /// Uygulama genelindeki kilitler buna bakar: satın alımlar kapalıyken herkes Pro'dur.
    var isPro: Bool { !Self.purchasesEnabled || entitlementActive }

    /// App Store'dan doğrulanan gerçek abonelik durumu.
    /// Açılışta önbellekten gelir, ardından güncellenir.
    private(set) var entitlementActive: Bool = UserDefaults.standard.bool(forKey: "proActiveCache") {
        didSet { UserDefaults.standard.set(entitlementActive, forKey: "proActiveCache") }
    }

    private(set) var products: [Product] = []
    private(set) var isLoadingProducts = false
    var purchaseError: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { await listenForTransactions() }
        Task {
            await refreshEntitlements()
            await loadProducts()
        }
    }

    var monthly: Product? { products.first { $0.id == Self.monthlyID } }
    var yearly: Product? { products.first { $0.id == Self.yearlyID } }

    /// Yıllık planın aylığa göre yüzde kazancı
    var yearlySavingsPercent: Int? {
        guard let monthly, let yearly else { return nil }
        let fullYear = monthly.price * 12
        guard fullYear > 0 else { return nil }
        let saving = (fullYear - yearly.price) / fullYear * 100
        let percent = Int(NSDecimalNumber(decimal: saving).doubleValue.rounded())
        return percent > 0 ? percent : nil
    }

    func canAddStudent(activeCount: Int) -> Bool {
        isPro || activeCount < Self.freeStudentLimit
    }

    func loadProducts() async {
        guard products.isEmpty else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            products = try await Product.products(for: Self.productIDs)
                .sorted { $0.price < $1.price }
        } catch {
            purchaseError = "Ürünler yüklenemedi. İnternet bağlantını kontrol et."
        }
    }

    func purchase(_ product: Product) async {
        purchaseError = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlements()
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = "Satın alma tamamlanamadı. Lütfen tekrar dene."
        }
    }

    func restore() async {
        purchaseError = nil
        try? await AppStore.sync()
        await refreshEntitlements()
        if !entitlementActive {
            purchaseError = "Geri yüklenecek aktif abonelik bulunamadı."
        }
    }

    func refreshEntitlements() async {
        var active = false
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement,
               Self.productIDs.contains(transaction.productID),
               transaction.revocationDate == nil {
                active = true
            }
        }
        entitlementActive = active
    }

    private func listenForTransactions() async {
        for await update in Transaction.updates {
            if case .verified(let transaction) = update {
                await transaction.finish()
                await refreshEntitlements()
            }
        }
    }
}
