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
        title = "LOGSv2"
        self.loadLogs()
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
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(share))
    }

    @objc func share(){
        DispatchQueue.global(qos: .background).async {
            let request = LogRequest(sorting: .desc, offset: 0, limit: 10000)
            if let resp = try? STARTracing.getLogs(request: request) {
                let report = resp.logs.map { (entry) -> String in
                    return "\(entry.timestamp.stringVal) \(entry.type.description): \(entry.message)"
                }.joined(separator: "\n")
                DispatchQueue.main.async {
                    let acv = UIActivityViewController(activityItems: [report], applicationActivities: nil)
                    self.present(acv, animated: true)
                }
            }
        }
    }

    @objc
    func reloadLogs() {
        self.loadLogs()
    }

    func loadLogs(request: LogRequest = LogRequest(sorting: .desc, offset: 0, limit: 200)){
        DispatchQueue.global(qos: .background).async {
            if let resp = try? STARTracing.getLogs(request: request) {
                self.nextRequest = resp.nextRequest
                let indexPaths = (request.offset..<(request.offset+resp.logs.count)).map { IndexPath(row: $0, section: 0) }
                DispatchQueue.main.async {
                    self.refreshControl.endRefreshing()
                    if request.offset == 0 {
                        self.logs = resp.logs
                        self.tableView.reloadData()
                    } else {
                        self.tableView.beginUpdates()
                        self.logs.append(contentsOf: resp.logs)
                        self.tableView.insertRows(at: indexPaths, with: .automatic)
                        self.tableView.endUpdates()
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
        return cell
    }
}

extension LogsViewController: STARTracingDelegate {
    func STARTracingStateChanged(_ state: TracingState) {}

    func errorOccured(_ error: STARTracingErrors) {}

    func didAddLog(_ entry: LogEntry) {
        self.logs.insert(entry, at: 0)
        if view.superview != nil {
            self.tableView.beginUpdates()
            self.tableView.insertRows(at: [IndexPath(row: 0, section: 0)], with: .automatic)
            self.tableView.endUpdates()
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
