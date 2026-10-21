// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 CloudCoder Limited

import Foundation
import IOKit

/// Minimal AppleSMC client. Reading needs no privileges; writing (fan control) needs root.
public final class SMC {
    private struct Version { var major: UInt8 = 0, minor: UInt8 = 0, build: UInt8 = 0, reserved: UInt8 = 0, release: UInt16 = 0 }
    private struct LimitData { var version: UInt16 = 0, length: UInt16 = 0, cpuPLimit: UInt32 = 0, gpuPLimit: UInt32 = 0, memPLimit: UInt32 = 0 }
    // Explicit tail padding: Swift packs nested structs by size, C by stride (12 bytes).
    private struct KeyInfo { var dataSize: UInt32 = 0, dataType: UInt32 = 0, dataAttributes: UInt8 = 0, pad: (UInt8, UInt8, UInt8) = (0, 0, 0) }
    private typealias Bytes32 = (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                                 UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                                 UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                                 UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)
    private struct ParamStruct {
        var key: UInt32 = 0
        var vers = Version()
        var pLimitData = LimitData()
        var keyInfo = KeyInfo()
        var result: UInt8 = 0
        var status: UInt8 = 0
        var data8: UInt8 = 0
        var data32: UInt32 = 0
        var bytes: Bytes32 = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                              0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    }

    private static let kernelIndex: UInt32 = 2
    private static let cmdReadBytes: UInt8 = 5
    private static let cmdWriteBytes: UInt8 = 6
    private static let cmdReadIndex: UInt8 = 8
    private static let cmdReadKeyInfo: UInt8 = 9

    public static let shared = SMC()
    private var conn: io_connect_t = 0
    private let lock = NSLock()
    private var infoCache: [UInt32: KeyInfo] = [:]
    var temperatureKeys: [String]?

