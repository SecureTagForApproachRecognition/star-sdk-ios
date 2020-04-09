//

import UIKit
import STARSDK_CALIBRATION

class ParametersViewController: UIViewController {

    let stackView = UIStackView()

    let reconnectionDelayInput = UITextField()

    init() {
        super.init(nibName: nil, bundle: nil)
        title = "Parameters"
        if #available(iOS 13.0, *) {
            tabBarItem = UITabBarItem(title: title, image: UIImage(systemName: "wrench.fill"), tag: 0)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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

        do {
            let label = UILabel()
            label.text = "Set Reconnection Delay (seconds)"
            stackView.addArrangedSubview(label)

            reconnectionDelayInput.text = "\(Default.shared.reconnectionDelay)"
            reconnectionDelayInput.delegate = self
            reconnectionDelayInput.font = UIFont.systemFont(ofSize: 15)
            reconnectionDelayInput.borderStyle = UITextField.BorderStyle.roundedRect
            reconnectionDelayInput.autocorrectionType = UITextAutocorrectionType.no
            reconnectionDelayInput.keyboardType = UIKeyboardType.numberPad
            reconnectionDelayInput.returnKeyType = UIReturnKeyType.done
            reconnectionDelayInput.clearButtonMode = UITextField.ViewMode.whileEditing
            reconnectionDelayInput.contentVerticalAlignment = UIControl.ContentVerticalAlignment.center
            reconnectionDelayInput.delegate = self
            stackView.addArrangedSubview(reconnectionDelayInput)

            let button = UIButton()
            if #available(iOS 13.0, *) {
                button.setTitleColor(.systemBlue, for: .normal)
                button.setTitleColor(.systemGray, for: .highlighted)
            } else {
                button.setTitleColor(.blue, for: .normal)
                button.setTitleColor(.black, for: .highlighted)
            }
            button.setTitle("Update", for: .normal)
            button.addTarget(self, action: #selector(updateReconnectionDelay), for: .touchUpInside)
            stackView.addArrangedSubview(button)
        }

        stackView.addArrangedView(UIView())
    }

    @objc func updateReconnectionDelay(){
        let delay = reconnectionDelayInput.text ?? "0"
        let intDelay = Int(delay) ?? 0
        Default.shared.reconnectionDelay = intDelay
        reconnectionDelayInput.text = "\(Default.shared.reconnectionDelay)"
        STARTracing.reconnectionDelay = Default.shared.reconnectionDelay
        reconnectionDelayInput.resignFirstResponder()
    }
}

extension ParametersViewController: STARTracingDelegate {
    func STARTracingStateChanged(_ state: TracingState) {}

    func errorOccured(_ error: STARTracingErrors) { }

    func didAddLog(_ entry: LogEntry) { }
}

extension ParametersViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let allowedCharacters = CharacterSet.decimalDigits
        let characterSet = CharacterSet(charactersIn: string)
        return allowedCharacters.isSuperset(of: characterSet)
    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
