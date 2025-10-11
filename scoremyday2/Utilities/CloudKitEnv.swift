import Foundation

enum CloudKitEnv {
    static var containerID: String? {
        AppConfiguration.cloudKitContainerIdentifier
    }
}
