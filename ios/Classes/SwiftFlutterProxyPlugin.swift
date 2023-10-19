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
        if let proxy = proxies.compactMap({ $0 as? NSDictionary })
            .first(where: { $0.value(forKey: kCFProxyAutoConfigurationURLKey as String) != nil }),
           let autoconfigUrl = proxy.value(forKey: kCFProxyAutoConfigurationURLKey as String) as? CFURL,
           let hostCfUrl = url as CFURL {

            var context = CFStreamClientContext(version: CFIndex(0), info: nil, retain: nil, release: nil, copyDescription: nil)
            let runLoopSource = CFNetworkExecuteProxyAutoConfigurationURL(autoconfigUrl, hostCfUrl) { (_, proxies, _) in
                guard let proxyArray = proxies as? [[CFString: Any]] else {
                    return nil
                }

                var message = ""
                for dictionary in proxyArray {
                    for (key, value) in dictionary {
                        message = "\(message);key: \(key) with type \(key.self), value: \(value)"
                    }
                    if let host = dictionary[kCFProxyHostNameKey],
                       let port = dictionary[kCFProxyPortNumberKey] {
                        return ["host": host, "port": port]
                    }
                }
                return nil
            }

            let runLoop: CFRunLoop = CFRunLoopGetCurrent()
            CFRunLoopRemoveSource(runLoop, runLoopSource.takeUnretainedValue(), CFRunLoopMode.defaultMode)

            return nil
        }

        if let hostName = settings.object(forKey: (kCFProxyHostNameKey as String)), let port = settings.object(forKey: (kCFProxyPortNumberKey as String)) {
            return ["host":hostName, "port":port]
        }
        return nil;
    }
}