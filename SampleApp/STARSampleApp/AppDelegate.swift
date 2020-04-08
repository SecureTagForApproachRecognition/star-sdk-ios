import STARSDK
import UIKit
import os

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    @UserDefault("ch.ubique.STARSDK.sampleapp", defaultValue: "")
    var logs: String

    func application(_ application: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        try! STARTracing.initialize(with: "ch.ubique.nextstep", enviroment: .dev, mode: .calibration(identifierPrefix: "STAR"))

        if application.applicationState != .background {
            initWindow()
        } else {
            STARTracing.logger = self
            log("🚀Application started in background mode🚀")
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

    func applicationDidEnterBackground(_: UIApplication) {
        log("applicationDidEnterBackground")
    }

    func applicationWillResignActive(_: UIApplication) {
        log("applicationWillResignActive")
    }

    func applicationDidBecomeActive(_: UIApplication) {
        log("applicationDidBecomeActive")
    }

    func applicationDidFinishLaunching(_: UIApplication) {
        log("applicationDidFinishLaunching")
    }

    func applicationWillEnterForeground(_: UIApplication) {
        if window == nil {
            initWindow()
        }
        log("applicationWillEnterForeground")
    }
}

extension AppDelegate: LoggingDelegate {
    func log(_ string: String) {
        os_log("%@", string)
        logs = logs + "\n" + Date().stringVal + string
    }
}
