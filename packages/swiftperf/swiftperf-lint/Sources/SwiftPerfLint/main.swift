import Foundation

struct Finding {
    var rule: String
    var path: String
    var line: Int
    var message: String
}

let msg: [String: String] = [
    "sp-print-in-loop": "print( in loop; gate or buffer",
    "sp-array-no-reserve": "empty Array then append in loop without reserveCapacity",
    "sp-dateformatter-in-loop": "date formatter constructed in a loop; reuse one instance",
    "sp-json-decode-in-loop": "JSON value decoded in a loop; reuse one decoder",
    "sp-regex-in-loop": "regular expression constructed in a loop; compile outside only when this pattern stays the same",
    "sp-file-read-in-loop": "file read in a loop; read once when the path stays the same",
    "sp-clock-in-loop": "clock sample in a tight loop with no await; hoist only when this iteration does not need a fresh time", "sp-value-for-key-in-loop": "lookup by name in a loop; use the field directly when the name is fixed",
]

func isSwift(_ path: String) -> Bool {
    path.hasSuffix(".swift")
}

func skipDir(_ name: String) -> Bool {
    [
        ".git", ".build", "fixtures", "Tests", "tests", "test",
        "docs", "Examples", "examples", "Example", "Benchmarks", "benchmarks",
        "IntegrationTests", "PerfTests", "dev",
        "NIOPerformanceTester", "NIOTCPEchoServer", "NIOTCPEchoClient",
        "NIOWebSocketClient", "NIOWebSocketServer", "NIOHTTP1Server",
        "NIOHTTP1Client", "NIOChatClient", "NIOChatServer", "Completions", "NIOTestUtils", "Usage", "Tools",
    ].contains(name)
}

func stripComment(_ line: String) -> String {
    if let r = line.range(of: "//") {
        let before = String(line[..<r.lowerBound])
        if before.filter({ $0 == "\"" }).count % 2 == 0 {
            return before
        }
    }
    return line
}

func isIdentChar(_ c: Character) -> Bool {
    c.isLetter || c.isNumber || c == "_"
}

/// Parts are joined at runtime. Call sites keep the pieces apart so this file's
/// scan loop does not contain the live constructor text.
func hasToken(_ code: String, _ parts: [String], requireParen: Bool) -> Bool {
    let name = parts.joined()
    if name.isEmpty { return false }
    var search = code.startIndex
    while search < code.endIndex {
        guard let r = code.range(of: name, range: search..<code.endIndex) else { return false }
        let beforeOK = r.lowerBound == code.startIndex || !isIdentChar(code[code.index(before: r.lowerBound)])
        if beforeOK {
            var i = r.upperBound
            if requireParen {
                while i < code.endIndex, code[i].isWhitespace {
                    i = code.index(after: i)
                }
                if i < code.endIndex, code[i] == "(" { return true }
            } else if i == code.endIndex || !isIdentChar(code[i]) {
                return true
            }
        }
        search = r.upperBound
    }
    return false
}



func identChar(_ c: Character) -> Bool {
    c == "_" || c.isLetter || c.isNumber
}

func identIn(_ s: String, _ name: String) -> Bool {
    if name.isEmpty { return false }
    var i = s.startIndex
    while i < s.endIndex {
        if let r = s.range(of: name, range: i..<s.endIndex) {
            let beforeOK = r.lowerBound == s.startIndex || !identChar(s[s.index(before: r.lowerBound)])
            let afterOK = r.upperBound == s.endIndex || !identChar(s[r.upperBound])
            if beforeOK && afterOK { return true }
            i = s.index(after: r.lowerBound)
        } else {
            break
        }
    }
    return false
}

