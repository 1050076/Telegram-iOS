import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import GradientBackground

/// Calculator-styled lock keyboard: looks and works like a plain calculator
/// (AC, ±, %, ÷, ×, −, +, =, decimal point), while digits 0-9 double as the
/// passcode entry path. Operations perform real calculations on the built-in
/// display so the screen behaves exactly like a stock calculator app.
final class CalculatorLockKeyboardNode: ASDisplayNode {
    private var presentationData: PresentationData?
    private var background: PasscodeBackground?
    
    var digitEntered: ((String) -> Void)?
    var backspace: (() -> Void)?
    var equalsPressed: (() -> Void)?
    
    private let displayNode: ASDisplayNode
    private let displayLabelNode: ImmediateTextNode
    
    private var buttonNodes: [String: PasscodeEntryButtonNode] = [:]
    
    private var displayValue: Double = 0
    private var displayText: String = "0"
    private var accumulator: Double?
    private var pendingOperation: Character?
    private var typingNewNumber = false
    
    private var validSize: CGSize?
    
    override init() {
        self.displayNode = ASDisplayNode()
        self.displayNode.cornerRadius = 20.0
        self.displayNode.clipsToBounds = true
        self.displayNode.backgroundColor = UIColor(white: 1.0, alpha: 0.12)
        
        self.displayLabelNode = ImmediateTextNode()
        self.displayLabelNode.maximumNumberOfLines = 1
        self.displayLabelNode.textAlignment = .right
        
        super.init()
        
        self.addSubnode(self.displayNode)
        self.displayNode.addSubnode(self.displayLabelNode)
    }
    
