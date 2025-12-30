//
//  SubscriptionManager.swift
//  BabyInCarApp
//
//  In-app purchase and subscription management
//

import Foundation
import StoreKit
import SwiftUI

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    // MARK: - Published Properties
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Product IDs
    enum ProductID: String, CaseIterable {
        case monthlyPremium = "com.babyincar.premium.monthly"
        case yearlyPremium = "com.babyincar.premium.yearly"
        case lifetimePremium = "com.babyincar.premium.lifetime"
        case familyMonthly = "com.babyincar.family.monthly"
        case familyYearly = "com.babyincar.family.yearly"

        var displayName: String {
            switch self {
            case .monthlyPremium: return "Premium Monthly"
            case .yearlyPremium: return "Premium Yearly"
            case .lifetimePremium: return "Premium Lifetime"
            case .familyMonthly: return "Family Monthly"
            case .familyYearly: return "Family Yearly"
            }
        }
    }

    // MARK: - Subscription Plans
    struct SubscriptionPlan: Identifiable {
        let id: String
        var product: Product?
        let name: String
        let description: String
        let monthlyPrice: String
        let features: [String]
        let isBestValue: Bool
        let savings: String?
    }

    var availablePlans: [SubscriptionPlan] {
        [
            SubscriptionPlan(
                id: ProductID.monthlyPremium.rawValue,
                product: products.first { $0.id == ProductID.monthlyPremium.rawValue },
                name: "Premium",
                description: "Monthly subscription",
                monthlyPrice: "$6.99",
                features: [
                    "100% content access",
                    "Unlimited offline downloads",
                    "All 10+ languages",
                    "Unlimited emergency cry-stop",
                    "CarPlay & Android Auto"
                ],
                isBestValue: false,
                savings: nil
            ),
            SubscriptionPlan(
                id: ProductID.yearlyPremium.rawValue,
                product: products.first { $0.id == ProductID.yearlyPremium.rawValue },
                name: "Premium Yearly",
                description: "Best value",
                monthlyPrice: "$4.17/mo",
                features: [
                    "Everything in Premium",
                    "Billed as $49.99/year",
                    "Save 40%"
                ],
                isBestValue: true,
                savings: "40%"
            ),
            SubscriptionPlan(
                id: ProductID.lifetimePremium.rawValue,
                product: products.first { $0.id == ProductID.lifetimePremium.rawValue },
                name: "Lifetime",
                description: "One-time purchase",
                monthlyPrice: "$149.99",
                features: [
                    "Everything in Premium",
                    "Never pay again",
                    "All future updates"
                ],
                isBestValue: false,
                savings: nil
            )
        ]
    }

    // MARK: - Computed Properties
    var isPremium: Bool {
        !purchasedProductIDs.isEmpty
    }

    private var updateListenerTask: Task<Void, Error>?

    private init() {
        updateListenerTask = listenForTransactions()
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Load Products
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let productIDs = ProductID.allCases.map { $0.rawValue }
            products = try await Product.products(for: Set(productIDs))
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
        }
    }

    // MARK: - Purchase
    func purchase(_ product: Product) async -> Bool {
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await updatePurchasedProducts()
                await transaction.finish()
                return true

            case .userCancelled:
                return false

            case .pending:
                return false

            @unknown default:
                return false
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            return false
        }
    }

    func purchase(planId: String) async -> Bool {
        guard let product = products.first(where: { $0.id == planId }) else {
            return false
        }
        return await purchase(product)
    }

    // MARK: - Restore Purchases
    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Transaction Listener
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached { [weak self] in
            for await result in Transaction.updates {
                do {
                    guard let self = self else { return }
                    let transaction = try await MainActor.run {
                        try self.checkVerified(result)
                    }
                    await self.updatePurchasedProducts()
                    await transaction.finish()
                } catch {
                    // Transaction failed verification
                }
            }
        }
    }

    // MARK: - Verification
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Update Purchased Products
    func updatePurchasedProducts() async {
        var purchased: Set<String> = []

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                if transaction.revocationDate == nil {
                    purchased.insert(transaction.productID)
                }
            } catch {
                // Handle verification error
            }
        }

        await MainActor.run {
            purchasedProductIDs = purchased
        }
    }

    enum StoreError: Error {
        case failedVerification
    }
}

