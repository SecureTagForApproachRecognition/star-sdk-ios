//

import UIKit

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
