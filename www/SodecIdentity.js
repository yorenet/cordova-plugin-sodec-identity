var exec = require('cordova/exec');

var SodecIdentity = {
    startCapture: function (options, successCallback, errorCallback) {
        // "SodecIdentity" matches the feature name in plugin.xml
        // "startCapture" matches the method inside Java/Swift wrappers
        exec(successCallback, errorCallback, 'SodecIdentity', 'startCapture', [options]);
    }
};

module.exports = SodecIdentity;