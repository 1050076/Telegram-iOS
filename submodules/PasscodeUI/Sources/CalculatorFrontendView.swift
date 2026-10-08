import Foundation
import UIKit
import Display
import AsyncDisplayKit

/// A stock-calculator view (UIKit) hosted inside the passcode lock screen.
/// Black background, dark rounded-square digit keys, orange operation keys,
/// and a right-aligned display - visually indistinguishable from the iOS
/// system calculator. Digits are reported through `onDigit`, `=` through
/// `onEquals`, backspace (via AC long-press behavior is not needed: AC also
/// clears the accumulated passcode entry) through `onClear`.
final class CalculatorFrontendView: UIView, UITextFieldDelegate {
    var onDigit: ((String) -> Void)?
    var onEquals: (() -> Void)?
    var onClear: (() -> Void)?
    var onBackspace: (() -> Void)?
    
    private let displayLabel = UILabel()
    private var buttonViews: [String: UIButton] = [:]
    
    private let displayFont = UIFont.monospacedDigitSystemFont(ofSize: 64.0, weight: .light)
    
    private var displayValue: Double = 0
    private var displayText: String = "0"
    private var accumulator: Double?
    private var pendingOperation: Character?
    private var typingNewNumber = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = UIColor(red: 0.071, green: 0.071, blue: 0.078, alpha: 1.0) // near-black, like the system calculator
        self.buildUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private let keypadLayout: [[(String, String)]] = [
        [("AC", "func"), ("±", "func"), ("%", "func"), ("÷", "op")],
        [("7", "num"), ("8", "num"), ("9", "num"), ("×", "op")],
        [("4", "num"), ("5", "num"), ("6", "num"), ("−", "op")],
        [("1", "num"), ("2", "num"), ("3", "num"), ("+", "op")],
        [("0", "num"), (".", "num"), ("=", "op")],
    ]
    
