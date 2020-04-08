//


import UIKit
import STARSDK_CALIBRATION

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
        viewControllers = tabs.map(UINavigationController.init(rootViewController: ))
        
        STARTracing.delegate = self
    }

}

extension RootViewController: STARTracingDelegate {
    func STARTracingStateChanged(_ state: TracingState) {
        self.tabs
            .compactMap{$0 as? STARTracingDelegate}
            .forEach{ $0.STARTracingStateChanged(state) }
    }

    func errorOccured(_ error: STARTracingErrors) {
        self.tabs
        .compactMap{$0 as? STARTracingDelegate}
        .forEach{ $0.errorOccured(error) }
    }

    func didAddLog(_ entry: LogEntry) {
        self.tabs
        .compactMap{$0 as? STARTracingDelegate}
        .forEach{ $0.didAddLog(entry) }
    }


}
