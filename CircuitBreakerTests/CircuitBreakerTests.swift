import XCTest
@testable import CircuitBreaker

class CircuitBreakerTests: XCTestCase {
    
    private var testService: TestService!
    private var circuitBreaker: CircuitBreaker!
    
    override func setUp() {
        super.setUp()
        
        testService = TestService()
    }
    
    override func tearDown() {
        circuitBreaker.reset()
        circuitBreaker.didTrip = nil
        circuitBreaker.call = nil
        
        super.tearDown()
    }
    
    func testSuccess() {
        let exp = expectation(description: "Successful call")
        
        circuitBreaker = CircuitBreaker()
        circuitBreaker.call = { [weak self] circuitBreaker in
            self?.testService.successCall { data, error in
                XCTAssertNotNil(data)
                XCTAssertNil(error)
                circuitBreaker.success()
                exp.fulfill()
            }
        }
        circuitBreaker.execute()
        
        waitForExpectations(timeout: 10) { _ in }
    }
    
    func testTimeout() {
        let exp = expectation(description: "Timed out call")
        
        circuitBreaker = CircuitBreaker(timeout: 3.0)
        circuitBreaker.call = { [weak self] circuitBreaker in
            switch circuitBreaker.failureCount {
            case 0:
                self?.testService?.delayedCall(delayInSeconds: 5) { _,_  in }
            default:
                self?.testService?.successCall { data, error in
                    circuitBreaker.success()
                    exp.fulfill()
                }
            }
        }
        circuitBreaker.execute()
        
        waitForExpectations(timeout: 15) { _ in }
    }
    
    func testFailure() {
        let exp = expectation(description: "Failure call")
        
        circuitBreaker = CircuitBreaker(timeout: 10.0, maxRetries: 1)
        circuitBreaker.call = { [weak self] circuitBreaker in
            switch circuitBreaker.failureCount {
            case 0:
                self?.testService?.failureCall { data, error in
                    XCTAssertNil(data)
                    XCTAssertNotNil(error)
                    circuitBreaker.failure()
                }
            default:
                self?.testService?.successCall { data, error in
                    circuitBreaker.success()
                    exp.fulfill()
                }
            }
        }
        circuitBreaker.execute()
        
        waitForExpectations(timeout: 12) { _ in }
    }
    
    func testTripping() {
        let exp = expectation(description: "Tripped call")
        
        circuitBreaker = CircuitBreaker(
            timeout: 10.0,
            maxRetries: 2,
            timeBetweenRetries: 1.0,
            exponentialBackoff: false,
            resetTimeout: 2.0
        )
        
        circuitBreaker.didTrip = { circuitBreaker, error in
            XCTAssertTrue(circuitBreaker.state == .Open)
            XCTAssertTrue(circuitBreaker.failureCount == circuitBreaker.maxRetries + 1)
            XCTAssertTrue((error! as NSError).code == 404)
            circuitBreaker.reset()
            exp.fulfill()
        }
        circuitBreaker.call = { [weak self] circuitBreaker in
            self?.testService.failureCall { data, error in
                circuitBreaker.failure(error: NSError(domain: "TestService", code: 404, userInfo: nil))
            }
        }
        circuitBreaker.execute()
        
        waitForExpectations(timeout: 100) { error in
            print(error)
        }
    }
    
    func testReset() {
        let exp = expectation(description: "Reset call")
        
        circuitBreaker = CircuitBreaker(
            timeout: 5.0,
            maxRetries: 1,
            timeBetweenRetries: 1.0,
            exponentialBackoff: false,
            resetTimeout: 2.0
        )
        circuitBreaker.call = { [weak self] circuitBreaker in
            if circuitBreaker.state == .HalfOpen {
                self?.testService?.successCall { data, error in
                    circuitBreaker.success()
                    XCTAssertTrue(circuitBreaker.state == .Closed)
                    exp.fulfill()
                }
                return
            }
            
            self?.testService.failureCall { data, error in
                circuitBreaker.failure()
            }
        }
        circuitBreaker.execute()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            self.circuitBreaker.execute()
        }
        
        waitForExpectations(timeout: 12) { _ in }
    }
    
}


