//
//  FutureFIFO.swift
//  FutureKit
//
//  Created by Michael Gray on 3/25/18.
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
import Foundation


public struct QueuePriority: RawRepresentable {
    public typealias RawValue = UInt

    public let rawValue: RawValue


    public init?(rawValue: RawValue) {
        if (rawValue > QueuePriority.maxCustomValue) {
            return nil
        }
        self.rawValue = rawValue
    }

    public static let low: QueuePriority = QueuePriority(rawValue: 250)!
    public static let medium: QueuePriority = QueuePriority(rawValue: 500)!
    public static let high: QueuePriority = QueuePriority(rawValue: 750)!
    public static let top: QueuePriority = QueuePriority(rawValue: QueuePriority.maxCustomValue)!
    public static func custom(_ rawValue: RawValue) -> QueuePriority {
        return QueuePriority(rawValue: rawValue)!
    }

    public static let maxPriority: QueuePriority = .top
    public static let maxCustomValue: RawValue = 1000
}

extension QueuePriority: Hashable {
    public var hashValue: Int {
        return Int(bitPattern: self.rawValue)
    }
}
extension QueuePriority: Comparable {
    public static func <(lhs: QueuePriority, rhs: QueuePriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

extension QueuePriority {
    fileprivate func maxOperations(forMaxConcurrentOperationCount count: Int) -> Int {
        if self.rawValue <= QueuePriority.low.rawValue {
            return (count / 2)
        }
        if self.rawValue <= QueuePriority.low.rawValue {
            return ((count * 3) / 4)
        }
        return count
    }
}

internal protocol QueueJob {

    var priority: QueuePriority { get }
    var tag: String? { get }
    func cancel(fileLineInfo: FileLineInfo)

}
internal protocol PendingJob: QueueJob {

    func start() -> Future<Any>
}

internal struct PendingJobFuture<C:CompletionType>: PendingJob {
    let priority: QueuePriority
    let maxExecutionTime: TimeInterval
    let promise: Promise<C.T>
    let executor: Executor
    let operation: () throws -> C
    let tag: String?

    var future: Future<C.T> {
        return promise.future
    }

    init(priority: QueuePriority,
         maxExecutionTime: TimeInterval,
         executor: Executor = .primary,
         tag: String?,
         operation: @escaping () throws -> C) {

        self.priority = priority
        self.maxExecutionTime = maxExecutionTime
        self.executor = executor
        self.operation = operation
        self.promise = Promise<C.T>()
        self.tag = tag
    }

    func start() -> Future<Any> {
        if !promise.isCompleted {
            let subFuture = executor
                .execute(operation)
                .automaticallyFail(with: FutureKitError.timedOutWaitingForResponse,
                                   afterDelay: maxExecutionTime)

            promise.completeUsingFuture(subFuture)
        }
        return promise.future.mapAs(Any.self)
    }

    func cancel(fileLineInfo: FileLineInfo) {
        promise.completeWithCancel(fileLineInfo)
    }
}

internal struct PendingJobQueue {
    var dict: Atomic<[QueuePriority:[PendingJob]]> = Atomic([:])

    var count: Int {
        return dict.withValue { dict in
            return dict.values.reduce(0) { $0 + $1.count }
        }
    }

    mutating func insert(job: PendingJob) {
        dict.modify {
            if var array = $0[job.priority] {
                array.insert(job, at: 0)
                $0[job.priority] = array
            } else {
                $0[job.priority] = [job]
            }
        }
    }
    mutating func remove(priority: QueuePriority) -> [QueueJob] {
        return dict.modify { dict -> [PendingJob] in
            var jobsRemoved = [PendingJob]()
            var newDict = [QueuePriority:[PendingJob]]()
            for (queuePriority, jobs) in dict {
                if queuePriority <= priority {
                    jobsRemoved.append(contentsOf: jobs)
                } else {
                    newDict[queuePriority] = jobs
                }
            }
            dict = newDict
            return jobsRemoved
        }
    }

    mutating func popTopItemIf(testIsTrue test: (PendingJob) -> Bool) -> PendingJob? {
        return dict.modify { dict -> PendingJob? in
            while !dict.isEmpty {
                let priority = dict.keys.max()!
                let maxIndex = dict.index(forKey: priority)!

                var queue = dict[maxIndex].value
                let lastJob = queue.last
                if let job = lastJob {
                    if test(job) {
                        _ = queue.popLast()
                        if queue.isEmpty {
                            dict.remove(at: maxIndex)
                        } else {
                            dict[priority] = queue
                        }
                        return job
                    } else {
                        return nil
                    }
                } else {
                    dict.remove(at: maxIndex)
                }
            }
            return nil
        }
    }

    var isEmpty: Bool {
        return dict.withValue { $0.isEmpty }
    }
}
internal struct ExecutingJob: QueueJob, Equatable {
    let number: Int
    let priority: QueuePriority
    let token: CancellationToken
    let tag: String?


    init<T>(priority: QueuePriority, future: Future<T>, tag: String?) {
        self.number = ExecutingJob.nextJobNum()
        self.priority = priority
        self.token = future.getCancelToken()
        self.tag = tag
    }

    func cancel(fileLineInfo: FileLineInfo) {
        token.cancel(.ForceThisFutureToBeCancelledImmediately, fileLineInfo)
    }

    static func == (lhs: ExecutingJob, rhs: ExecutingJob) -> Bool {
        return lhs.number == rhs.number
    }

    private static var jobCount = Atomic<Int>(0)
    private static func nextJobNum() -> Int {
        return jobCount.modify {
            $0 += 1
            return $0
        }
    }
}

public class FutureQueue {

    /// setting to zero will 'pause' the queue.
    public var maxConcurrentOperationCount: Int = 10 {
        didSet {
            popAndRun()
        }
    }
    public var maxAllowedExecutionTime: TimeInterval = 45.0

    public var pendingCount : Int {
        return self.pendingJobs.count
    }
    public var executingCount : Int {
        return self.executingJobs.withValue { $0.count }
    }
    public var executingTags : [String?] {
        return self.executingJobs.withValue { $0.map { $0.tag } }
    }

    public var pendingTags : [QueuePriority: [String?]] {
        return self.pendingJobs.dict.withValue { dict -> [QueuePriority: [String?]] in
            return dict.mapValues { $0.map { $0.tag } }
        }
    }


    public var unfinishedOperationCount : Int {
        return self.pendingCount + self.executingCount
    }

    private var pendingJobs = PendingJobQueue()
    private var executingJobs = Atomic<[ExecutingJob]>([])

    public init() {}

    public func add<C:CompletionType>(executor: Executor = .primary,
                                      priority: QueuePriority,
                                      tag: String?,
                                      operation: @escaping () throws -> C) -> Future<C.T> {

        let job = PendingJobFuture<C>(priority: priority,
                                      maxExecutionTime: self.maxAllowedExecutionTime,
                                      executor: executor,
                                      tag: tag,
                                      operation: operation)
        pendingJobs.insert(job: job)
        popAndRun()

        return job.future
    }

    public func cancelJobs(lessThanOrEqualTo priority: QueuePriority, _ file: StaticString = #file, _ line: UInt = #line) {
        let fileLineInfo = FileLineInfo(file, line)
        var jobsToCancel = self.pendingJobs.remove(priority: priority)
        self.executingJobs.modify {
            var jobsToKeep = [ExecutingJob]()
            for job in $0 {
                if job.priority <= priority {
                    jobsToCancel.append(job)
                } else {
                    jobsToKeep.append(job)
                }
            }
            $0 = jobsToKeep
        }
        for job in jobsToCancel {
            job.cancel(fileLineInfo: fileLineInfo)
        }
    }

    public func cancelAll(_ file: StaticString = #file, _ line: UInt = #line) {
        self.cancelJobs(lessThanOrEqualTo: .maxPriority, file, line)
    }

    private func addExecutingJob(_ job: ExecutingJob) {
        executingJobs.modify {
            $0.append(job)
        }
    }

    private func removeExecutingJob(_ job: ExecutingJob) {
        executingJobs.modify {
            if let found = $0.index(of: job) {
                $0.remove(at: found)
            }
        }
        self.popAndRun()
    }
    private func popAndRun() {
        while !self.pendingJobs.isEmpty {
            let poppedJob = self.pendingJobs.popTopItemIf { job -> Bool in
                let maxJobsAllowed = job.priority
                    .maxOperations(forMaxConcurrentOperationCount: maxConcurrentOperationCount)
                return maxJobsAllowed > self.executingJobs.withValue { $0.count }
            }
            guard let job = poppedJob else {
                return
            }
            let future = job.start()
            if !future.isCompleted {
                let executingJob = ExecutingJob(priority: job.priority,
                                                future: future,
                                                tag: job.tag)

                self.addExecutingJob(executingJob)
                future.onComplete(.default) { _ in
                    self.removeExecutingJob(executingJob)
                }
            }
        }
    }
}
