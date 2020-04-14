//

import STARSDK_CALIBRATION
import UIKit

class RootViewController: UITabBarController {
    var logsViewController = LogsViewController()
    var controlsViewController = ControlViewController()
    var parameterViewController = ParametersViewController()
    var handshakeViewController = HandshakeViewController()

    lazy var tabs: [UIViewController] = [controlsViewController,
                                         logsViewController,
                                         parameterViewController,
                                         handshakeViewController]

    override func viewDidLoad() {
        super.viewDidLoad()
        viewControllers = tabs.map(UINavigationController.init(rootViewController:))

        STARTracing.delegate = self
    }
}

extension RootViewController: STARTracingDelegate {
    func STARTracingStateChanged(_ state: TracingState) {
        tabs
            .compactMap { $0 as? STARTracingDelegate }
            .forEach { $0.STARTracingStateChanged(state) }
    }

    func didAddLog(_ entry: LogEntry) {
        tabs
            .compactMap { $0 as? STARTracingDelegate }
            .forEach { $0.didAddLog(entry) }
    }

    func didAddHandshake(_ handshake: HandshakeModel) {
        tabs
            .compactMap { $0 as? STARTracingDelegate }
            .forEach { $0.didAddHandshake(handshake) }
    }
}
