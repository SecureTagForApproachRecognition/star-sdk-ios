//


import UIKit

class RootViewController: UITabBarController {

    var logsViewController = LogsViewController()
    var controlsViewController = ControlViewController()
    var parameterViewController = ParametersViewController()
    var handshakeViewController = HandshakeViewController()

    override func viewDidLoad() {
        super.viewDidLoad()
        viewControllers = [controlsViewController,
                           logsViewController,
                           parameterViewController,
                           UINavigationController(rootViewController: handshakeViewController)]
    }

}
