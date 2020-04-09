//

import STARSDK_CALIBRATION
import UIKit
import SnapKit

class HandshakeViewController: UIViewController {

    private var tableView: UITableView!

    private var cachedHandshakes: [HandshakeModel] = []
    private var nextRequest: HandshakeRequest?
    private let dateFormatter = DateFormatter()

    private enum Mode {
        case raw, grouped
    }
    private var mode: Mode = .raw {
        didSet {
            reloadHandshakes()
        }
    }

    private var didLoadHandshakes = false

    init() {
        super.init(nibName: nil, bundle: nil)
        title = "HandShakes"
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .long
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
        tableView.dataSource = self
        tableView.delegate = self
        view.addSubview(tableView)
        tableView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }

        let refreshControl = UIRefreshControl()
        refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        refreshControl.addTarget(self, action: #selector(refresh(sender:)), for: UIControl.Event.valueChanged)
        tableView.addSubview(refreshControl)

        let segmentedControl = UISegmentedControl(items: ["Raw", "Grouped"])
        segmentedControl.addTarget(self, action: #selector(groupingChanged(sender:)), for: .valueChanged)
        segmentedControl.selectedSegmentIndex = 0
        navigationItem.titleView = segmentedControl
    }

    @objc func didClearData(notification: Notification) {
        cachedHandshakes = []
        didLoadHandshakes = false
        guard tableView != nil else { return }
        self.tableView.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !didLoadHandshakes {
            didLoadHandshakes = true
            reloadHandshakes()
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
        reloadHandshakes()
        sender.endRefreshing()
    }

    private func reloadHandshakes() {
        switch mode {
        case .raw:
            loadHandshakes(request: HandshakeRequest(offset: 0, limit: 30), clear: true)
        case .grouped:
            loadHandshakes(request: HandshakeRequest(), clear: true)
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
                tableView.reloadData()
            } else if response.handshakes.isEmpty == false {
                var indexPathes: [IndexPath] = []
                let base = response.handshakes.count
                let target = base + response.handshakes.count
                for rowIndex in base..<target {
                    indexPathes.append(IndexPath(row: rowIndex, section: 0))
                }
                cachedHandshakes.append(contentsOf: response.handshakes)
                tableView.insertRows(at: indexPathes, with: .bottom)
            }
        } catch {
            let alert = UIAlertController(title: "Error Fetching Handshakes", message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
        }
    }
}

extension HandshakeViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        cachedHandshakes.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell
        if let dequeuedCell = tableView.dequeueReusableCell(withIdentifier: "TVCID") {
            cell = dequeuedCell
        } else {
            cell = UITableViewCell(style: .subtitle, reuseIdentifier: "TVCID")
            cell.textLabel?.numberOfLines = 0
        }

        let handshake = cachedHandshakes[indexPath.row]
        let identifier = String(data: handshake.star[0..<4], encoding: .utf8) ?? "Unable to decode"
        cell.textLabel?.text = "(\(identifier)): \(handshake.star.hexEncodedString)"
        let distance: String = handshake.distance == nil ? "--" : String(format: "%.2fm", handshake.distance!)
        cell.detailTextLabel?.text = "\(dateFormatter.string(from: handshake.timestamp)), \(distance) m, \(handshake.knownCaseId != nil ? "Exposed" : "Not Exposed")"

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

    func errorOccured(_ error: STARTracingErrors) {}

    func didAddHandshake(_ handshake: HandshakeModel) {
        cachedHandshakes.insert(handshake, at: 0)
        guard tableView != nil else { return }
        tableView.insertRows(at: [IndexPath(row: 0, section: 0)], with: .top)
    }
    
}

extension Data {
    var hexEncodedString: String {
        return map { String(format: "%02hhx ", $0) }.joined()
    }
}
