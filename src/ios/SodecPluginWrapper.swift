import Foundation
import UIKit
import SAMobileCapture

@objc(SodecPluginWrapper)
class SodecPluginWrapper: CDVPlugin, SAMobileCaptureDelegate {
    
    private var currentCommand: CDVInvokedUrlCommand?
    
    // MARK: - Action: startVerification (Token)
    @objc(startVerification:)
    func startVerification(command: CDVInvokedUrlCommand) {
        self.currentCommand = command
        guard let options = command.arguments.first as? [String: Any] else {
            let pluginResult = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "Invalid options parameters")
            self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
            return
        }
        
        DispatchQueue.main.async {
            self.launchSdk(options: options, useIdNumber: false)
        }
    }
    
    // MARK: - Action: startVerificationWithIDNumber (ID Number)
    @objc(startVerificationWithIDNumber:)
    func startVerificationWithIDNumber(command: CDVInvokedUrlCommand) {
        self.currentCommand = command
        guard let options = command.arguments.first as? [String: Any] else {
            let pluginResult = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "Invalid options parameters")
            self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
            return
        }
        
        DispatchQueue.main.async {
            self.launchSdk(options: options, useIdNumber: true)
        }
    }
    
    // MARK: - Private Helper to Init and Launch SAMobileCapture SDK
    private func launchSdk(options: [String: Any], useIdNumber: Bool) {
        let baseUrl = options["baseUrl"] as? String ?? "https://testkyccloud.sodec.com/"
        let clientId = options["clientId"] as? String ?? ""
        let clientKey = options["clientKey"] as? String ?? ""
        
        // 1. UI Setup Configuration
        let configManager = SAConfigManager.shared
        configManager.setLanguage("tr")
        configManager.setPrimaryColor(UIColor(red: 0.09, green: 0.18, blue: 0.30, alpha: 1.0)) // #172E4D
        configManager.setAccentColor(UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0))   // #FF8000
        configManager.setButtonsRounded(true)
        
        // 2. API Manager Configuration
        let apiManager = SAApiManager.shared
        apiManager.setup(baseUrl: baseUrl, clientId: clientId, clientKey: clientKey)
        apiManager.setScenario("1")
        apiManager.setMinimumAgeForKyc(18)
        apiManager.setEnableMaskDetection(true)
        apiManager.setMaxCountOfAttemptsForLiveness(10)
        apiManager.setMaxCountOfAttemptsForFaceVerification(3)
        
        // Set self as Delegate to catch SDK results
        SAMobileCapture.shared.delegate = self
        
        guard let viewController = self.viewController else {
            sendError(message: "NO_VIEW_CONTROLLER")
            return
        }
        
        // 3. Launch SDK with Token vs ID Number
        if useIdNumber {
            let idNumber = options["idNumber"] as? String ?? ""
            SAMobileCapture.shared.startCustomerVerification(
                withIDNumber: idNumber,
                presentingViewController: viewController
            )
        } else {
            let token = options["token"] as? String ?? ""
            SAMobileCapture.shared.startCustomerVerification(
                withToken: token,
                presentingViewController: viewController
            )
        }
    }
    
    // MARK: - SAMobileCaptureDelegate Methods
    
    func didCompleteVerification(result: SAVerificationResult) {
        let response: [String: Any] = [
            "status": "APPROVED",
            "verificationResult": result.resultTypeRawValue ?? "Success"
        ]
        sendSuccess(result: response)
    }
    
    func didFailVerification(error: SAError) {
        sendError(message: error.localizedDescription)
    }
    
    func didCancelVerification() {
        sendError(message: "CANCELLED")
    }
    
    // MARK: - Cordova Output Helpers
    
    private func sendSuccess(result: [String: Any]) {
        guard let command = self.currentCommand else { return }
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: result)
        self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
        self.currentCommand = nil
    }
    
    private func sendError(message: String) {
        guard let command = self.currentCommand else { return }
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: message)
        self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
        self.currentCommand = nil
    }
}
