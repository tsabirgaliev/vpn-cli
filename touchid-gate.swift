// touchid-gate: shows a Touch ID prompt with the given reason.
// Exit 0 = approved, 1 = denied/failed, 64 = usage.
//
// Build:  swiftc -O touchid-gate.swift -o touchid-gate
// Sign:   codesign -f -s - -o runtime touchid-gate
//
// Policy: biometrics only. To allow fallback to the Mac login password
// (e.g. lid closed, keyboard without Touch ID), change the policy to
// .deviceOwnerAuthentication.

import Foundation
import LocalAuthentication

let reason = CommandLine.arguments.dropFirst().joined(separator: " ")
guard !reason.isEmpty else {
    FileHandle.standardError.write("usage: touchid-gate <reason>\n".data(using: .utf8)!)
    exit(64)
}

let ctx = LAContext()
let policy = LAPolicy.deviceOwnerAuthenticationWithBiometrics

var err: NSError?
guard ctx.canEvaluatePolicy(policy, error: &err) else {
    FileHandle.standardError.write("touchid-gate: \(err?.localizedDescription ?? "Touch ID unavailable")\n".data(using: .utf8)!)
    exit(1)
}

let sem = DispatchSemaphore(value: 0)
var ok = false
ctx.evaluatePolicy(policy, localizedReason: reason) { success, _ in
    ok = success
    sem.signal()
}
sem.wait()
exit(ok ? 0 : 1)
