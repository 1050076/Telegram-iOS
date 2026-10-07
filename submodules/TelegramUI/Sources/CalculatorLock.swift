import Foundation
import UIKit

/// Calculator-frontend lock screen. Presents a fully functional calculator;
/// typing the secret sequence followed by `=` unlocks and reveals the app.
final class CalculatorLock {
    static let shared = CalculatorLock()
    
    private let secretSequence = "832800"
    private var window: UIWindow?
    private var controller: CalculatorLockController?
    private var enteredDigits = ""
    
    var isLocked: Bool {
        return self.window != nil
    }
    
    func lock(animated: Bool = true) {
        guard let scene = UIApplication.shared.connectedScenes.first(where: { ($0 as? UIWindowScene) != nil }) as? UIWindowScene else {
            return
        }
        if self.window == nil {
            let window = UIWindow(windowScene: scene)
            window.windowLevel = .alert + 100.0
            let controller = CalculatorLockController()
            controller.onDigit = { [weak self] digit in
                self?.handleDigit(digit)
            }
            controller.onEquals = { [weak self] in
                self?.checkSecret()
            }
            controller.onClear = { [weak self] in
                self?.enteredDigits = ""
            }
            window.rootViewController = controller
            self.window = window
            self.controller = controller
        }
        self.window?.isHidden = false
        if animated, let window = self.window {
            window.alpha = 0.0
            UIView.animate(withDuration: 0.18, animations: {
                window.alpha = 1.0
            })
        }
    }
    
    func unlock(animated: Bool = true) {
        guard let window = self.window else {
            return
        }
        self.enteredDigits = ""
        let completion = { [weak self] in
            window.isHidden = true
            self?.window = nil
            self?.controller = nil
        }
        if animated {
            UIView.animate(withDuration: 0.25, animations: {
                window.alpha = 0.0
            }, completion: { _ in
                completion()
            })
        } else {
            completion()
        }
    }
    
    private func handleDigit(_ digit: String) {
        if self.enteredDigits.count < 16 {
            self.enteredDigits.append(digit)
        } else {
            self.enteredDigits = digit
        }
    }
    
    private func checkSecret() {
        if self.enteredDigits == self.secretSequence {
            self.unlock()
        } else {
            self.enteredDigits = ""
        }
    }
}