//

import UIKit
import SnapKit
import STARSDK_CALIBRATION

class ControlViewController: UIViewController {

    let segmentedControl = UISegmentedControl(items: ["On", "Off"])

    let startAdvertisingButton = UIButton()
    let startReceivingButton = UIButton()

    let statusLabel = UILabel()

    let stackView = UIStackView()

    let identifierInput = UITextField()

    init() {
        super.init(nibName: nil, bundle: nil)
        title = "Controls"
        if #available(iOS 13.0, *) {
            tabBarItem = UITabBarItem(title: title, image: UIImage(systemName: "doc.text"), tag: 0)
        }
        segmentedControl.selectedSegmentIndex = 1
        segmentedControl.addTarget(self, action: #selector(segmentedControlChanges), for: .valueChanged)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 13.0, *) {
            self.view.backgroundColor = .systemBackground
        } else {
            self.view.backgroundColor = .white
        }
        self.view.addSubview(stackView)
        stackView.snp.makeConstraints { (make) in
            make.left.right.bottom.equalTo(self.view.layoutMarginsGuide)
            make.top.equalTo(self.view.layoutMarginsGuide).inset(12)
        }
        stackView.axis = .vertical

        statusLabel.font = .systemFont(ofSize: 18)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        if #available(iOS 13.0, *) {
            statusLabel.backgroundColor = .systemGroupedBackground
        } else {
            statusLabel.backgroundColor = .lightGray
        }
        STARTracing.status { (result) in
            switch result {
            case let .success(state):
                self.updateUI(state)
            case .failure(_):
                break
            }
        }

        stackView.addArrangedSubview(statusLabel)
        stackView.addSpacerView(18)

        do {
            let label = UILabel()
            label.text = "Start / Stop Bluetooth Service"
            stackView.addArrangedSubview(label)
            stackView.addArrangedSubview(segmentedControl)

            if #available(iOS 13.0, *) {
                startAdvertisingButton.setTitleColor(.systemBlue, for: .normal)
                startAdvertisingButton.setTitleColor(.systemGray, for: .highlighted)
                startAdvertisingButton.setTitleColor(.systemGray2, for: .disabled)
            } else {
                startAdvertisingButton.setTitleColor(.blue, for: .normal)
                startAdvertisingButton.setTitleColor(.black, for: .highlighted)
                startAdvertisingButton.setTitleColor(.lightGray, for: .disabled)
            }
            startAdvertisingButton.setTitle("Start Advertising", for: .normal)
            startAdvertisingButton.addTarget(self, action: #selector(startAdvertising), for: .touchUpInside)

            stackView.addArrangedSubview(startAdvertisingButton)


            if #available(iOS 13.0, *) {
                startReceivingButton.setTitleColor(.systemBlue, for: .normal)
                startReceivingButton.setTitleColor(.systemGray, for: .highlighted)
                startReceivingButton.setTitleColor(.systemGray2, for: .disabled)
            } else {
                startReceivingButton.setTitleColor(.blue, for: .normal)
                startReceivingButton.setTitleColor(.black, for: .highlighted)
                startReceivingButton.setTitleColor(.lightGray, for: .disabled)
            }
            startReceivingButton.setTitle("Start Receiving", for: .normal)
            startReceivingButton.addTarget(self, action: #selector(startReceiving), for: .touchUpInside)
            
            stackView.addArrangedSubview(startReceivingButton)

        }

        stackView.addSpacerView(12)

        do {
            let button = UIButton()
            if #available(iOS 13.0, *) {
                button.setTitleColor(.systemBlue, for: .normal)
                button.setTitleColor(.systemGray, for: .highlighted)
            } else {
                button.setTitleColor(.blue, for: .normal)
                button.setTitleColor(.black, for: .highlighted)
            }
            button.setTitle("Reset", for: .normal)
            button.addTarget(self, action: #selector(reset), for: .touchUpInside)
            stackView.addArrangedSubview(button)
        }

        stackView.addSpacerView(12)

        do {
            let button = UIButton()
            if #available(iOS 13.0, *) {
                button.setTitleColor(.systemBlue, for: .normal)
                button.setTitleColor(.systemGray, for: .highlighted)
            } else {
                button.setTitleColor(.blue, for: .normal)
                button.setTitleColor(.black, for: .highlighted)
            }
            button.setTitle("Set Infected", for: .normal)
            button.addTarget(self, action: #selector(setExposed), for: .touchUpInside)
            stackView.addArrangedSubview(button)
        }
        stackView.addSpacerView(12)

        do {
            let button = UIButton()
            if #available(iOS 13.0, *) {
                button.setTitleColor(.systemBlue, for: .normal)
                button.setTitleColor(.systemGray, for: .highlighted)
            } else {
                button.setTitleColor(.blue, for: .normal)
                button.setTitleColor(.black, for: .highlighted)
            }
            button.setTitle("Synchronize with Backend", for: .normal)
            button.addTarget(self, action: #selector(sync), for: .touchUpInside)
            stackView.addArrangedSubview(button)
        }

        stackView.addSpacerView(12)

        do {
            let label = UILabel()
            label.text = "Set ID Prefix"
            stackView.addArrangedSubview(label)

            identifierInput.text = Default.shared.identifierPrefix ?? "AAAA"
            identifierInput.delegate = self
            identifierInput.font = UIFont.systemFont(ofSize: 15)
            identifierInput.borderStyle = UITextField.BorderStyle.roundedRect
            identifierInput.autocorrectionType = UITextAutocorrectionType.no
            identifierInput.keyboardType = UIKeyboardType.default
            identifierInput.returnKeyType = UIReturnKeyType.done
            identifierInput.clearButtonMode = UITextField.ViewMode.whileEditing
            identifierInput.contentVerticalAlignment = UIControl.ContentVerticalAlignment.center
            identifierInput.delegate = self
            stackView.addArrangedSubview(identifierInput)

            let button = UIButton()
            if #available(iOS 13.0, *) {
                button.setTitleColor(.systemBlue, for: .normal)
                button.setTitleColor(.systemGray, for: .highlighted)
            } else {
                button.setTitleColor(.blue, for: .normal)
                button.setTitleColor(.black, for: .highlighted)
            }
            button.setTitle("Update", for: .normal)
            button.addTarget(self, action: #selector(updateIdentifier), for: .touchUpInside)
            stackView.addArrangedSubview(button)
        }
        stackView.addSpacerView(12)

        do {
            let button = UIButton()
            if #available(iOS 13.0, *) {
                button.setTitleColor(.systemBlue, for: .normal)
                button.setTitleColor(.systemGray, for: .highlighted)
            } else {
                button.setTitleColor(.blue, for: .normal)
                button.setTitleColor(.black, for: .highlighted)
            }
            button.setTitle("Share Database", for: .normal)
            button.addTarget(self, action: #selector(shareDatabase), for: .touchUpInside)
            stackView.addArrangedSubview(button)
        }

        
        stackView.addArrangedSubview(UIView())
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func updateIdentifier() {
        identifierInput.resignFirstResponder()
        Default.shared.identifierPrefix = identifierInput.text
        reset()
    }

    @objc func sync() {
        STARTracing.sync { _ in }
    }

    @objc func setExposed() {
        STARTracing.iWasExposed(onset: Date(), authString: "") { (_) in
            STARTracing.status { (result) in
                switch result {
                case let .success(state):
                    self.updateUI(state)
                case .failure(_):
                    break
                }
            }
        }
    }

    @objc func shareDatabase(){
        let acv = UIActivityViewController(activityItems: [Self.getDatabasePath()], applicationActivities: nil)
        if let popoverController = acv.popoverPresentationController {
            popoverController.sourceView = self.view
        }
        self.present(acv, animated: true)
    }

    @objc func reset(){
        STARTracing.stopTracing()
        try? STARTracing.reset()
        NotificationCenter.default.post(name: Notification.Name("ClearData"), object: nil)
        try! STARTracing.initialize(with: "ch.ubique.starsdk.sample", enviroment: .dev, mode: .calibration(identifierPrefix: Default.shared.identifierPrefix ?? "AAAA"))
        STARTracing.delegate = navigationController?.tabBarController as? STARTracingDelegate
        STARTracing.status { (result) in
            switch result {
            case let .success(state):
                self.updateUI(state)
            case .failure(_):
                break
            }
        }
    }

    @objc func segmentedControlChanges(){
        if segmentedControl.selectedSegmentIndex == 0 {
            try? STARTracing.startTracing()
            Default.shared.tracingMode = .active
        }else {
            STARTracing.stopTracing()
            Default.shared.tracingMode = .none
        }
    }

    @objc func startAdvertising(){
        try? STARTracing.startAdvertising()
        Default.shared.tracingMode = .activeAdvertising
    }

    @objc func startReceiving(){
        try? STARTracing.startReceiving()
        Default.shared.tracingMode = .activeReceiving
    }

    func updateUI(_ state: TracingState){
        var elements: [String]  = []
        elements.append(state.trackingState.stringValue)
        switch state.trackingState {
        case .active, .activeReceiving, .activeAdvertising:
            segmentedControl.selectedSegmentIndex = 0
            startReceivingButton.isEnabled = false
            startAdvertisingButton.isEnabled = false
        default:
            segmentedControl.selectedSegmentIndex = 1
            startReceivingButton.isEnabled = true
            startAdvertisingButton.isEnabled = true
        }
        if let lastSync = state.lastSync {
            elements.append(lastSync.stringVal)
        }

        switch state.infectionStatus {
        case .exposed:
            elements.append("InfectionStatus: EXPOSED")
        case .infected:
            elements.append("InfectionStatus: INFECTED")
        case .healthy:
            elements.append("InfectionStatus: HEALTHY")
        }
        elements.append("Handshakes: \(state.numberOfHandshakes)")

        statusLabel.text = elements.joined(separator: "\n")
    }

    private static func getDatabasePath() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory.appendingPathComponent("STAR_tracing_db").appendingPathExtension("sqlite")
    }
}

extension ControlViewController: STARTracingDelegate {
    func STARTracingStateChanged(_ state: TracingState) {
        updateUI(state)
    }
}

extension ControlViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let textFieldText = textField.text,
            let rangeOfTextToReplace = Range(range, in: textFieldText) else {
                return false
        }
        let substringToReplace = textFieldText[rangeOfTextToReplace]
        let count = textFieldText.count - substringToReplace.count + string.count
        return count <= 4
    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

fileprivate extension TrackingState {
    var stringValue: String {
        switch self {
        case .active:
            return "active"
        case .activeAdvertising:
            return "activeAdvertising"
        case .activeReceiving:
            return "activeReceiving"
        case let .inactive(error):
            return "inactive \(error.localizedDescription)"
        case .stopped:
            return "stopped"
        }
    }
}
