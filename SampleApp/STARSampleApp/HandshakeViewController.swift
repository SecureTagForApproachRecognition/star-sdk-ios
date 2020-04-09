//

import STARSDK_CALIBRATION
import UIKit
import SnapKit

class HandshakeViewController: UIViewController {

    private var tableView: UITableView?

    private let MAX_NUMBER_OF_MISSING_HANDSHAKES = 3
    private var cachedHandshakeIntervals: [HandshakeInterval] = []
    private var cachedHandshakes: [HandshakeModel] = []
    private var nextRequest: HandshakeRequest?
    private let dateFormatter = DateFormatter()

    private enum Mode {
        case raw, grouped
    }
    private var mode: Mode = .raw {
        didSet {
            reloadModel()
        }
    }

    private var didLoadHandshakes = false

    init() {
        super.init(nibName: nil, bundle: nil)
        title = "HandShakes"
        dateFormatter.dateFormat = "dd.MM HH:mm:ss "
        if #available(iOS 13.0, *) {
            tabBarItem = UITabBarItem(title: title, image: UIImage(systemName: "person.3.fill"), tag: 0)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(self.didClearData(notification:)), name: Notification.Name("ClearData"), object: nil)
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView = UITableView(frame: .zero, style: .plain)
        tableView!.dataSource = self
        tableView!.delegate = self
        view.addSubview(tableView!)
        tableView!.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }

        let refreshControl = UIRefreshControl()
        refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        refreshControl.addTarget(self, action: #selector(refresh(sender:)), for: UIControl.Event.valueChanged)
        tableView!.addSubview(refreshControl)

        let segmentedControl = UISegmentedControl(items: ["Raw", "Grouped"])
        segmentedControl.addTarget(self, action: #selector(groupingChanged(sender:)), for: .valueChanged)
        segmentedControl.selectedSegmentIndex = 0
        navigationItem.titleView = segmentedControl

        NotificationCenter.default.addObserver(self, selector: #selector(self.didClearData(notification:)), name: Notification.Name("ClearData"), object: nil)
    }

    @objc func didClearData(notification: Notification) {
        cachedHandshakes.removeAll()
        cachedHandshakeIntervals.removeAll()
        nextRequest = nil
        didLoadHandshakes = false
        tableView?.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !didLoadHandshakes {
            didLoadHandshakes = true
            reloadModel()
        }
    }

    @objc func groupingChanged(sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 0 {
            mode = .raw
        } else {
            mode = .grouped
        }
    }

    @objc func refresh(sender: UIRefreshControl) {
        reloadModel()
        sender.endRefreshing()
    }

    private func reloadModel() {
        cachedHandshakeIntervals.removeAll()
        cachedHandshakes.removeAll()
        nextRequest = nil
        switch mode {
        case .raw:
            loadHandshakes(request: HandshakeRequest(offset: 0, limit: 30), clear: true)
        case .grouped:
            do {
                let response = try STARTracing.getHandshakes(request: HandshakeRequest())
                let groupped = groupHandshakes(response.handshakes)
                let intervals = generateIntervalsFrom(grouppedHandshakes: groupped)
                cachedHandshakeIntervals = intervals
                tableView?.reloadData()
            } catch {
                let alert = UIAlertController(title: "Error Fetching Handshakes", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                present(alert, animated: true, completion: nil)
            }
        }
    }

    private func loadNextHandshakes() {
        guard let nextRequest = nextRequest else {
            return
        }
        loadHandshakes(request: nextRequest, clear: false)
    }

    private func loadHandshakes(request: HandshakeRequest, clear: Bool) {
        do {
            let response = try STARTracing.getHandshakes(request: request)
            nextRequest = response.nextRequest
            if clear {
                cachedHandshakes = response.handshakes
                tableView?.reloadData()
            } else if response.handshakes.isEmpty == false {
                var indexPathes: [IndexPath] = []
                let base = response.handshakes.count
                let target = base + response.handshakes.count
                for rowIndex in base..<target {
                    indexPathes.append(IndexPath(row: rowIndex, section: 0))
                }
                cachedHandshakes.append(contentsOf: response.handshakes)
                tableView?.insertRows(at: indexPathes, with: .bottom)
            }
        } catch {
            let alert = UIAlertController(title: "Error Fetching Handshakes", message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
        }
    }

    private func groupHandshakes(_ handshakes: [HandshakeModel]) -> [String: [HandshakeModel]] {
        var grouppedHandshakes: [String: [HandshakeModel]] = [:]
        for handshake in handshakes {
            guard let identifier = handshake.star.STARHeadIndentifier else {
                continue
            }
            var group = grouppedHandshakes[identifier, default: []]
            group.append(handshake)
            grouppedHandshakes[identifier] = group
        }
        return grouppedHandshakes
    }

    private func generateIntervalsFrom(grouppedHandshakes: [String: [HandshakeModel]]) -> [HandshakeInterval] {
        var intervals: [HandshakeInterval] = []
        for (_, group) in grouppedHandshakes.enumerated() {
            let sortedGroup = group.value.sorted(by: { $0.timestamp < $1.timestamp })
            var start = 0
            var end = 1
            while end < sortedGroup.count {
                let timeDelay = abs(sortedGroup[end].timestamp.timeIntervalSince(sortedGroup[end - 1].timestamp))
                if timeDelay > Double(MAX_NUMBER_OF_MISSING_HANDSHAKES * STARTracing.reconnectionDelay) {
                    let startTime = sortedGroup[start].timestamp
                    let endTime = sortedGroup[end - 1].timestamp
                    let elapsedTime = abs(startTime.timeIntervalSince(endTime))
                    let expectedCount: Int = 1 + Int(ceil(elapsedTime) / Double(STARTracing.reconnectionDelay))
                    let interval = HandshakeInterval(identifier: group.key, start: startTime, end: endTime, count: end - start, expectedCount: expectedCount)
                    intervals.append(interval)
                    start = end
                }
                end += 1
            }
            let startTime = sortedGroup[start].timestamp
            let endTime = sortedGroup[end - 1].timestamp
            let elapsedTime = abs(startTime.timeIntervalSince(endTime))
            let expectedCount: Int = 1 + Int(ceil(elapsedTime) / Double(STARTracing.reconnectionDelay))
            let interval = HandshakeInterval(identifier: group.key, start: startTime, end: endTime, count: end - start, expectedCount: expectedCount)
            intervals.append(interval)
        }
        return intervals
    }

    private struct HandshakeInterval {
        let identifier: String
        let start: Date
        let end: Date
        let count: Int
        let expectedCount: Int
    }
}

extension HandshakeViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch mode {
        case .grouped:
            return cachedHandshakeIntervals.count
        case .raw:
            return cachedHandshakes.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell
        if let dequeuedCell = tableView.dequeueReusableCell(withIdentifier: "TVCID") {
            cell = dequeuedCell
        } else {
            cell = UITableViewCell(style: .subtitle, reuseIdentifier: "TVCID")
            cell.textLabel?.numberOfLines = 0
            cell.detailTextLabel?.numberOfLines = 0
            cell.selectionStyle = .none
        }

        switch mode {
        case .grouped:
            let interval = cachedHandshakeIntervals[indexPath.row]
            cell.textLabel?.text = "\(dateFormatter.string(from: interval.start)) -> \(dateFormatter.string(from: interval.end))"
            cell.detailTextLabel?.text = "\(interval.identifier) - \(interval.count) / \(interval.expectedCount)"
        case .raw:
            let handshake = cachedHandshakes[indexPath.row]
            let star = handshake.star
            cell.textLabel?.text = (star.STARHeadIndentifier ?? "Unknown") + " - " + star.hexEncodedString
            let distance: String = handshake.distance == nil ? "--" : String(format: "%.2fm", handshake.distance!)
            let tx: String = handshake.TXPowerlevel == nil ? " -- " : String(format: "%.2f", handshake.TXPowerlevel!)
            let rssi: String = handshake.RSSI == nil ? " -- " : String(format: "%.2f", handshake.RSSI!)
            cell.detailTextLabel?.text = "\(dateFormatter.string(from: handshake.timestamp)), distance: est. \(distance), TX: \(tx), RSSI: \(rssi), \(handshake.knownCaseId != nil ? "Exposed" : "Not Exposed")"
        }

        return cell
    }
}

extension HandshakeViewController: UITableViewDelegate {

    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        let targetOffset = CGFloat(targetContentOffset.pointee.y)
        let maximumOffset = scrollView.adjustedContentInset.bottom + scrollView.contentSize.height - scrollView.frame.size.height

        if maximumOffset - targetOffset <= 40.0 {
            loadNextHandshakes()
        }
    }
}

extension HandshakeViewController: STARTracingDelegate {

    func STARTracingStateChanged(_ state: TracingState) {}
    
    func didAddHandshake(_ handshake: HandshakeModel) {
        switch mode {
        case .raw:
            cachedHandshakes.insert(handshake, at: 0)
            tableView?.insertRows(at: [IndexPath(row: 0, section: 0)], with: .top)
        case .grouped:
            reloadModel()
        }
    }
}

extension Data {
    var hexEncodedString: String {
        return map { String(format: "%02hhx ", $0) }.joined()
    }

    var STARHeadIndentifier: String? {
        let head = self[0..<4]
        guard let identifier = String(data: head, encoding: .utf8) else {
            return nil
        }
        return identifier
    }
}
