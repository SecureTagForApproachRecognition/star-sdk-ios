import STARSDK_CALIBRATION
import UIKit
import os

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        STARTracing.reconnectionDelay = Default.shared.reconnectionDelay
        try! STARTracing.initialize(with: "ch.ubique.starsdk.sample", enviroment: .dev, mode: .calibration(identifierPrefix: Default.shared.identifierPrefix ?? "AAAA"))

        if application.applicationState != .background {
            initWindow()
        }

        try? STARTracing.startTracing()

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
