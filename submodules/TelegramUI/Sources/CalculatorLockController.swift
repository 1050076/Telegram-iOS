import Foundation
import UIKit

/// A plain UIKit calculator UI used as the lock front. Fully functional
/// (+ − × ÷, AC, ±, %) so it behaves exactly like the system calculator.
final class CalculatorLockController: UIViewController {
    var onDigit: ((String) -> Void)?
    var onEquals: (() -> Void)?
    var onClear: (() -> Void)?
    
    private var displayValue: String = "0"
    private var accumulator: Double? = nil
    private var pendingOperation: Character? = nil
    private var typingNewNumber = false
    
    private let displayLabel = UILabel()
    private var buttons: [UIButton] = []
    
    private let bgColor = UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0)
    private let displayBgColor = UIColor(red: 0.17, green: 0.17, blue: 0.18, alpha: 1.0)
    private let numBgColor = UIColor(red: 0.24, green: 0.24, blue: 0.26, alpha: 1.0)
    private let opBgColor = UIColor(red: 1.0, green: 0.62, blue: 0.04, alpha: 1.0)
    private let funcBgColor = UIColor(red: 0.38, green: 0.38, blue: 0.40, alpha: 1.0)
    
    private let layout: [[(String, String)]] = [
        [("AC", "func"), ("±", "func"), ("%", "func"), ("÷", "op")],
        [("7", "num"), ("8", "num"), ("9", "num"), ("×", "op")],
        [("4", "num"), ("5", "num"), ("6", "num"), ("−", "op")],
        [("1", "num"), ("2", "num"), ("3", "num"), ("+", "op")],
        [("0", "num"), (".", "num"), ("=", "op")],
    ]
    
    override func loadView() {
        let view = UIView()
        view.backgroundColor = self.bgColor
        self.view = view
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.buildUI()
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    private func buildUI() {
        let safe = self.view.safeAreaLayoutGuide
        
        let displayContainer = UIView()
        displayContainer.backgroundColor = self.displayBgColor
        displayContainer.layer.cornerRadius = 20.0
        displayContainer.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(displayContainer)
        
        self.displayLabel.text = "0"
        self.displayLabel.textColor = .white
        self.displayLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 76.0, weight: .light)
        self.displayLabel.textAlignment = .right
        self.displayLabel.adjustsFontSizeToFitWidth = true
        self.displayLabel.minimumScaleFactor = 0.3
        self.displayLabel.translatesAutoresizingMaskIntoConstraints = false
        displayContainer.addSubview(self.displayLabel)
        
        let buttonContainer = UIView()
        buttonContainer.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(buttonContainer)
        
        NSLayoutConstraint.activate([
            displayContainer.topAnchor.constraint(equalTo: safe.topAnchor, constant: 16.0),
            displayContainer.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16.0),
            displayContainer.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16.0),
            displayContainer.heightAnchor.constraint(equalToConstant: 140.0),
            
            self.displayLabel.leadingAnchor.constraint(equalTo: displayContainer.leadingAnchor, constant: 24.0),
            self.displayLabel.trailingAnchor.constraint(equalTo: displayContainer.trailingAnchor, constant: -24.0),
            self.displayLabel.centerYAnchor.constraint(equalTo: displayContainer.centerYAnchor),
            
            buttonContainer.topAnchor.constraint(equalTo: displayContainer.bottomAnchor, constant: 16.0),
            buttonContainer.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16.0),
            buttonContainer.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16.0),
            buttonContainer.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -16.0),
        ])
        
        var rowViews: [UIView] = []
        let vertical = UIStackView()
        vertical.axis = .vertical
        vertical.distribution = .fillEqually
        vertical.spacing = 12.0
        vertical.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.addSubview(vertical)
        NSLayoutConstraint.activate([
            vertical.leadingAnchor.constraint(equalTo: buttonContainer.leadingAnchor),
            vertical.trailingAnchor.constraint(equalTo: buttonContainer.trailingAnchor),
            vertical.topAnchor.constraint(equalTo: buttonContainer.topAnchor),
            vertical.bottomAnchor.constraint(equalTo: buttonContainer.bottomAnchor),
        ])
        for row in self.layout {
            let rowView = UIStackView()
            rowView.axis = .horizontal
            rowView.distribution = .fillEqually
            rowView.spacing = 12.0
            vertical.addArrangedSubview(rowView)
            rowViews.append(rowView)
            for (label, kind) in row {
                let button = self.makeButton(label: label, kind: kind)
                rowView.addArrangedSubview(button)
                self.buttons.append(button)
            }
        }
    }
    
    private func makeButton(label: String, kind: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(label, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 34.0, weight: .regular)
        button.layer.cornerRadius = 40.0
        button.clipsToBounds = true
        switch kind {
        case "op":
            button.backgroundColor = self.opBgColor
            button.setTitleColor(.black, for: .normal)
        case "func":
            button.backgroundColor = self.funcBgColor
            button.setTitleColor(.white, for: .normal)
        default:
            button.backgroundColor = self.numBgColor
            button.setTitleColor(.white, for: .normal)
        }
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
            self.onEquals?()
            self.applyOperation()
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
    
    // MARK: Calculator logic
    
    private func inputDigit(_ digit: String) {
        if self.typingNewNumber || self.displayValue == "0" {
            self.displayValue = digit
            self.typingNewNumber = false
        } else {
            if self.displayValue.replacingOccurrences(of: "-", with: "").count < 12 {
                self.displayValue += digit
            }
        }
        self.updateDisplay()
    }
    
    private func inputDot() {
        if self.typingNewNumber {
            self.displayValue = "0."
            self.typingNewNumber = false
        } else if !self.displayValue.contains(".") {
            self.displayValue += "."
        }
        self.updateDisplay()
    }
    
    private func setOperation(_ symbol: String) {
        let op: Character
        switch symbol {
        case "+": op = "+"
        case "−": op = "-"
        case "×": op = "*"
        case "÷": op = "/"
        default: return
        }
        let current = Double(self.displayValue) ?? 0.0
        if let acc = self.accumulator, let pending = self.pendingOperation, !self.typingNewNumber {
            let result = self.compute(acc, current, pending)
            self.accumulator = result
            self.displayValue = self.formatNumber(result)
            self.updateDisplay()
        } else {
            self.accumulator = current
        }
        self.pendingOperation = op
        self.typingNewNumber = true
    }
    
    private func applyOperation() {
        let current = Double(self.displayValue) ?? 0.0
        if let acc = self.accumulator, let pending = self.pendingOperation {
            let result = self.compute(acc, current, pending)
            self.displayValue = self.formatNumber(result)
            self.accumulator = nil
            self.pendingOperation = nil
            self.updateDisplay()
        }
        self.typingNewNumber = true
    }
    
    private func allClear() {
        self.displayValue = "0"
        self.accumulator = nil
        self.pendingOperation = nil
        self.typingNewNumber = false
        self.updateDisplay()
    }
    
    private func toggleSign() {
        if self.displayValue != "0" {
            if self.displayValue.hasPrefix("-") {
                self.displayValue.removeFirst()
            } else {
                self.displayValue = "-" + self.displayValue
            }
            self.updateDisplay()
        }
    }
    
    private func percent() {
        let current = Double(self.displayValue) ?? 0.0
        self.displayValue = self.formatNumber(current / 100.0)
        self.updateDisplay()
        self.typingNewNumber = true
    }
    
    private func compute(_ a: Double, _ b: Double, _ op: Character) -> Double {
        switch op {
        case "+": return a + b
        case "-": return a - b
        case "*": return a * b
        case "/": return b == 0 ? 0 : a / b
        default: return b
        }
    }
    
    private func formatNumber(_ value: Double) -> String {
        if value.isNaN || value.isInfinite {
            return "错误"
        }
        if value == value.rounded() && abs(value) < 1e12 {
            let int = Int64(value)
            return String(int)
        }
        var text = String(format: "%.10g", value)
        if text.hasSuffix(".0") {
            text.removeLast(2)
        }
        return text
    }
    
    private func updateDisplay() {
        self.displayLabel.text = self.displayValue
    }
}