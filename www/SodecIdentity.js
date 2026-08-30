var exec = require('cordova/exec');

var SodecIdentity = {
    startVerificationWithToken: function (options, successCallback, errorCallback) {
        exec(successCallback, errorCallback, 'SodecIdentity', 'startVerification', [options]);
    },
    
    startVerificationWithIDNumber: function (options, successCallback, errorCallback) {
        exec(successCallback, errorCallback, 'SodecIdentity', 'startVerificationWithIDNumber', [options]);
    }
};

module.exports = SodecIdentity;
