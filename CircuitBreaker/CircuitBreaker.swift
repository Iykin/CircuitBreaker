// MIT License: https://opensource.org/licenses/MIT
// Author: https://github.com/fe9lix/CircuitBreaker

import Foundation

public class CircuitBreaker {
    
    public enum State {
        case closed
        case open
        case halfOpen
    }
    
    public let timeout: TimeInterval
    public let maxRetries: Int
    public let timeBetweenRetries: TimeInterval
    public let exponentialBackoff: Bool
    public let resetTimeout: TimeInterval
    public var call: ((CircuitBreaker) -> Void)?
    public var didTrip: ((CircuitBreaker, Error?) -> Void)?
    public private(set) var failureCount = 0
    
    public var state: State {
        if let lastFailureTime = lastFailureTime, (failureCount > maxRetries) &&
                (Date().timeIntervalSince1970 - lastFailureTime) > resetTimeout {
                    return .halfOpen
        }
        
        if failureCount > maxRetries {
            return .open
        }
        
        return .closed
    }
    
    private var lastError: Error?
    private var lastFailureTime: TimeInterval?
    private var timer: Timer?
    
    public init(
        timeout: TimeInterval = 10,
        maxRetries: Int = 2,
        timeBetweenRetries: TimeInterval = 2,
        exponentialBackoff: Bool = true,
        resetTimeout: TimeInterval = 10) {
            self.timeout = timeout
            self.maxRetries = maxRetries
            self.timeBetweenRetries = timeBetweenRetries
            self.exponentialBackoff = exponentialBackoff
            self.resetTimeout = resetTimeout
    }
    
    // MARK: - Public API
    
    public func execute() {
        timer?.invalidate()
        
        switch state {
        case .closed, .halfOpen:
            doCall()
        case .open:
            trip()
        }
    }
    
    public func success() {
        reset()
    }
    
    public func failure(error: Error? = nil) {
        timer?.invalidate()
        lastError = error
        lastFailureTime = Date().timeIntervalSince1970
        failureCount += 1
        
        switch state {
        case .closed, .halfOpen:
            retryAfterDelay()
        case .open:
            trip()
        }
    }
    
    public func reset() {
        timer?.invalidate()
        failureCount = 0
        lastFailureTime = nil
        lastError = nil
    }
    
    // MARK: - Call & Timeout
    
    private func doCall() {
        call?(self)
        startTimer(delay: timeout, selector: #selector(CircuitBreaker.didTimeout(_:)))
    }
    
    @objc private func didTimeout(_ timer: Timer) {
        failure()
    }
    
    // MARK: - Retry
    
    private func retryAfterDelay() {
        let delay = exponentialBackoff ? pow(timeBetweenRetries, Double(failureCount)) : timeBetweenRetries
        startTimer(delay: delay, selector: #selector(CircuitBreaker.shouldRetry(_:)))
    }
    
    @objc private func shouldRetry(_ timer: Timer) {
        doCall()
    }
    
    // MARK: - Trip
    
    private func trip() {
        didTrip?(self, lastError)
    }
    
    // MARK: - Timer
    
    private func startTimer(delay: TimeInterval, selector: Selector) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(
            timeInterval: delay,
            target: self,
            selector: selector,
            userInfo: nil,
            repeats: false
        )
    }
    
}
