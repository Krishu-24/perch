//
//  LockIndicator.swift
//  Perch
//
//  A lock on the closed notch while the Mac is locked, which springs open for a
//  moment when you unlock it, like the lock above an iPhone's clock. The notch stays
//  on the lock screen through SkyLight (BoringNotchSkyLightWindow), and while it's
//  locked the notch shows only the lock: no sessions, music or calendar, and it
//  doesn't open, unless you've turned on Settings → Advanced → Show notch on lock screen.
//

import SwiftUI

@MainActor
final class LockStatus: ObservableObject {
    static let shared = LockStatus()

    enum State: Equatable {
        case unlocked
        case locked
        /// Just unlocked: the lock shows open for a moment, then goes.
        case justUnlocked
    }

    /// How long the open lock stays after unlocking.
    static let openLockDuration: Duration = .milliseconds(1400)

    @Published private(set) var state: State = .unlocked
    private var settle: Task<Void, Never>?

    var isLocked: Bool { state == .locked }
    var isShowing: Bool { state != .unlocked }

    func didLock() {
        settle?.cancel()
        state = .locked
    }

    func didUnlock() {
        guard state == .locked else { return }
        state = .justUnlocked
        settle?.cancel()
        settle = Task { @MainActor [weak self] in
            try? await Task.sleep(for: LockStatus.openLockDuration)
            guard !Task.isCancelled, self?.state == .justUnlocked else { return }
            self?.state = .unlocked
        }
    }
}

/// The closed notch while locked: the lock on the left, laid out like ClaudeLiveActivity.
struct LockLiveActivity: View {
    let isLocked: Bool
    /// The closed notch's height; each side gets a square this tall, less 12.
    let notchHeight: CGFloat
    /// The black gap the physical notch covers.
    let notchWidth: CGFloat

    private var side: CGFloat { max(0, notchHeight - 12) }

    var body: some View {
        HStack {
            Image(systemName: isLocked ? "lock.fill" : "lock.open.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isLocked ? .white : TerminalColors.green)
                .contentTransition(.symbolEffect(.replace))
                .animation(.spring(response: 0.35, dampingFraction: 0.6), value: isLocked)
                .frame(width: side, height: side)
                .accessibilityLabel(isLocked ? "Locked" : "Unlocked")

            Rectangle()
                .fill(.black)
                .frame(width: notchWidth)

            // Balances the lock, so the notch grows evenly on both sides.
            Color.clear
                .frame(width: side, height: side)
        }
        .frame(height: notchHeight, alignment: .center)
    }
}
