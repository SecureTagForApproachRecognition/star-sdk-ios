//

import STARSDK_CALIBRATION
import UIKit
import SnapKit
import STARSDK

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

    init() {
        super.init(nibName: nil, bundle: nil)
        title = "HandShakes"
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if cachedHandshakes.isEmpty {
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
        cell.textLabel?.text = handshake.star.base64EncodedString()
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
