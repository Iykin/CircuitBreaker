import UIKit
import CircuitBreaker

class ViewController: UIViewController {
    
    @IBOutlet weak var infoTextView: UITextView!
    
    private let testService = TestService()
    private var circuitBreaker: CircuitBreaker?
    private var callShouldSucceed = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        circuitBreaker = CircuitBreaker(
            timeout: 10.0,
            maxRetries: 2,
            timeBetweenRetries: 2.0,
            exponentialBackoff: true,
            resetTimeout: 2.0
        )
        circuitBreaker?.didTrip = { [weak self] circuitBreaker, error in
            self?.logInfo(info: "Failure (Code: \((error as! NSError).code)). Tripped! State: \(circuitBreaker.state)")
        }
        circuitBreaker?.call = { [weak self] circuitBreaker in
            guard let strongSelf = self else { return }
            strongSelf.logInfo(info: "Perform call. State: \(circuitBreaker.state), failureCount: \(circuitBreaker.failureCount)")
            
            if strongSelf.callShouldSucceed {
                strongSelf.testService.successCall() { data, error in
                    circuitBreaker.success()
                    strongSelf.logInfo(info: "Success. State: \(circuitBreaker.state)")
                }
            } else {
                strongSelf.testService.failureCall() { data, error in
                    if circuitBreaker.failureCount < circuitBreaker.maxRetries {
                        strongSelf.logInfo(info: "Failure. Will retry. State: \(circuitBreaker.state)")
                    }
                    circuitBreaker.failure(error: error)
                }
            }
        }
    }
    
    @IBAction func didTapFailureCall(_ sender: UIButton) {
        logInfo(info: "> Start Failure Call")
        callShouldSucceed = false
        circuitBreaker?.execute()
    }
    
    @IBAction func didTapSuccessCall(_ sender: UIButton) {
        logInfo(info: "> Start Success Call")
        callShouldSucceed = true
        circuitBreaker?.execute()
    }
    
    private func logInfo(info: String) {
        
        DispatchQueue.main.async {
            var newInfo = self.infoTextView.text!
            newInfo += "\(info)\n"
            self.infoTextView.text = newInfo
        }
    }
    
}
