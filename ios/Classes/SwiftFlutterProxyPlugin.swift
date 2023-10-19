import Flutter
import UIKit

public class SwiftFlutterProxyPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "native_flutter_proxy", binaryMessenger: registrar.messenger())
    let instance = SwiftFlutterProxyPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
        case "getProxySetting":
            result(getProxySetting())
            break
        default:
            result(FlutterMethodNotImplemented)
            break
    }
  }

    func getProxySetting() -> NSDictionary? {
        guard let proxySettings = CFNetworkCopySystemProxySettings()?.takeUnretainedValue(),
            let url = URL(string: "https://www.bing.com/") else {
                return nil
        }
        let proxies = CFNetworkCopyProxiesForURL((url as CFURL), proxySettings).takeUnretainedValue() as NSArray
        guard let settings = proxies.firstObject as? NSDictionary,
            let _ = settings.object(forKey: (kCFProxyTypeKey as String)) as? String else {
                return nil
        }
        for proxy in proxies {
            if let proxyDictionary = proxy as? NSDictionary {
                if let autoconfigUrl = proxyDictionary.value(forKey: (kCFProxyAutoConfigurationURLKey as String)), let proxyURL = URL(string: String(describing: autoconfigUrl)) as CFURL?, let hostCfUrl = url as CFURL? {
                    
                    return Single.create { (singleEvent: @escaping (SingleEvent<Any?>) -> Void) -> Disposable in
                        ProxyMethodCallHandler.emit = singleEvent
                        var context = CFStreamClientContext(version: CFIndex(0), info: nil, retain: nil, release: nil, copyDescription: nil)
                        let runLoopSource = CFNetworkExecuteProxyAutoConfigurationURL(proxyURL , hostCfUrl, {(_, proxies, __ ) in
                            if let proxyArray = proxies as? [Dictionary<CFString, Any>] {
                                var message = ""
                                for dictionary in proxyArray {
                                    for (key, value) in dictionary {
                                        message = "\(message);key: \(key) with type \(key.self), value: \(value)"
                                    }
                                    if let host = dictionary[kCFProxyHostNameKey], let port = dictionary[kCFProxyPortNumberKey]{
                                        return ["host":host, "port":port]
                                    }
                                }
                                return nil
                            } else {
                                return nil
                            }
                        }, &context)
                        let runLoop: CFRunLoop = CFRunLoopGetCurrent()
                        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource.takeUnretainedValue(), CFRunLoopMode.defaultMode)
                    }
                }
            }
        }

        if let hostName = settings.object(forKey: (kCFProxyHostNameKey as String)), let port = settings.object(forKey: (kCFProxyPortNumberKey as String)) {
            return ["host":hostName, "port":port]
        }
        return nil;
    }
}