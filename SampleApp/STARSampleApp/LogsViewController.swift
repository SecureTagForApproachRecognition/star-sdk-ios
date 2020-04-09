//
//  LogsViewController.swift
//  STARSampleApp
//
//  Created by Stefan Mitterrutzner on 08.04.20.
//  Copyright © 2020 Ubique. All rights reserved.
//

import UIKit
import STARSDK_CALIBRATION

class LogCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        self.textLabel?.numberOfLines = 0
        self.textLabel?.font = .boldSystemFont(ofSize: 12.0)
        self.detailTextLabel?.numberOfLines = 0
        self.selectionStyle = .none
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class LogsViewController: UIViewController {

    let tableView = UITableView()

    let refreshControl = UIRefreshControl()

    var logs: [LogEntry] = []

    var nextRequest: LogRequest?

    init() {
        super.init(nibName: nil, bundle: nil)
        title = "Logs"
        if #available(iOS 13.0, *) {
            tabBarItem = UITabBarItem(title: title, image: UIImage(systemName: "list.bullet"), tag: 0)
        }
        self.loadLogs()
        NotificationCenter.default.addObserver(self, selector: #selector(self.didClearData(notification:)), name: Notification.Name("ClearData"), object: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        self.view = tableView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(LogCell.self, forCellReuseIdentifier: "logCell")
        tableView.refreshControl = refreshControl
        tableView.dataSource = self
        refreshControl.addTarget(self, action: #selector(reloadLogs), for: .allEvents)
    }

    @objc func didClearData(notification: Notification) {
        logs = []
        self.tableView.reloadData()
    }

    @objc
    func reloadLogs() {
        self.loadLogs()
    }

    func loadLogs(request: LogRequest = LogRequest(sorting: .desc, offset: 0, limit: 200)){
        DispatchQueue.global(qos: .background).async {
            if let resp = try? STARTracing.getLogs(request: request) {
                self.nextRequest = resp.nextRequest
                DispatchQueue.main.async {
                    self.refreshControl.endRefreshing()
                    if request.offset == 0 {
                        self.logs = resp.logs
                    } else {
                        self.logs.append(contentsOf: resp.logs)
                        self.tableView.reloadData()
                    }
                }
            }

        }
    }
}



extension LogsViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return logs.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row == (logs.count - 1),
           let nextRequest = self.nextRequest {
            loadLogs(request: nextRequest)
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: "logCell", for: indexPath) as! LogCell
        let log = logs[indexPath.row]
        cell.textLabel?.text = "\(log.timestamp.stringVal) \(log.type.description)"
        cell.detailTextLabel?.text = log.message
        switch log.type {
        case .sender:
            cell.backgroundColor = UIColor(red: 1, green: 0, blue: 0, alpha: 0.1)
        case .receiver:
            cell.backgroundColor = UIColor(red: 0, green: 1, blue: 0, alpha: 0.1)
        default:
            cell.backgroundColor = .clear
        }
        return cell
    }
}

extension LogsViewController: STARTracingDelegate {
    func STARTracingStateChanged(_ state: TracingState) {}

    func errorOccured(_ error: STARTracingErrors) {}

    func didAddLog(_ entry: LogEntry) {
        self.logs.insert(entry, at: 0)
        if view.superview != nil {
            self.tableView.reloadData()
        }
        self.nextRequest?.offset += 1
    }
}

extension Date {
    var stringVal: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM HH:mm:ss "
        return dateFormatter.string(from: self)
    }
}
