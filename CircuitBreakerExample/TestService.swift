import Foundation
import UIKit

public class TestService {

    public typealias CompletionBlock = (Data?, Error?) -> Void
    
    public func successCall(completion: @escaping CompletionBlock) {
        makeCall(path: "get", completion: completion)
    }
    
    public func failureCall(completion: @escaping CompletionBlock) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(1)) {
            completion(nil, NSError(domain: "TestService", code: 404, userInfo: nil))
        }
    }
    
    public func delayedCall(delayInSeconds: Int, completion: @escaping CompletionBlock) {
        makeCall(path: "delay/\(delayInSeconds)", completion: completion)
    }
    
    private func makeCall(path: String, completion: @escaping CompletionBlock) {
        
        
        let task = URLSession.shared.dataTask(with: URL(string: "https://httpbin.org/\(path)")!, completionHandler: { (data, response, error) in
            
            DispatchQueue.main.async {
                completion(data, error)
            }
        })
        task.resume()
    }
    
}
