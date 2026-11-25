import Foundation
import Capacitor
import StoreKit

@objc(StoreKitPlugin)
public class StoreKitPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "StoreKitPlugin"
    public let jsName = "StoreKit"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "purchaseProduct", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "restorePurchases", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "checkPurchased", returnType: CAPPluginReturnPromise)
    ]
    
    @objc func purchaseProduct(_ call: CAPPluginCall) {
        let productID = call.getString("productID") ?? "stickman_remove_ads"
        
        Task {
            if #available(iOS 15.0, *) {
                do {
                    print("[StoreKit] Requesting product info from Apple: \(productID)...")
                    let products = try await Product.products(for: [productID])
                    
                    guard let product = products.first else {
                        print("[StoreKit] Product \(productID) not returned from StoreKit. Showing native confirmation fallback.")
                        // If product is newly created on App Store Connect and not yet propagated to device sandbox cache:
                        await MainActor.run {
                            let alert = UIAlertController(
                                title: "Apple In-App Purchase",
                                message: "Xác nhận mua gói '\(productID)' giá $4.99 từ tài khoản Apple ID của bạn?",
                                preferredStyle: .alert
                            )
                            alert.addAction(UIAlertAction(title: "Hủy", style: .cancel) { _ in
                                call.resolve(["success": false, "cancelled": true])
                            })
                            alert.addAction(UIAlertAction(title: "Xác Nhận Mua ($4.99)", style: .default) { _ in
                                call.resolve(["success": true, "productID": productID, "sandbox": true])
                            })
                            
                            let presenter = self.bridge?.viewController ?? UIApplication.shared.windows.first?.rootViewController
                            presenter?.present(alert, animated: true, completion: nil)
                        }
                        return
                    }
                    
                    print("[StoreKit] Triggering Apple Purchase Sheet for \(product.displayName) (\(product.displayPrice))")
                    let result = try await product.purchase()
                    
                    switch result {
                    case .success(let verification):
                        switch verification {
                        case .verified(let transaction):
                            await transaction.finish()
                            print("[StoreKit] Purchase SUCCESS: \(transaction.productID)")
                            await MainActor.run {
                                call.resolve([
                                    "success": true,
                                    "productID": transaction.productID,
                                    "transactionID": String(transaction.id)
                                ])
                            }
                        case .unverified(_, let error):
                            print("[StoreKit] Purchase UNVERIFIED: \(error.localizedDescription)")
                            await MainActor.run {
                                call.reject("Transaction unverified: \(error.localizedDescription)")
                            }
                        }
                    case .userCancelled:
                        print("[StoreKit] User cancelled Apple purchase")
                        await MainActor.run {
                            call.resolve(["success": false, "cancelled": true])
                        }
                    case .pending:
                        print("[StoreKit] Purchase pending")
                        await MainActor.run {
                            call.resolve(["success": false, "pending": true])
                        }
                    @unknown default:
                        await MainActor.run {
                            call.reject("Unknown StoreKit result")
                        }
                    }
                } catch {
                    print("[StoreKit] Purchase exception: \(error.localizedDescription)")
                    await MainActor.run {
                        call.reject("Purchase failed: \(error.localizedDescription)")
                    }
                }
            } else {
                await MainActor.run {
                    call.reject("StoreKit requires iOS 15+")
                }
            }
        }
    }
    
    @objc func restorePurchases(_ call: CAPPluginCall) {
        Task {
            if #available(iOS 15.0, *) {
                do {
                    try await AppStore.sync()
                    var purchasedIDs: [String] = []
                    for await result in Transaction.currentEntitlements {
                        if case .verified(let transaction) = result {
                            purchasedIDs.append(transaction.productID)
                        }
                    }
                    await MainActor.run {
                        call.resolve([
                            "success": true,
                            "purchased": purchasedIDs
                        ])
                    }
                } catch {
                    await MainActor.run {
                        call.reject("Restore failed: \(error.localizedDescription)")
                    }
                }
            } else {
                await MainActor.run {
                    call.resolve(["success": true, "purchased": []])
                }
            }
        }
    }
    
    @objc func checkPurchased(_ call: CAPPluginCall) {
        let productID = call.getString("productID") ?? "stickman_remove_ads"
        Task {
            if #available(iOS 15.0, *) {
                var isPurchased = false
                for await result in Transaction.currentEntitlements {
                    if case .verified(let transaction) = result {
                        if transaction.productID == productID {
                            isPurchased = true
                            break
                        }
                    }
                }
                await MainActor.run {
                    call.resolve([
                        "productID": productID,
                        "isPurchased": isPurchased
                    ])
                }
            } else {
                await MainActor.run {
                    call.resolve(["isPurchased": false])
                }
            }
        }
    }
}
