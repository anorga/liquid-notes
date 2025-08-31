import Foundation
import SwiftData

/// Centralized, coalescing mutation scheduler to avoid SwiftData exclusivity violations during
/// transient UIKit / SwiftUI bridging phases (e.g. context menu teardown, animation completions).
/// All mutations scheduled within the same visual frame are batched and executed after several
/// runloop / actor yields plus a short delay, ensuring any in-flight observation passes complete.
@MainActor
final class ModelMutationScheduler {
    static let shared = ModelMutationScheduler()
    private init() {}

    private var pending: [() -> Void] = []
    private var scheduledFlush = false

    /// Schedule a mutation safely. Multiple calls in the same frame are coalesced.
    /// The execution strategy:
    /// 1. Collect blocks during the current frame.
    /// 2. Yield the MainActor twice (lets SwiftUI finish the update / context menu callbacks).
    /// 3. Dispatch again after a small delay (default ~120ms) to ensure UIKit animations / teardown complete.
    /// Adjust delay via parameter if needed.
    func schedule(after delay: TimeInterval = 0.12, _ block: @escaping @MainActor () -> Void) {
        pending.append(block)
        guard !scheduledFlush else { return }
        scheduledFlush = true
        Task { @MainActor [weak self] in
            // Yield a couple times to let current transaction settle
            await Task.yield()
            await Task.yield()
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self else { return }
                let work = self.pending
                self.pending.removeAll()
                self.scheduledFlush = false
                for job in work { job() }
            }
        }
    }
}
