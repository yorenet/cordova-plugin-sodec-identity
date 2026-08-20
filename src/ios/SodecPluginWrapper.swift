import Foundation
import Cordova
import SAMobileCapture

@objc(SodecPluginWrapper)
class SodecPluginWrapper: CDVPlugin, SACustomerVerificationDelegate {
    
    var currentCallbackId: String?

    @objc(startVerification:)
    func startVerification(command: CDVInvokedUrlCommand) {
        self.currentCallbackId = command.callbackId
        
        guard let options = command.arguments[0] as? [String: Any],
              let token = options["token"] as? String else {
            let pluginResult = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "Geçersiz parametre veya token eksik.")
            self.commandDelegate?.send(pluginResult, callbackId: command.callbackId)
            return
        }

        let baseUrl = options["baseUrl"] as? String ?? "https://testkyccloud.sodec.com/"
        let clientId = options["clientId"] as? String ?? "8502111d-6cd8-4efa-b624-336f76b12a12"
        let clientKey = options["clientKey"] as? String ?? "3b1997a3-192c-490e-af7f-663bfb316147"

        DispatchQueue.main.async {
            // SAFileManager temizliği (Doküman önerisi)
            SAFileManager.removeDocumentDirectory()

            guard let apiManager = SAApiManager(baseUrl: baseUrl, withSubscriptionId: clientId, withSubscriptionKey: clientKey) else {
                let pluginResult = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "SAApiManager başlatılamadı.")
                self.commandDelegate?.send(pluginResult, callbackId: command.callbackId)
                return
            }

            // Temel API Ayarları
            apiManager.timeout = 30.0
            apiManager.scenario = "1"
            apiManager.showServiceErrors = true
            apiManager.processReturnType = .toInitialProcess
            apiManager.minimumAgeForKyc = 18
            apiManager.enableHologramAndOviDetection = false
            apiManager.nfcVerificationMandatory = false
            apiManager.enableMaskDetection = true
            apiManager.maxCountOfAttemptsForLiveness = 10
            apiManager.maxCountOfAttemptsForFaceVerification = 3
            apiManager.displayTypeOfKycVerificationResult = .alwaysShow

            // İstenmeyen Kimlik Tipleri
            let undesiredIdentityTypes = SAIdentityTypes()
            undesiredIdentityTypes?.add(.oldIdentityCard)
            undesiredIdentityTypes?.add(.oldDrivingLicense)
            undesiredIdentityTypes?.add(.newDrivingLicense)
            undesiredIdentityTypes?.add(.passport)
            undesiredIdentityTypes?.add(.oldResidencePermit)
            undesiredIdentityTypes?.add(.newResidencePermit)
            undesiredIdentityTypes?.add(.temporaryProtection)
            apiManager.undesiredIdentityTypes = undesiredIdentityTypes

            // Ekran Oluşturma ve Present
            if let customerVerification = apiManager.createCustomerVerification(self, withToken: token) {
                self.viewController?.present(customerVerification, animated: true, completion: nil)
            } else {
                let pluginResult = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "CustomerVerification ekranı oluşturulamadı.")
                self.commandDelegate?.send(pluginResult, callbackId: command.callbackId)
            }
        }
    }

    // MARK: - SACustomerVerificationDelegate

    func customerVerificationDidCancel(_ controller: SACustomerVerification!) {
        controller.dismiss(animated: true) {
            if let callbackId = self.currentCallbackId {
                let pluginResult = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "CANCELLED")
                self.commandDelegate?.send(pluginResult, callbackId: callbackId)
            }
        }
    }

    func customerVerificationDidDone(_ controller: SACustomerVerification!, with verificationResultType: SAVerificationResultType, with buttonActionType: SAButtonActionType) {
        controller.dismiss(animated: true) {
            if let callbackId = self.currentCallbackId {
                var statusString = "Unknown"
                if verificationResultType == .approved {
                    statusString = "Approved"
                } else if verificationResultType == .pending {
                    statusString = "Pending"
                }

                let resultDict: [String: Any] = [
                    "status": statusString,
                    "buttonAction": "\(buttonActionType.rawValue)"
                ]

                let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: resultDict)
                self.commandDelegate?.send(pluginResult, callbackId: callbackId)
            }
        }
    }

    func customerVerificationDidError(_ controller: SACustomerVerification!, withErrorMessage errorMessage: String!) {
        controller.dismiss(animated: true) {
            if let callbackId = self.currentCallbackId {
                let pluginResult = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: errorMessage ?? "Unknown Error")
                self.commandDelegate?.send(pluginResult, callbackId: callbackId)
            }
        }
    }
}