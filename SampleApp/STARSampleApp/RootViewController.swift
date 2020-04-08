//
//  RootViewController.swift
//  STARSampleApp
//
//  Created by Stefan Mitterrutzner on 08.04.20.
//  Copyright © 2020 Ubique. All rights reserved.
//

import UIKit

class RootViewController: UITabBarController {

    lazy var logsViewController = LogsViewController()
    lazy var secondViewController = UIViewController()

    override func viewDidLoad() {
        super.viewDidLoad()
        secondViewController.title = "second"
        viewControllers = [logsViewController, secondViewController]
    }

}
