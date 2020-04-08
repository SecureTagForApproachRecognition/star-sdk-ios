import SnapKit
import STARSDK
import UIKit
import os

class LogsViewController: UIViewController {
    let startButton = UIButton()
    let stopButton = UIButton()
    let clearButton = UIButton()
    let updateDBButton = UIButton()
    let getStateButton = UIButton()
    let markAsInfected = UIButton()
    let logsView = UITextView()
    let handshakeCountLabel = UILabel()

    @UserDefault("ch.ubique.STARTracing.testapp", defaultValue: "")
    var logs: String {
        didSet {
            updateLogsView()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .lightGray

        title = "Logs"

        setupLayout()

        startButton.setTitleColor(.green, for: .normal)
        stopButton.setTitleColor(.red, for: .normal)
        updateDBButton.setTitleColor(.blue, for: .normal)
        startButton.setTitle("Start", for: .normal)
        stopButton.setTitle("Stop", for: .normal)
        clearButton.setTitle("Clear", for: .normal)
        updateDBButton.setTitle("Update DB", for: .normal)
        getStateButton.setTitle("GetState", for: .normal)
        markAsInfected.setTitle("Infected", for: .normal)
        logsView.text = "Logs:"
        logsView.isEditable = false

        startButton.addTarget(self, action: #selector(startTracing), for: .touchUpInside)
        stopButton.addTarget(self, action: #selector(stopTracing), for: .touchUpInside)
        clearButton.addTarget(self, action: #selector(clearLogs), for: .touchUpInside)
        updateDBButton.addTarget(self, action: #selector(updateDB), for: .touchUpInside)
        getStateButton.addTarget(self, action: #selector(getState), for: .touchUpInside)
        markAsInfected.addTarget(self, action: #selector(setInfected), for: .touchUpInside)

        STARTracing.logger = self
        STARTracing.delegate = self
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateLogsView()
    }

    fileprivate func setupLayout() {
        view.addSubview(startButton)
        view.addSubview(stopButton)
        view.addSubview(logsView)
        view.addSubview(clearButton)
        view.addSubview(updateDBButton)
        view.addSubview(getStateButton)
        view.addSubview(handshakeCountLabel)
        view.addSubview(markAsInfected)

        handshakeCountLabel.numberOfLines = 0

        handshakeCountLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.centerX.equalToSuperview()
        }

        clearButton.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.right.equalToSuperview().inset(10)
        }

        stopButton.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.leading.equalToSuperview().inset(10)
        }

        markAsInfected.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(10)
            make.top.equalTo(startButton.snp.bottom).offset(10)
        }

        startButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(10)
            make.top.equalTo(stopButton.snp.bottom).offset(10)
        }

        updateDBButton.snp.makeConstraints { make in
            make.right.equalToSuperview().inset(10)
            make.top.equalTo(clearButton.snp.bottom).offset(10)
        }

        getStateButton.snp.makeConstraints { make in
            make.top.equalTo(handshakeCountLabel.snp.bottom).inset(-10)
            make.centerX.equalToSuperview()
        }

        logsView.snp.makeConstraints { make in
            make.leading.bottom.trailing.equalToSuperview()
            make.top.equalTo(markAsInfected.snp.bottom).inset(-10)
        }
    }

    fileprivate func updateLogsView() {
        logsView.text = logs
        if logs.count > 0 {
            let location = logsView.text.count - 1
            let bottom = NSRange(location: location, length: 1)
            logsView.scrollRangeToVisible(bottom)
        }
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with _: UIEvent?) {
        if motion == .motionShake {
            clearLogs()
        }
    }

    @objc func clearLogs() {
        logs = ""
    }

    @objc func getState() {
        STARTracing.status { result in
            switch result {
            case let .success(state):
                self.handshakeCountLabel.text = "Handshakes: \(state.numberOfHandshakes) \n Exposed: \(state.infectionStatus.string) \n \(state.lastSync?.timeIntervalSinceNow ?? 0.0)"
            default:
                break
            }
        }
    }

    @objc func startTracing() {
        try? STARTracing.startTracing()
    }

    @objc func stopTracing() {
        STARTracing.stopTracing()
    }

    @objc func setInfected() {
        STARTracing.iWasExposed(customJSON: nil) { [weak self] _ in
            self?.log("did mark as exposed")
        }
    }

    @objc func updateDB() {
        STARTracing.sync { result in
            switch result {
            case .success:
                self.logs = self.logs + "\n" + Date().stringVal + "Successful known cases sync"
            case let .failure(error):
                self.logs = self.logs + "\n" + Date().stringVal + "Error: \(error.localizedDescription)"
            }
        }
    }
}

extension LogsViewController: LoggingDelegate {
    func log(_ string: String) {
        os_log("%@", string)
        logs = logs + "\n" + Date().stringVal + string
    }
}

extension LogsViewController: STARTracingDelegate {
    func STARTracingStateChanged(_ state: TracingState) {
        handshakeCountLabel.text = "Handshakes: \(state.numberOfHandshakes) \n Infected: \(state.infectionStatus.string) \n \(state.lastSync?.timeIntervalSinceNow ?? 0.0)"
    }

    func errorOccured(_: STARTracingErrors) {}
}

extension InfectionStatus {
    var string: String {
        switch self {
        case .exposed:
            return "Exposed"
        case .infected:
            return "Infected"
        case .healthy:
            return "Healthy"
        }
    }
}

extension Date {
    var stringVal: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM HH:mm:ss "
        return dateFormatter.string(from: self)
    }
}