    func updateBackground(_ presentationData: PresentationData, _ background: PasscodeBackground) {
        self.presentationData = presentationData
        self.background = background
        
        // Layout: 4 columns × 5 rows calculator grid
        let rows: [[String]] = [
            ["AC", "±", "%", "÷"],
            ["7", "8", "9", "×"],
            ["4", "5", "6", "−"],
            ["1", "2", "3", "+"],
            ["0", ".", "=", ""],
        ]
        var allKeys: [String] = []
        for row in rows {
            for key in row where !key.isEmpty {
                allKeys.append(key)
            }
        }
        
        if self.buttonNodes.isEmpty {
            for key in allKeys {
                let buttonNode = PasscodeEntryButtonNode(presentationData: presentationData, background: background, title: key, subtitle: "")
                buttonNode.accessibilityLabel = key
                switch key {
                    case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
                        buttonNode.action = { [weak self] in
                            self?.digitEntered?(key)
                        }
                    case ".":
                        buttonNode.action = { [weak self] in
                            self?.inputDot()
                        }
                    case "AC":
                        buttonNode.action = { [weak self] in
                            self?.backspace?()
                            self?.allClear()
                        }
                    case "±":
                        buttonNode.action = { [weak self] in
                            self?.toggleSign()
                        }
                    case "%":
                        buttonNode.action = { [weak self] in
                            self?.percent()
                        }
                    case "÷", "×", "−", "+":
                        buttonNode.action = { [weak self] in
                            self?.setOperation(key)
                        }
                    case "=":
                        buttonNode.action = { [weak self] in
                            self?.applyPending()
                            self?.equalsPressed?()
                        }
                    default:
                        break
                }
                self.buttonNodes[key] = buttonNode
                self.addSubnode(buttonNode)
            }
        } else {
            for buttonNode in self.buttonNodes.values {
                buttonNode.updateBackground(presentationData, background)
            }
        }
        
        if let size = self.validSize {
            let _ = self.updateLayout(size: size, transition: .immediate)
        }
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) -> (CGRect, CGSize) {
        self.validSize = size
        
        let sideInset: CGFloat = 12.0
        let columnSpacing: CGFloat = 12.0
        let rowSpacing: CGFloat = 12.0
        
        let displayHeight: CGFloat = 72.0
        let displayInset: CGFloat = 16.0
        
        let buttonSide = (size.width - sideInset * 2.0 - columnSpacing * 3.0) / 4.0
        let zeroWidth = buttonSide * 2.0 + columnSpacing
        let keyboardHeight = displayHeight + displayInset + buttonSide * 5.0 + rowSpacing * 4.0
        
        // display
        let displayFrame = CGRect(x: sideInset, y: 0.0, width: size.width - sideInset * 2.0, height: displayHeight)
        transition.updateFrame(node: self.displayNode, frame: displayFrame)
        
        let fontSize = max(30.0, min(44.0, displayFrame.height * 0.5))
        self.displayLabelNode.attributedText = NSAttributedString(string: self.displayText, font: Font.monospace(fontSize), textColor: .white)
        let displayTextSize = self.displayLabelNode.updateLayout(CGSize(width: displayFrame.width - 48.0, height: displayFrame.height))
        let displayTextFrame = CGRect(x: displayFrame.width - 24.0 - displayTextSize.width, y: floor((displayFrame.height - displayTextSize.height) / 2.0), width: displayTextSize.width, height: displayTextSize.height)
        transition.updateFrame(node: self.displayLabelNode, frame: displayTextFrame)
        
        // buttons
        let rows: [[String]] = [
            ["AC", "±", "%", "÷"],
            ["7", "8", "9", "×"],
            ["4", "5", "6", "−"],
            ["1", "2", "3", "+"],
            ["0", ".", "="],
        ]
        for rowIndex in 0..<rows.count {
            let row = rows[rowIndex]
            let rowY = displayHeight + displayInset + CGFloat(rowIndex) * (buttonSide + rowSpacing)
            if rowIndex == rows.count - 1 {
                // last row: 0 spans two columns, then ".", then "="
                if let zeroNode = self.buttonNodes["0"] {
                    transition.updateFrame(node: zeroNode, frame: CGRect(x: sideInset, y: rowY, width: zeroWidth, height: buttonSide))
                }
                if let dotNode = self.buttonNodes["."] {
                    transition.updateFrame(node: dotNode, frame: CGRect(x: sideInset + zeroWidth + columnSpacing, y: rowY, width: buttonSide, height: buttonSide))
                }
                if let eqNode = self.buttonNodes["="] {
                    transition.updateFrame(node: eqNode, frame: CGRect(x: sideInset + zeroWidth + columnSpacing * 2.0 + buttonSide, y: rowY, width: buttonSide, height: buttonSide))
                }
            } else {
                for (columnIndex, key) in row.enumerated() {
                    if let buttonNode = self.buttonNodes[key] {
                        let x = sideInset + CGFloat(columnIndex) * (buttonSide + columnSpacing)
                        transition.updateFrame(node: buttonNode, frame: CGRect(x: x, y: rowY, width: buttonSide, height: buttonSide))
                    }
                }
            }
        }
        
        return (CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: keyboardHeight)), CGSize(width: buttonSide, height: buttonSide))
    }
    
    // MARK: Calculator logic (real calculations on the display)
    
    private func updateDisplay() {
        if self.displayValue.isNaN || self.displayValue.isInfinite {
            self.displayText = "错误"
        } else if self.displayValue == self.displayValue.rounded() && abs(self.displayValue) < 1e12 {
            self.displayText = String(Int64(self.displayValue))
        } else {
            var text = String(format: "%.10g", self.displayValue)
            if text.hasSuffix(".0") {
                text.removeLast(2)
            }
            self.displayText = text
        }
        if let size = self.validSize {
            let _ = self.updateLayout(size: size, transition: .immediate)
        }
    }
    
    private func inputDigit(_ digit: String) {
        // Display calculator behavior
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
        self.updateDisplay()
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
        self.updateDisplay()
    }
    
    private func toggleSign() {
        if self.displayText != "0" {
            if self.displayText.hasPrefix("-") {
                self.displayText.removeFirst()
            } else {
                self.displayText = "-" + self.displayText
            }
            self.displayValue = Double(self.displayText) ?? 0
            self.updateDisplay()
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
    
    func animateIn() {
        for subnode in self.subnodes ?? [] {
            subnode.layer.animateScale(from: 0.0001, to: 1.0, duration: 0.25, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue)
        }
    }
    
    func resetDisplay() {
        // Silent reset to zero - used on both wrong passcode and unlock, so
        // the calculator looks exactly like a stock one in every case.
        self.allClear()
    }
    
    func flashError() {
        // Reserved for modal presentations; the calculator frontend stays
        // visually neutral on wrong passcodes (see resetDisplay()).
        let previous = self.displayNode.backgroundColor
        self.displayNode.backgroundColor = UIColor(rgb: 0xff453a, alpha: 0.55)
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.35, execute: { [weak self] in
            self?.displayNode.backgroundColor = previous
        })
        self.allClear()
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        if let result = result, result.isDescendant(of: self.view) {
            return result
        }
        return nil
    }
}