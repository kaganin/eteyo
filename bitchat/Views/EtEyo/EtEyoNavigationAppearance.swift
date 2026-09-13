#if os(iOS)
import SwiftUI
import UIKit

/// Replaces the native back indicator while retaining the navigation stack's
/// back button, transition and interactive pop gesture.
struct EtEyoNavigationAppearance: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.applyAppearance()
    }

    final class Controller: UIViewController {
        override func loadView() {
            view = UIView()
            view.isUserInteractionEnabled = false
        }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            applyAppearance()
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            applyAppearance()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            applyAppearance()
        }

        func applyAppearance() {
            guard let navigationController,
                  let image = UIImage(named: "EtEyo-back")?
                    .withRenderingMode(.alwaysTemplate)
                    .imageFlippedForRightToLeftLayoutDirection() else { return }

            // Configure only this screen, leaving the Debug reference unchanged.
            var screen: UIViewController = self
            while let parent = screen.parent, !(parent is UINavigationController) {
                screen = parent
            }
            guard screen.parent is UINavigationController else { return }
            let item = screen.navigationItem
            let bar = navigationController.navigationBar

            func appearance(_ current: UINavigationBarAppearance?) -> UINavigationBarAppearance {
                let result = (current ?? bar.standardAppearance).copy()
                result.setBackIndicatorImage(image, transitionMaskImage: image)
                return result
            }

            item.standardAppearance = appearance(item.standardAppearance ?? bar.standardAppearance)
            item.scrollEdgeAppearance = appearance(item.scrollEdgeAppearance ?? bar.scrollEdgeAppearance)
            item.compactAppearance = appearance(item.compactAppearance ?? bar.compactAppearance)
            item.compactScrollEdgeAppearance = appearance(item.compactScrollEdgeAppearance ?? bar.compactScrollEdgeAppearance)
        }
    }
}
#endif
