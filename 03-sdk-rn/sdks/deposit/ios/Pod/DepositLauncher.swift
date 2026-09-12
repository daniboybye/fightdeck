import Foundation
import UIKit
import FightDeckRNRuntime

@MainActor
public enum DepositLauncher {
    public static func launch(
        from navigationController: UINavigationController,
        hosting: DepositHosting,
        params: DepositParams,
        onResult: @escaping @Sendable (DepositResult) -> Void
    ) {
        let controller = hosting.makeViewController(params: params, onResult: onResult)
        navigationController.pushViewController(controller, animated: true)
    }
}
