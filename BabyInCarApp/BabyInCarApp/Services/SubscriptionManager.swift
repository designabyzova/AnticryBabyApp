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
        case lifetimePremium = "com.babyincar.premium.lifetime.v2"

        var displayName: String {
            switch self {
            case .monthlyPremium: return "Premium Monthly"
            case .yearlyPremium: return "Premium Yearly"
            case .lifetimePremium: return "Premium Lifetime"
            }
        }
    }

    // MARK: - Subscription Plans
    struct SubscriptionPlan: Identifiable {
        let id: String
        var product: Product?
        let name: String
        let description: String
        let billedPrice: String       // Primary: actual amount charged (most prominent)
        let billedPeriod: String      // e.g. "/month", "/year", "one-time"
        let equivalentPrice: String?  // Secondary: calculated equivalent (subordinate)
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
                billedPrice: "$6.99",
                billedPeriod: "/month",
                equivalentPrice: nil,
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
                billedPrice: "$49.99",
                billedPeriod: "/year",
                equivalentPrice: "$4.17/mo",
                features: [
                    "Everything in Premium",
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
                billedPrice: "$149.99",
                billedPeriod: " one-time",
                equivalentPrice: nil,
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
            // Provide user feedback when products aren't loaded
            if products.isEmpty {
                errorMessage = "Unable to load subscription options. Please check your internet connection and try again."
            } else {
                errorMessage = "Selected plan is not available. Please try another option."
            }
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
    // FIX: Use @ObservedObject for singletons - prevents state observation issues on iPad
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @ObservedObject private var trialManager = TrialManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var selectedPlan: String = ""
    @State private var showingComparison = false
    @State private var isLoadingProducts = true

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Trial banner (if applicable)
                    if trialManager.trialState.isActive {
                        trialBanner
                    }

                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.yellow)

                        Text(trialManager.trialState.isActive ? "Keep Premium Access" : "Upgrade to Premium")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.appText)

                        Text(trialManager.trialState.isActive
                             ? "Subscribe before your trial ends"
                             : "Unlock all features and content")
                            .font(.system(size: 16))
                            .foregroundColor(.appTextSecondary)
                    }
                    .padding(.top, trialManager.trialState.isActive ? 0 : 20)

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
                            if subscriptionManager.isLoading || isLoadingProducts {
                                ProgressView()
                                    .tint(.white)
                                Text(isLoadingProducts ? "Loading plans..." : "Processing...")
                                    .padding(.leading, 8)
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
                                .fill(subscriptionManager.isLoading || isLoadingProducts || selectedPlan.isEmpty
                                      ? Color.appPrimary.opacity(0.5)
                                      : Color.appPrimary)
                        )
                    }
                    .disabled(subscriptionManager.isLoading || isLoadingProducts || selectedPlan.isEmpty)
                    .padding(.horizontal, 20)
                    .accessibilityIdentifier("subscribeNowButton")

                    // Compare plans link
                    Button {
                        showingComparison = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "list.bullet.rectangle")
                                .font(.system(size: 14))
                            Text("Compare Free vs Premium")
                                .font(.system(size: 14))
                        }
                        .foregroundColor(.appPrimary)
                    }

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
                    VStack(spacing: 8) {
                        Text("Payment will be charged to your Apple ID account. Subscription automatically renews unless canceled at least 24 hours before the end of the current period.")
                            .font(.system(size: 11))
                            .foregroundColor(.appTextSecondary)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 4) {
                            Link("Privacy Policy", destination: URL(string: "https://lulla-app.pages.dev/privacy")!)
                            Text("and")
                                .foregroundColor(.appTextSecondary)
                            Link("Terms of Use (EULA)", destination: URL(string: "https://lulla-app.pages.dev/terms")!)
                        }
                        .font(.system(size: 11))
                    }
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
        .sheet(isPresented: $showingComparison) {
            FreePremiumComparisonView()
        }
        .alert("Error", isPresented: .init(
            get: { subscriptionManager.errorMessage != nil },
            set: { if !$0 { subscriptionManager.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                subscriptionManager.errorMessage = nil
            }
            Button("Retry") {
                Task {
                    await subscriptionManager.loadProducts()
                    // Re-select best value plan after reload
                    if let bestValue = subscriptionManager.availablePlans.first(where: { $0.isBestValue && $0.product != nil }) {
                        selectedPlan = bestValue.id
                    }
                }
            }
        } message: {
            Text(subscriptionManager.errorMessage ?? "An error occurred")
        }
        .onAppear {
            // Pre-select best value plan (only if product is loaded)
            if let bestValue = subscriptionManager.availablePlans.first(where: { $0.isBestValue && $0.product != nil }) {
                selectedPlan = bestValue.id
            }
            isLoadingProducts = false
        }
        .task {
            // Auto-retry product loading with backoff (fixes Guideline 2.1 sandbox issue)
            var retryCount = 0
            let maxRetries = 3
            while subscriptionManager.products.isEmpty && retryCount < maxRetries {
                await subscriptionManager.loadProducts()
                if !subscriptionManager.products.isEmpty { break }
                retryCount += 1
                if retryCount < maxRetries {
                    try? await Task.sleep(nanoseconds: UInt64(retryCount) * 2_000_000_000)
                }
            }
            if let bestValue = subscriptionManager.availablePlans.first(where: { $0.isBestValue && $0.product != nil }) {
                selectedPlan = bestValue.id
            }
            isLoadingProducts = false
        }
    }

    // (Button state is computed inline)

    // MARK: - Trial Banner

    private var trialBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.fill")
                .font(.system(size: 24))
                .foregroundColor(.appWarning)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(trialManager.trialDaysRemaining) days left in trial")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.appText)

                Text("You're enjoying full Premium access")
                    .font(.system(size: 13))
                    .foregroundColor(.appTextSecondary)
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.appWarning.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.appWarning.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
        .padding(.top, 20)
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
                    // Billed amount is the MOST prominent (Apple Guideline 3.1.2)
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text(plan.billedPrice)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.appText)
                        Text(plan.billedPeriod)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.appTextSecondary)
                    }

                    // Calculated equivalent in subordinate position
                    if let equivalent = plan.equivalentPrice {
                        Text(equivalent)
                            .font(.system(size: 11))
                            .foregroundColor(.appTextSecondary)
                    }

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