    private func buildUI() {
        self.displayLabel.text = "0"
        self.displayLabel.textColor = .white
        self.displayLabel.font = self.displayFont
        self.displayLabel.textAlignment = .right
        self.displayLabel.adjustsFontSizeToFitWidth = true
        self.displayLabel.minimumScaleFactor = 0.25
        self.displayLabel.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(self.displayLabel)
        
        var rows: [UIStackView] = []
        for row in self.keypadLayout {
            let rowView = UIStackView()
            rowView.axis = .horizontal
            rowView.distribution = .fillEqually
            rowView.spacing = 12.0

            for (label, kind) in row {
                let button = self.makeButton(label: label, kind: kind)
                rowView.addArrangedSubview(button)
                self.buttonViews[label] = button
            }
            rows.append(rowView)
        }
        
        let grid = UIStackView()
        grid.axis = .vertical
        grid.spacing = 12.0
        grid.distribution = .fillEqually

        for row in rows {
            grid.addArrangedSubview(row)
        }
        grid.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(grid)
        
        // Pure Auto Layout, no manual frames. The 5 keypad rows equally
        // stretch to the screen bottom, and the display takes everything
        // above the keypad with its text floating right above the keys -
        // standard calculator structure. This resolves correctly regardless
        // of when the host view receives its bounds, unlike a manual
        // layoutSubviews pass that runs with a zero-size frame on first
        // layout and leaves the whole keypad invisible (blank screen with
        // only the "0" showing).
        NSLayoutConstraint.activate([
            self.displayLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 16.0),
            self.displayLabel.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -16.0),
            self.displayLabel.topAnchor.constraint(greaterThanOrEqualTo: self.safeAreaLayoutGuide.topAnchor, constant: 12.0),
            
            grid.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 12.0),
            grid.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -12.0),
            grid.bottomAnchor.constraint(equalTo: self.safeAreaLayoutGuide.bottomAnchor, constant: -12.0),
            grid.topAnchor.constraint(equalTo: self.displayLabel.bottomAnchor, constant: 12.0),
            
            // Force the keypad to claim most of the screen: with top pinned
            // to the display and bottom pinned to the safe area, this makes
            // the grid stretch (fillEqually rows grow) instead of collapsing
            // to the content height (~77pt keys). The display shrinks to its
            // intrinsic height above it.
            grid.heightAnchor.constraint(greaterThanOrEqualTo: self.heightAnchor, multiplier: 0.62),
        ])
        
        // The display hugs its content so the big number sits right above
        // the keypad (like the system calculator) while the label's frame
        // itself may extend to the top of the screen. (These calls return
        // Void and must stay outside the NSLayoutConstraint array.)
        self.displayLabel.setContentHuggingPriority(.required, for: .vertical)
        self.displayLabel.setContentCompressionResistancePriority(.required, for: .vertical)
    }
    
    private func makeButton(label: String, kind: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(label, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 32.0, weight: .regular)
        switch kind {
            case "op":
                button.backgroundColor = UIColor(red: 1.0, green: 0.58, blue: 0.0, alpha: 1.0)
                button.setTitleColor(.black, for: .normal)
            case "func":
                button.backgroundColor = UIColor(red: 0.24, green: 0.24, blue: 0.26, alpha: 1.0)
                button.setTitleColor(.white, for: .normal)
            default:
                button.backgroundColor = UIColor(red: 0.16, green: 0.16, blue: 0.17, alpha: 1.0)
                button.setTitleColor(.white, for: .normal)
        }
        button.layer.cornerRadius = 40.0
        button.clipsToBounds = true

        button.addTarget(self, action: #selector(self.buttonPressed(_:)), for: .touchUpInside)
        return button
    }
    
    @objc private func buttonPressed(_ sender: UIButton) {
        guard let title = sender.title(for: .normal) else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        switch title {
            case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
                self.onDigit?(title)
                self.inputDigit(title)
            case ".":
                self.inputDot()
            case "+", "−", "×", "÷":
                self.setOperation(title)
            case "=":
                self.applyPending()
                self.onEquals?()
            case "AC":
                self.onClear?()
                self.allClear()
            case "±":
                self.toggleSign()
            case "%":
                self.percent()
            default:
                break
        }
    }
    
    // MARK: Calculator logic (fully functional display)
    
    private func updateDisplay() {
        if self.displayValue.isNaN || self.displayValue.isInfinite {
            self.displayText = "Error"
        } else if self.displayValue == self.displayValue.rounded() && abs(self.displayValue) < 1e12 {
            self.displayText = String(Int64(self.displayValue))
        } else {
            var text = String(format: "%.10g", self.displayValue)
            if text.hasSuffix(".0") {
                text.removeLast(2)
            }
            self.displayText = text
        }
        self.displayLabel.text = self.displayText
    }
    
    private func inputDigit(_ digit: String) {
        if self.typingNewNumber || self.displayText == "0" {
            self.displayText = digit
            self.displayValue = Double(digit) ?? 0
            self.typingNewNumber = false
        } else if self.displayText.count < 12 {
            self.displayText += digit
            self.displayValue = Double(self.displayText) ?? 0
        }
        self.updateDisplay()
    }
    
    private func inputDot() {
        if self.typingNewNumber {
            self.displayText = "0."
            self.displayValue = 0
            self.typingNewNumber = false
        } else if !self.displayText.contains(".") {
            self.displayText += "."
        }
        self.displayLabel.text = self.displayText
    }
    
    private func setOperation(_ symbol: String) {
        let op: Character
        switch symbol {
            case "÷": op = "/"
            case "×": op = "*"
            case "−": op = "-"
            case "+": op = "+"
            default: return
        }
        let current = self.displayValue
        if let acc = self.accumulator, let pending = self.pendingOperation {
            self.accumulator = self.compute(acc, current, pending)
            self.displayValue = self.accumulator ?? 0
            self.updateDisplay()
        } else {
            self.accumulator = current
        }
        self.pendingOperation = op
        self.typingNewNumber = true
    }
    
    private func applyPending() {
        let current = self.displayValue
        if let acc = self.accumulator, let pending = self.pendingOperation {
            self.displayValue = self.compute(acc, current, pending)
            self.accumulator = nil
            self.pendingOperation = nil
            self.updateDisplay()
        }
        self.typingNewNumber = true
    }
    
    private func allClear() {
        self.displayValue = 0
        self.displayText = "0"
        self.accumulator = nil
        self.pendingOperation = nil
        self.typingNewNumber = false
        self.displayLabel.text = self.displayText
    }
    
    func reset() {
        self.allClear()
    }
    
    private func toggleSign() {
        if self.displayText != "0" {
            if self.displayText.hasPrefix("-") {
                self.displayText.removeFirst()
            } else {
                self.displayText = "-" + self.displayText
            }
            self.displayValue = Double(self.displayText) ?? 0
            self.displayLabel.text = self.displayText
        }
    }
    
    private func percent() {
        self.displayValue = self.displayValue / 100.0
        self.updateDisplay()
        self.typingNewNumber = true
    }
    
    private func compute(_ a: Double, _ b: Double, _ op: Character) -> Double {
        switch op {
            case "+": return a + b
            case "-": return a - b
            case "*": return a * b
            case "/": return b == 0 ? Double.nan : a / b
            default: return b
        }
    }
}