// MARK: - Subscription View
struct SubscriptionView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var selectedPlan: String = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.yellow)

                        Text("Upgrade to Premium")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.appText)

                        Text("Unlock all features and content")
                            .font(.system(size: 16))
                            .foregroundColor(.appTextSecondary)
                    }
                    .padding(.top, 20)

                    // Features list
                    VStack(alignment: .leading, spacing: 12) {
                        FeatureItem(icon: "infinity", text: "100% content library access")
                        FeatureItem(icon: "arrow.down.circle.fill", text: "Unlimited offline downloads")
                        FeatureItem(icon: "globe", text: "All 10+ language fairy tales")
                        FeatureItem(icon: "exclamationmark.triangle.fill", text: "Unlimited emergency cry-stop")
                        FeatureItem(icon: "car.fill", text: "CarPlay & Android Auto")
                        FeatureItem(icon: "waveform", text: "Advanced AI personalization")
                    }
                    .padding(.horizontal, 24)

                    // Plans
                    VStack(spacing: 12) {
                        ForEach(subscriptionManager.availablePlans) { plan in
                            PlanCard(
                                plan: plan,
                                isSelected: selectedPlan == plan.id
                            ) {
                                selectedPlan = plan.id
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    // Subscribe button
                    Button {
                        Task {
                            if await subscriptionManager.purchase(planId: selectedPlan) {
                                dismiss()
                            }
                        }
                    } label: {
                        HStack {
                            if subscriptionManager.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Subscribe Now")
                            }
                        }
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedPlan.isEmpty ? Color.appPrimary.opacity(0.5) : Color.appPrimary)
                        )
                    }
                    .disabled(selectedPlan.isEmpty || subscriptionManager.isLoading)
                    .padding(.horizontal, 20)

                    // Restore purchases
                    Button {
                        Task {
                            await subscriptionManager.restorePurchases()
                        }
                    } label: {
                        Text("Restore Purchases")
                            .font(.system(size: 14))
                            .foregroundColor(.appPrimary)
                    }

                    // Legal text
                    Text("Payment will be charged to your Apple ID account. Subscription automatically renews unless canceled at least 24 hours before the end of the current period.")
                        .font(.system(size: 11))
                        .foregroundColor(.appTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)
                }
            }
            .background(Color.appBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            // Pre-select best value plan
            if let bestValue = subscriptionManager.availablePlans.first(where: { $0.isBestValue }) {
                selectedPlan = bestValue.id
            }
        }
    }
}

// MARK: - Feature Item
struct FeatureItem: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.appPrimary)
                .frame(width: 24)

            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.appText)
        }
    }
}

// MARK: - Plan Card
struct PlanCard: View {
    let plan: SubscriptionManager.SubscriptionPlan
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(plan.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.appText)

                        if plan.isBestValue {
                            Text("BEST VALUE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color.appSuccess)
                                )
                        }
                    }

                    Text(plan.description)
                        .font(.system(size: 12))
                        .foregroundColor(.appTextSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(plan.monthlyPrice)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.appPrimary)

                    if let savings = plan.savings {
                        Text("Save \(savings)")
                            .font(.system(size: 11))
                            .foregroundColor(.appSuccess)
                    }
                }

                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.appPrimary : Color.appTextSecondary.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Circle()
                            .fill(Color.appPrimary)
                            .frame(width: 16, height: 16)
                    }
                }
                .padding(.leading, 8)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .shadow(color: isSelected ? Color.appPrimary.opacity(0.2) : .black.opacity(0.05), radius: isSelected ? 8 : 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.appPrimary : Color.clear, lineWidth: 2)
            )
        }
    }
}

#Preview {
    SubscriptionView()
}
