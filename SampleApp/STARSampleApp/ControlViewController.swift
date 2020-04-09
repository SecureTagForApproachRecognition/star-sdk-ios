//

import UIKit
import SnapKit
import STARSDK_CALIBRATION

class ControlViewController: UIViewController {

    let segmentedControl = UISegmentedControl(items: ["On", "Off"])

    let healthLabel = UILabel()

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

        healthLabel.font = .boldSystemFont(ofSize: 18)
        STARTracing.status { (result) in
            switch result {
            case let .success(state):
                self.updateUI(state)
            case .failure(_):
                break
            }
        }

        stackView.addArrangedSubview(healthLabel)
        stackView.addSpacerView(18)

        do {
            let label = UILabel()
            label.text = "Start / Stop Bluetooth Service"
            stackView.addArrangedSubview(label)
            stackView.addArrangedSubview(segmentedControl)
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

    @objc func setExposed(){
        STARTracing.iWasExposed(customJSON: nil) { (_) in
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
        }else {
            STARTracing.stopTracing()
        }
    }

    func updateUI(_ state: TracingState){
        switch state.trackingState {
        case .active:
            segmentedControl.selectedSegmentIndex = 0
        default:
            segmentedControl.selectedSegmentIndex = 1
        }

        switch state.infectionStatus {
        case .exposed:
            self.healthLabel.text = "InfectionStatus: EXPOSED"
        case .infected:
            self.healthLabel.text = "InfectionStatus: INFECTED"
        case .healthy:
            self.healthLabel.text = "InfectionStatus: HEALTHY"
        }
    }
}

extension ControlViewController: STARTracingDelegate {
    func STARTracingStateChanged(_ state: TracingState) {
        updateUI(state)
    }

    func errorOccured(_ error: STARTracingErrors) { }

    func didAddLog(_ entry: LogEntry) { }
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

extension UIStackView {
    func addArrangedView(_ view: UIView, size: CGFloat? = nil, insets: UIEdgeInsets? = nil) {
        if let h = size, axis == .vertical {
            view.snp.makeConstraints { make in
                make.height.equalTo(h)
            }
        } else if let w = size, axis == .horizontal {
            view.snp.makeConstraints { make in
                make.width.equalTo(w)
            }
        }

        addArrangedSubview(view)

        if let insets = insets {
            view.snp.makeConstraints { make in
                if axis == .vertical {
                    make.leading.trailing.equalToSuperview().inset(insets)
                } else {
                    make.top.bottom.equalToSuperview().inset(insets)
                }
            }
        }
    }

    func addSpacerView(_ size: CGFloat, color: UIColor? = nil, insets: UIEdgeInsets? = nil) {
        let extraSpacer = UIView()
        extraSpacer.backgroundColor = color
        addArrangedView(extraSpacer, size: size)
        if let insets = insets {
            extraSpacer.snp.makeConstraints { make in
                if axis == .vertical {
                    make.leading.trailing.equalToSuperview().inset(insets)
                } else {
                    make.top.bottom.equalToSuperview().inset(insets)
                }
            }
        }
    }
}
