import StoreKit
import SwiftUI
import UIKit

private var storeVC: SKStoreProductViewController?

func openReviews() {
	UIApplication.shared.open(URL(string: "https://apps.apple.com/app/id\(Bundle.iTunesIdentifier)?action=write-review")!)
}

func openStoreListing(backing: UIViewBacking) async {
	do {
		let vc = SKStoreProductViewController()
		let success = try await vc.loadProduct(withParameters: [SKStoreProductParameterITunesItemIdentifier: Bundle.iTunesIdentifier, SKStoreProductParameterCustomProductPageIdentifier: "write-review"])
		if let frontViewController = await UIApplication.shared.frontViewController {
			if success {
				DispatchQueue.main.async {
					vc.popoverPresentationController?.sourceView = backing.uiView
					storeVC = vc
					frontViewController.present(vc, animated: true) {
						storeVC = nil
					}
				}
			} else {
				print("Unable to load App Store product")
			}
		}
	} catch {
		print(#function, error)
	}
}