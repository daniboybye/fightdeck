import Foundation

@objcMembers
public final class RuntimeBridgeExports: NSObject {
    public static func postResult(feature: String, payload: [String: Any]) {
        NotificationCenter.default.post(
            name: .fightdeckFeatureResult,
            object: nil,
            userInfo: ["feature": feature, "payload": payload]
        )
    }
}
