import Foundation
import UIKit
import FightDeckRNRuntime

@MainActor
public enum DepositLauncher {
    public static func launch(
        from navigationController: UINavigationController,
        hosting: DepositHosting,
        paramsBuilder: @escaping () async throws -> DepositParams,
        onResult: @escaping @Sendable (DepositResult) -> Void
    ) {
        Task {
            do {
                let params = try await paramsBuilder()
                let controller = hosting.makeViewController(params: params, onResult: onResult)
                navigationController.pushViewController(controller, animated: true)
            } catch {
                onResult(.failed(reason: error.localizedDescription))
            }
        }
    }
}