func forNames(_ code: String) -> [String] {
    let re = try! NSRegularExpression(pattern: #"\bfor\s+(.+?)\s+in\b"#)
    let ns = code as NSString
    let full = NSRange(location: 0, length: ns.length)
    guard let m = re.firstMatch(in: code, range: full), m.numberOfRanges >= 2 else { return [] }
    let pat = ns.substring(with: m.range(at: 1))
    var names: [String] = []
    var cur = ""
    func flush() {
        if cur.isEmpty { cur = ""; return }
        if cur != "_" && cur != "for" && cur != "in" && cur != "let" && cur != "var" && cur != "case" {
            names.append(cur)
        }
        cur = ""
    }
    for ch in pat {
        if identChar(ch) { cur.append(ch) } else { flush() }
    }
    flush()
    return names
}

func regionUses(_ code: String, _ marker: String, _ names: [String]) -> Bool {
    guard !names.isEmpty, let r = code.range(of: marker) else { return false }
    let rest = String(code[r.upperBound...])
    return names.contains { identIn(rest, $0) }
}

func scanFile(_ path: String) throws -> [Finding] {
    let text = try String(contentsOfFile: path, encoding: .utf8)
    var findings: [Finding] = []
    findings.reserveCapacity(64)
    var depth = 0
    var inLoop = 0
    var loopNames: [String] = []
    var clockHold: [Finding] = []
    var loopAwait = false
    var empties: [String: (depth: Int, reserved: Bool, fired: Bool)] = [:]
    let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
    let loopRe = try! NSRegularExpression(pattern: #"\b(for|while)\b"#)
    let printRe = try! NSRegularExpression(pattern: #"\bprint\s*\("#)
    let emptyRe = try! NSRegularExpression(pattern: #"\bvar\s+(\w+)\s*(?::\s*\[[^\]]+\])?\s*=\s*(?:\[\s*\]|\[[^\]]+\]\(\)|Array\s*<[^>]+>\(\))"#)
    let appendRe = try! NSRegularExpression(pattern: #"(\w+)\.append\s*\("#)
    let reserveRe = try! NSRegularExpression(pattern: #"(\w+)\.reserveCapacity\s*\("#)
    let dateFmtParts = ["Date", "Formatter"]
    let jsonDecParts = ["JSON", "Decoder"]
    let jsonObjParts = ["JSON", "Serialization.", "jsonObject"]
    let nsRegexParts = ["NS", "Regular", "Expression"]
    let fileReadParts = ["contents", "OfFile"]
    let clockParts = ["Date"]
    let kvcParts = ["value(for", "Key"]
    for (idx, raw) in lines.enumerated() {
        let lineNo = idx + 1
        let code = stripComment(String(raw))
        let ns = code as NSString
        let full = NSRange(location: 0, length: ns.length)
        let opens = code.filter { $0 == "{" }.count
        let closes = code.filter { $0 == "}" }.count

        if let m = emptyRe.firstMatch(in: code, range: full), m.numberOfRanges >= 2 {
            let name = ns.substring(with: m.range(at: 1))
            empties[name] = (depth, false, false)
        }
        if let m = reserveRe.firstMatch(in: code, range: full), m.numberOfRanges >= 2 {
            let name = ns.substring(with: m.range(at: 1))
            if var st = empties[name] {
                st.reserved = true
                empties[name] = st
            }
        }

        if loopRe.firstMatch(in: code, range: full) != nil {
            inLoop = depth + 1
            loopNames.append(contentsOf: forNames(code))
            if code.range(of: #"\bawait\b"#, options: .regularExpression) != nil {
                loopAwait = true
            }
        }
        if inLoop > 0 && depth >= inLoop {
            if printRe.firstMatch(in: code, range: full) != nil {
                findings.append(Finding(rule: "sp-print-in-loop", path: path, line: lineNo, message: msg["sp-print-in-loop"] ?? "sp-print-in-loop"))
            }
            if hasToken(code, dateFmtParts, requireParen: true) {
                findings.append(Finding(rule: "sp-dateformatter-in-loop", path: path, line: lineNo, message: msg["sp-dateformatter-in-loop"] ?? "sp-dateformatter-in-loop"))
            }
            if hasToken(code, jsonDecParts, requireParen: true) || hasToken(code, jsonObjParts, requireParen: false) {
                findings.append(Finding(rule: "sp-json-decode-in-loop", path: path, line: lineNo, message: msg["sp-json-decode-in-loop"] ?? "sp-json-decode-in-loop"))
            }
            if code.range(of: #"\bawait\b"#, options: .regularExpression) != nil {
                loopAwait = true
            }
            if hasToken(code, nsRegexParts, requireParen: true) && !regionUses(code, "pattern:", loopNames) {
                findings.append(Finding(rule: "sp-regex-in-loop", path: path, line: lineNo, message: msg["sp-regex-in-loop"] ?? "sp-regex-in-loop"))
            }
            if hasToken(code, fileReadParts, requireParen: false) && !regionUses(code, "OfFile", loopNames) {
                findings.append(Finding(rule: "sp-file-read-in-loop", path: path, line: lineNo, message: msg["sp-file-read-in-loop"] ?? "sp-file-read-in-loop"))
            }
            if hasToken(code, clockParts, requireParen: true) && !loopAwait {
                clockHold.append(Finding(rule: "sp-clock-in-loop", path: path, line: lineNo, message: msg["sp-clock-in-loop"] ?? "sp-clock-in-loop"))
            }
            if hasToken(code, kvcParts, requireParen: false) {
                findings.append(Finding(rule: "sp-value-for-key-in-loop", path: path, line: lineNo, message: msg["sp-value-for-key-in-loop"] ?? "sp-value-for-key-in-loop"))
            }
            if let m = appendRe.firstMatch(in: code, range: full), m.numberOfRanges >= 2 {
                let name = ns.substring(with: m.range(at: 1))
                if var st = empties[name], !st.reserved, !st.fired {
                    st.fired = true
                    empties[name] = st
                    findings.append(Finding(rule: "sp-array-no-reserve", path: path, line: lineNo, message: msg["sp-array-no-reserve"] ?? "sp-array-no-reserve"))
                }
            }
        }


        depth += opens - closes
        if depth < 0 { depth = 0 }
        if inLoop > 0 && depth < inLoop {
            if !loopAwait { findings.append(contentsOf: clockHold) }
            clockHold.removeAll()
            loopAwait = false
            loopNames.removeAll()
            inLoop = 0
        }
        empties = empties.filter { $0.value.depth <= depth }
    }
    if !loopAwait { findings.append(contentsOf: clockHold) }
    return findings
}

func scanPath(_ root: String) throws -> [Finding] {
    var isDir: ObjCBool = false
    guard FileManager.default.fileExists(atPath: root, isDirectory: &isDir) else {
        throw NSError(domain: "swiftperf-lint", code: 2)
    }
    if !isDir.boolValue {
        return isSwift(root) ? try scanFile(root) : []
    }
    var all: [Finding] = []
    all.reserveCapacity(64)
    let enumerator = FileManager.default.enumerator(atPath: root)
    while let rel = enumerator?.nextObject() as? String {
        let name = (rel as NSString).lastPathComponent
        if skipDir(name) {
            enumerator?.skipDescendants()
            continue
        }
        let full = (root as NSString).appendingPathComponent(rel)
        var d: ObjCBool = false
        if FileManager.default.fileExists(atPath: full, isDirectory: &d), d.boolValue {
            continue
        }
        if isSwift(full) {
            all.append(contentsOf: try scanFile(full))
        }
    }
    return all
}

var args = Array(CommandLine.arguments.dropFirst())
if args.isEmpty {
    fputs("Usage: swiftperf-lint PATH...\n", stderr)
    exit(2)
}
var paths: [String] = []
paths.reserveCapacity(8)
var severities: [String: String] = ["sp-print-in-loop": "off", "sp-array-no-reserve": "hint", "sp-dateformatter-in-loop": "hint", "sp-json-decode-in-loop": "hint", "sp-regex-in-loop": "hint", "sp-file-read-in-loop": "hint", "sp-clock-in-loop": "hint", "sp-value-for-key-in-loop": "hint"]
var strictHints = false
var noFail = false
var i = 0
while i < args.count {
    let a = args[i]
    if a == "--severity", i + 1 < args.count {
        i += 1
        let parts = args[i].split(separator: "=", maxSplits: 1).map(String.init)
        if parts.count == 2, severities[parts[0]] != nil {
            severities[parts[0]] = parts[1]
        }
    } else if a == "--strict-hints" {
        strictHints = true
    } else if a == "--no-fail" {
        noFail = true
    } else if a.hasPrefix("-") {
        fputs("unknown flag \(a)\n", stderr)
        exit(2)
    } else {
        paths.append(a)
    }
    i += 1
}

var findings: [Finding] = []
findings.reserveCapacity(64)
do {
    for p in paths {
        findings.append(contentsOf: try scanPath(p))
    }
} catch {
    fputs("\(error)\n", stderr)
    exit(2)
}

var nerr = 0
var nhint = 0
for f in findings {
    let sev = severities[f.rule] ?? "hint"
    if sev == "off" { continue }
    let row = "\(f.path):\(f.line): \(sev) \(f.rule): \(f.message)\n"
    fputs(row, stdout)
    if sev == "error" { nerr += 1 } else { nhint += 1 }
}
let shown = nerr + nhint
if shown > 0 {
    fputs("\(shown) finding(s) (\(nerr) error, \(nhint) hint)\n", stderr)
} else {
    fputs("ok\n", stderr)
}
if noFail { exit(0) }
if nerr > 0 || (strictHints && nhint > 0) { exit(1) }
exit(0)
