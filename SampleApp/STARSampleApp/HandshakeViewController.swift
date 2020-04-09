//

import UIKit

class HandshakeViewController: UIViewController {
    init() {
        super.init(nibName: nil, bundle: nil)
        title = "HandShakes"
        if #available(iOS 13.0, *) {
            tabBarItem = UITabBarItem(title: title, image: UIImage(systemName: "person.3.fill"), tag: 0)
        }
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
