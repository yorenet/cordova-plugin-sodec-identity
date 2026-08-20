package com.yorenet.plugin;

import android.content.Context;
import android.content.Intent;
import android.graphics.Color;
import android.os.Build;
import android.util.Log;
import android.widget.Toast;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.concurrent.TimeUnit;

import com.sodecapps.samobilecapture.SAApiManager;
import com.sodecapps.samobilecapture.SAConfigManager;
import com.sodecapps.samobilecapture.SASSLCertificate;
import com.sodecapps.samobilecapture.SASSLCertificates;
import com.sodecapps.samobilecapture.SATimeoutParams;
import com.sodecapps.samobilecapture.enums.SADetectionAccuracyLevel;
import com.sodecapps.samobilecapture.enums.SAIdentityTypes;
import com.sodecapps.samobilecapture.enums.SAProcessReturnType;
import com.sodecapps.samobilecapture.enums.SAStatusBarStyle;
import com.sodecapps.samobilecapture.enums.SAVerificationResultType;
import com.sodecapps.samobilecapture.enums.SADefineIdentity;

public class SodecPluginWrapper extends CordovaPlugin {

    private static final String TAG = "SodecPluginWrapper";
    private static final int CUSTOMER_VERIFICATION_REQUEST_CODE = 1001;
    private CallbackContext currentCallbackContext;

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {
        if ("startVerification".equals(action)) {
            this.currentCallbackContext = callbackContext;
            JSONObject options = args.getJSONObject(0);
            
            cordova.getActivity().runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    try {
                        startSdkVerification(options);
                    } catch (Exception e) {
                        Log.e(TAG, "SDK Başlatma Hatası", e);
                        callbackContext.error("SDK Initialization Failed: " + e.getMessage());
                    }
                }
            });
            return true;
        }
        return false;
    }

    private void startSdkVerification(JSONObject options) throws Exception {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
            Toast.makeText(cordova.getActivity(), "Kimlik doğrulama için Android 21 ve üzeri gereklidir.", Toast.LENGTH_LONG).show();
            currentCallbackContext.error("UNSUPPORTED_OS_VERSION");
            return;
        }

        String token = options.optString("token", "");
        String baseUrl = options.optString("baseUrl", "https://testkyccloud.sodec.com/");
        String clientId = options.optString("clientId", "8502111d-6cd8-4efa-b624-336f76b12a12");
        String clientKey = options.optString("clientKey", "3b1997a3-192c-490e-af7f-663bfb316147");

        Context context = cordova.getActivity().getApplicationContext();

        // 1. UI Konfigürasyonu
        SAConfigManager configManager = new SAConfigManager();
        configManager.setDebuggable(true);
        configManager.setLanguage("tr");
        configManager.setDeasciifing(false);
        configManager.setPreventTakingScreenshots(false);
        configManager.setPrimaryColor(Color.parseColor("#172E4D"));
        configManager.setAccentColor(Color.parseColor("#FF8000"));
        configManager.setBarColor(Color.WHITE);
        configManager.setStatusBarStyle(SAStatusBarStyle.DARK);
        configManager.setButtonsRounded(true);
        configManager.applyAndSaveChanges(context);

        // 2. API Yöneticisi Konfigürasyonu
        SASSLCertificates sslCertificates = new SASSLCertificates();
        // Gerekirse SSL cert eklenebilir
        SAApiManager apiManager = new SAApiManager(baseUrl, clientId, clientKey, sslCertificates);

        SATimeoutParams timeoutParams = new SATimeoutParams();
        timeoutParams.setTimeUnit(TimeUnit.SECONDS);
        timeoutParams.setConnectTimeout(30);
        timeoutParams.setWriteTimeout(30);
        timeoutParams.setReadTimeout(30);
        apiManager.setTimeoutParams(timeoutParams);

        apiManager.setScenario("1");
        apiManager.setShowServiceErrors(true);
        apiManager.setProcessReturnType(SAProcessReturnType.TO_INITIAL_PROCESS);
        apiManager.setMinimumAgeForKyc(18);
        apiManager.setEnableHologramAndOviDetection(false);
        apiManager.setNfcVerificationMandatory(false);
        apiManager.setAskToEnableNfcBeforeStartingIDCapture(true);
        apiManager.setEnableMaskDetection(true);
        apiManager.setMaxCountOfAttemptsForLiveness(10);
        apiManager.setMaxCountOfAttemptsForFaceVerification(3);

        // 3. İstenmeyen Kimlik Tipleri
        SAIdentityTypes undesiredIdentityTypes = new SAIdentityTypes();
        undesiredIdentityTypes.addIdentityType(SADefineIdentity.SAIdentityType.OldIdentityCard);
        undesiredIdentityTypes.addIdentityType(SADefineIdentity.SAIdentityType.OldDrivingLicense);
        undesiredIdentityTypes.addIdentityType(SADefineIdentity.SAIdentityType.NewDrivingLicense);
        undesiredIdentityTypes.addIdentityType(SADefineIdentity.SAIdentityType.Passport);
        undesiredIdentityTypes.addIdentityType(SADefineIdentity.SAIdentityType.OldResidencePermit);
        undesiredIdentityTypes.addIdentityType(SADefineIdentity.SAIdentityType.NewResidencePermit);
        undesiredIdentityTypes.addIdentityType(SADefineIdentity.SAIdentityType.TemporaryProtection);
        apiManager.setUndesiredIdentityTypes(undesiredIdentityTypes);

        // Cordova Activity listener kaydı
        cordova.setActivityResultCallback(this);

        // SDK Aktivitesini Başlat
        apiManager.startCustomerVerificationWithToken(cordova.getActivity(), CUSTOMER_VERIFICATION_REQUEST_CODE, token);
    }

    @Override
    public void onActivityResult(int requestCode, int resultCode, Intent intent) {
        super.onActivityResult(requestCode, resultCode, intent);

        if (requestCode == CUSTOMER_VERIFICATION_REQUEST_CODE) {
            if (currentCallbackContext == null) return;

            if (resultCode == android.app.Activity.RESULT_OK && intent != null) {
                // SDK Sonucunu Parse Et
                String verificationResult = intent.getStringExtra("verificationResultType");
                JSONObject resultJson = new JSONObject();
                try {
                    resultJson.put("status", verificationResult != null ? verificationResult : "Approved");
                    currentCallbackContext.success(resultJson);
                } catch (JSONException e) {
                    currentCallbackContext.success("Approved");
                }
            } else if (resultCode == android.app.Activity.RESULT_CANCELED) {
                currentCallbackContext.error("CANCELLED");
            } else {
                String errorMsg = (intent != null && intent.hasExtra("errorMessage")) ? 
                        intent.getStringExtra("errorMessage") : "UNKNOWN_ERROR";
                currentCallbackContext.error(errorMsg);
            }
        }
    }
}