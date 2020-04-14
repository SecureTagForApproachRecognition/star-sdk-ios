import os
import STARSDK_CALIBRATION
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        STARTracing.reconnectionDelay = Default.shared.reconnectionDelay
        try! STARTracing.initialize(with: "ch.ubique.starsdk.sample", enviroment: .dev, mode: .calibration(identifierPrefix: Default.shared.identifierPrefix ?? "AAAA"))

        if application.applicationState != .background {
            initWindow()
        }

        switch Default.shared.tracingMode {
        case .none:
            break
        case .active:
            try? STARTracing.startTracing()
        case .activeAdvertising:
            try? STARTracing.startAdvertising()
        case .activeReceiving:
            try? STARTracing.startReceiving()
        }

        return true
    }

    func initWindow() {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.makeKey()
        window?.rootViewController = RootViewController()
        window?.makeKeyAndVisible()
    }

    func applicationWillEnterForeground(_: UIApplication) {
        if window == nil {
            initWindow()
        }
    }
}
