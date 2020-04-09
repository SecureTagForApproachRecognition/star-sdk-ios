//


import UIKit

class ParametersViewController: UIViewController {
    init() {
        super.init(nibName: nil, bundle: nil)
        title = "Config"
        if #available(iOS 13.0, *) {
            tabBarItem = UITabBarItem(title: title, image: UIImage(systemName: "wrench.fill"), tag: 0)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