    private init() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return }
        IOServiceOpen(service, mach_task_self_, 0, &conn)
        IOObjectRelease(service)
    }

    deinit { if conn != 0 { IOServiceClose(conn) } }

    private static func fourCC(_ s: String) -> UInt32 {
        s.utf8.reduce(0) { ($0 << 8) | UInt32($1) }
    }

    private func call(_ input: inout ParamStruct) -> ParamStruct? {
        var output = ParamStruct()
        var outSize = MemoryLayout<ParamStruct>.stride
        let kr = IOConnectCallStructMethod(conn, Self.kernelIndex, &input, MemoryLayout<ParamStruct>.stride, &output, &outSize)
        return (kr == kIOReturnSuccess && output.result == 0) ? output : nil
    }

    private static func typeName(_ t: UInt32) -> String {
        String(bytes: [UInt8(t >> 24 & 0xff), UInt8(t >> 16 & 0xff), UInt8(t >> 8 & 0xff), UInt8(t & 0xff)], encoding: .ascii) ?? "????"
    }

    /// Caller holds `lock`.
    private func keyInfo(_ code: UInt32) -> KeyInfo? {
        if let info = infoCache[code] { return info }
        var input = ParamStruct()
        input.key = code
        input.data8 = Self.cmdReadKeyInfo
        guard let out = call(&input) else { return nil }
        infoCache[code] = out.keyInfo
        return out.keyInfo
    }

    /// Data type of a key, e.g. "flt " or "ui8 ".
    public func type(of key: String) -> String? {
        lock.lock(); defer { lock.unlock() }
        return keyInfo(Self.fourCC(key)).map { Self.typeName($0.dataType) }
    }

    /// All SMC key names (a few hundred on Intel Macs).
    public func allKeys() -> [String] {
        let count = Int(value("#KEY") ?? 0)
        lock.lock(); defer { lock.unlock() }
        var keys: [String] = []
        for i in 0..<count {
            var input = ParamStruct()
            input.data8 = Self.cmdReadIndex
            input.data32 = UInt32(i)
            if let out = call(&input) { keys.append(Self.typeName(out.key)) }
        }
        return keys
    }

    /// Raw bytes and 4-char type of an SMC key.
    public func read(_ key: String) -> (type: String, bytes: [UInt8])? {
        guard conn != 0 else { return nil }
        lock.lock(); defer { lock.unlock() }
        guard let keyInfo = keyInfo(Self.fourCC(key)), keyInfo.dataSize > 0 else { return nil }
        let code = Self.fourCC(key)
        var input = ParamStruct()
        input.key = code
        input.keyInfo.dataSize = keyInfo.dataSize
        input.data8 = Self.cmdReadBytes
        guard var out = call(&input) else { return nil }
        let bytes = withUnsafeBytes(of: &out.bytes) { Array($0.prefix(Int(keyInfo.dataSize))) }
        return (Self.typeName(keyInfo.dataType), bytes)
    }

    /// Write raw bytes to a key. Needs root. Returns false on failure.
    @discardableResult
    public func write(_ key: String, _ bytes: [UInt8]) -> Bool {
        guard conn != 0 else { return false }
        lock.lock(); defer { lock.unlock() }
        let code = Self.fourCC(key)
        guard let info = keyInfo(code), Int(info.dataSize) == bytes.count, bytes.count <= 32 else { return false }
        var input = ParamStruct()
        input.key = code
        input.keyInfo.dataSize = info.dataSize
        input.data8 = Self.cmdWriteBytes
        withUnsafeMutableBytes(of: &input.bytes) { buf in
            for (i, b) in bytes.enumerated() { buf[i] = b }
        }
        return call(&input) != nil
    }

    /// Write a number, encoded in the key's own SMC type.
    @discardableResult
    public func write(_ key: String, value: Double) -> Bool {
        guard let t = type(of: key) else { return false }
        let bytes: [UInt8]
        switch t {
        case "flt ":
            let bits = Float(value).bitPattern
            bytes = [UInt8(bits & 0xff), UInt8(bits >> 8 & 0xff), UInt8(bits >> 16 & 0xff), UInt8(bits >> 24 & 0xff)]
        case "fpe2":
            let v = UInt16(max(0, min(16383, value * 4)))
            bytes = [UInt8(v >> 8), UInt8(v & 0xff)]
        case "ui8 ", "flag":
            bytes = [UInt8(max(0, min(255, value)))]
        case "ui16":
            let v = UInt16(max(0, min(65535, value)))
            bytes = [UInt8(v >> 8), UInt8(v & 0xff)]
        default:
            return false
        }
        return write(key, bytes)
    }

    /// Numeric value of a key, decoding the common SMC types.
    public func value(_ key: String) -> Double? {
        guard let (type, b) = read(key) else { return nil }
        switch type {
        case "sp78" where b.count >= 2:
            return Double(Int16(bitPattern: UInt16(b[0]) << 8 | UInt16(b[1]))) / 256.0
        case "fpe2" where b.count >= 2:
            return Double(UInt16(b[0]) << 8 | UInt16(b[1])) / 4.0
        case "flt " where b.count >= 4:
            return Double(Float(bitPattern: UInt32(b[0]) | UInt32(b[1]) << 8 | UInt32(b[2]) << 16 | UInt32(b[3]) << 24))
        case "ui8 " where b.count >= 1, "flag" where b.count >= 1:
            return Double(b[0])
        case "ui16" where b.count >= 2:
            return Double(UInt16(b[0]) << 8 | UInt16(b[1]))
        case "ui32" where b.count >= 4:
            return Double(UInt32(b[0]) << 24 | UInt32(b[1]) << 16 | UInt32(b[2]) << 8 | UInt32(b[3]))
        default:
            return nil
        }
    }

    // CPU die / PECI / proximity, in order of preference.
    private static let cpuTempKeys = ["TCXC", "TC0D", "TC0E", "TC0F", "TC0P", "TC0H"]
    private var cpuTempKey: String?

    public func cpuTemperature() -> Double? {
        if let key = cpuTempKey { return value(key) }
        for key in Self.cpuTempKeys {
            if let v = value(key), v > 0, v < 130 {
                cpuTempKey = key
                return v
            }
        }
        return nil
    }

    public func fanSpeeds() -> [Double] {
        let count = Int(value("FNum") ?? 0)
        return (0..<count).compactMap { value("F\($0)Ac") }
    }
}
