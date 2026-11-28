import Foundation

// MARK: - Formula values

/// The result of evaluating part of a formula: always either a number or a string. There is
/// no separate boolean type — comparisons and logic produce 1 or 0, and both read as "true"
/// unless they're exactly 0 or an empty string.
enum FormulaValue {
    case number(Double)
    case string(String)

    var isTruthy: Bool {
        switch self {
        case .number(let n): return n != 0
        case .string(let s): return !s.isEmpty
        }
    }

    var numberValue: Double {
        switch self {
        case .number(let n): return n
        case .string(let s): return Double(s) ?? 0
        }
    }

    var stringValue: String {
        switch self {
        case .string(let s): return s
        case .number(let n):
            if n.isFinite, n == n.rounded(), abs(n) < 1e15 {
                return String(Int64(n))
            }
            return String(format: "%.2f", n)
        }
    }
}

/// The values a formula can read: facts about this device and the current date, computed
/// fresh every time a formula runs. Nothing here reaches another app, the network, or
/// anything outside this one read.
struct FormulaContext {
    let now: Date
    private let variables: [String: FormulaValue]

    init(now: Date) {
        self.now = now
        var vars: [String: FormulaValue] = [:]

        let calendar = Calendar.current
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .weekday], from: now)
        vars["year"] = .number(Double(parts.year ?? 0))
        vars["month"] = .number(Double(parts.month ?? 0))
        vars["day"] = .number(Double(parts.day ?? 0))
        vars["hour"] = .number(Double(parts.hour ?? 0))
        vars["minute"] = .number(Double(parts.minute ?? 0))
        vars["weekday"] = .number(Double(parts.weekday ?? 0))

        vars["dayProgress"] = .number(DesignContent.calendarFraction(.day, now: now))
        vars["weekProgress"] = .number(DesignContent.calendarFraction(.weekOfYear, now: now))
        vars["monthProgress"] = .number(DesignContent.calendarFraction(.month, now: now))
        vars["yearProgress"] = .number(DesignContent.calendarFraction(.year, now: now))

        let battery = DeviceStats.batteryRaw()
        vars["battery"] = .number(Double(battery.percent))
        vars["charging"] = .number(battery.isCharging ? 1 : 0)
        vars["storageUsedPercent"] = .number(DeviceStats.storageUsedFraction() * 100)
        vars["storageFreeGB"] = .number(DeviceStats.storageFreeGB())
        vars["uptimeHours"] = .number(DeviceStats.uptimeSeconds() / 3600)
        vars["uptimeDays"] = .number(DeviceStats.uptimeSeconds() / 86400)
        vars["online"] = .number(DeviceStats.isOnline() ? 1 : 0)

        self.variables = vars
    }

    func variable(_ name: String) -> FormulaValue? { variables[name] }
}

// MARK: - Engine

/// A small, sandboxed expression language for "Formula" layers: template text with `{...}`
/// spans that are evaluated and substituted. A formula can only read the values in
/// `FormulaContext` and compute with them — no loops, no variables of its own, no way to
/// reach the network, the filesystem, or any other app. A mistake in a formula shows a dash;
/// it never crashes the widget.
enum FormulaEngine {
    struct FormulaError: Error, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// Renders a template, substituting every `{...}` span. Falls back to "—" on any error.
    static func render(_ template: String, now: Date) -> String {
        (try? renderThrowing(template, now: now)) ?? "—"
    }

    /// The same, surfacing the error message — used by the editor to explain a mistake.
    static func renderThrowing(_ template: String, now: Date) throws -> String {
        let context = FormulaContext(now: now)
        let chars = Array(template)
        var result = ""
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "{" {
                if i + 1 < chars.count, chars[i + 1] == "{" {
                    result.append("{")
                    i += 2
                    continue
                }
                guard let close = matchingBrace(chars, from: i) else {
                    throw FormulaError(message: "Missing a closing }")
                }
                let inner = String(chars[(i + 1)..<close])
                let value = try evaluate(inner, context: context)
                result += value.stringValue
                i = close + 1
            } else if c == "}" {
                if i + 1 < chars.count, chars[i + 1] == "}" {
                    result.append("}")
                    i += 2
                    continue
                }
                throw FormulaError(message: "Unmatched }")
            } else {
                result.append(c)
                i += 1
            }
        }
        return result
    }

    /// Evaluates one bare expression (no surrounding braces or literal text).
    static func evaluate(_ expression: String, context: FormulaContext) throws -> FormulaValue {
        var parser = FormulaParser(tokens: try FormulaLexer.tokenize(expression))
        let node = try parser.parseExpression()
        try parser.expectEnd()
        return try node.evaluate(context: context)
    }

    private static func matchingBrace(_ chars: [Character], from openIndex: Int) -> Int? {
        var depth = 0
        var i = openIndex
        while i < chars.count {
            if chars[i] == "{" { depth += 1 }
            if chars[i] == "}" {
                depth -= 1
                if depth == 0 { return i }
            }
            i += 1
        }
        return nil
    }
}

// MARK: - Lexer

enum FormulaToken: Equatable {
    case number(Double)
    case string(String)
    case identifier(String)
    case op(String)
    case comparison(String)
    case question
    case colon
    case andOp
    case orOp
    case notOp
    case end
}

enum FormulaLexer {
    static func tokenize(_ source: String) throws -> [FormulaToken] {
        var tokens: [FormulaToken] = []
        let chars = Array(source)
        var i = 0

        func peekNext() -> Character? { i + 1 < chars.count ? chars[i + 1] : nil }

        while i < chars.count {
            let c = chars[i]
            if c.isWhitespace {
                i += 1
                continue
            }
            if c.isNumber || (c == "." && (peekNext()?.isNumber ?? false)) {
                var text = ""
                while i < chars.count, chars[i].isNumber || chars[i] == "." {
                    text.append(chars[i])
                    i += 1
                }
                guard let value = Double(text) else {
                    throw FormulaEngine.FormulaError(message: "'\(text)' isn't a number")
                }
                tokens.append(.number(value))
                continue
            }
            if c == "\"" {
                i += 1
                var text = ""
                while i < chars.count, chars[i] != "\"" {
                    if chars[i] == "\\", i + 1 < chars.count {
                        i += 1
                        switch chars[i] {
                        case "n": text.append("\n")
                        case "t": text.append("\t")
                        default: text.append(chars[i])
                        }
                    } else {
                        text.append(chars[i])
                    }
                    i += 1
                }
                guard i < chars.count, chars[i] == "\"" else {
                    throw FormulaEngine.FormulaError(message: "Missing a closing \" in a formula")
                }
                i += 1
                tokens.append(.string(text))
                continue
            }
            if c.isLetter || c == "_" {
                var text = ""
                while i < chars.count, chars[i].isLetter || chars[i].isNumber || chars[i] == "_" {
                    text.append(chars[i])
                    i += 1
                }
                tokens.append(.identifier(text))
                continue
            }
            switch c {
            case "+", "-", "*", "/", "%", "(", ")", ",":
                tokens.append(.op(String(c)))
                i += 1
            case "?":
                tokens.append(.question)
                i += 1
            case ":":
                tokens.append(.colon)
                i += 1
            case "=":
                guard peekNext() == "=" else { throw FormulaEngine.FormulaError(message: "Use == to compare, not =") }
                tokens.append(.comparison("=="))
                i += 2
            case "!":
                if peekNext() == "=" {
                    tokens.append(.comparison("!="))
                    i += 2
                } else {
                    tokens.append(.notOp)
                    i += 1
                }
            case "<":
                if peekNext() == "=" {
                    tokens.append(.comparison("<="))
                    i += 2
                } else {
                    tokens.append(.comparison("<"))
                    i += 1
                }
            case ">":
                if peekNext() == "=" {
                    tokens.append(.comparison(">="))
                    i += 2
                } else {
                    tokens.append(.comparison(">"))
                    i += 1
                }
            case "&":
                guard peekNext() == "&" else { throw FormulaEngine.FormulaError(message: "Use && for \"and\"") }
                tokens.append(.andOp)
                i += 2
            case "|":
                guard peekNext() == "|" else { throw FormulaEngine.FormulaError(message: "Use || for \"or\"") }
                tokens.append(.orOp)
                i += 2
            default:
                throw FormulaEngine.FormulaError(message: "Didn't understand '\(c)' in the formula")
            }
        }
        tokens.append(.end)
        return tokens
    }
}

// MARK: - Parser

struct FormulaParser {
    let tokens: [FormulaToken]
    var index = 0
    /// Guards against a pathological formula (thousands of nested parentheses) blowing the
    /// call stack — a formula can come from a design someone else shared with you.
    var depth = 0

    private var current: FormulaToken { tokens[index] }

    private mutating func advance() {
        if index < tokens.count - 1 { index += 1 }
    }

    mutating func expectEnd() throws {
        guard current == .end else {
            throw FormulaEngine.FormulaError(message: "Extra text after the formula")
        }
    }

    mutating func parseExpression() throws -> FormulaNode {
        depth += 1
        defer { depth -= 1 }
        guard depth < 64 else {
            throw FormulaEngine.FormulaError(message: "Formula is too deeply nested")
        }
        return try parseTernary()
    }

    private mutating func parseTernary() throws -> FormulaNode {
        let condition = try parseOr()
        guard current == .question else { return condition }
        advance()
        let whenTrue = try parseExpression()
        guard current == .colon else { throw FormulaEngine.FormulaError(message: "Expected ':' in a ? : expression") }
        advance()
        let whenFalse = try parseExpression()
        return .ternary(condition, whenTrue, whenFalse)
    }

    private mutating func parseOr() throws -> FormulaNode {
        var node = try parseAnd()
        while current == .orOp {
            advance()
            node = .binary("||", node, try parseAnd())
        }
        return node
    }

    private mutating func parseAnd() throws -> FormulaNode {
        var node = try parseEquality()
        while current == .andOp {
            advance()
            node = .binary("&&", node, try parseEquality())
        }
        return node
    }

    private mutating func parseEquality() throws -> FormulaNode {
        var node = try parseComparison()
        while case .comparison(let op) = current, op == "==" || op == "!=" {
            advance()
            node = .binary(op, node, try parseComparison())
        }
        return node
    }

    private mutating func parseComparison() throws -> FormulaNode {
        var node = try parseAdditive()
        while case .comparison(let op) = current, op == "<" || op == "<=" || op == ">" || op == ">=" {
            advance()
            node = .binary(op, node, try parseAdditive())
        }
        return node
    }

    private mutating func parseAdditive() throws -> FormulaNode {
        var node = try parseMultiplicative()
        while case .op(let symbol) = current, symbol == "+" || symbol == "-" {
            advance()
            node = .binary(symbol, node, try parseMultiplicative())
        }
        return node
    }

    private mutating func parseMultiplicative() throws -> FormulaNode {
        var node = try parseUnary()
        while case .op(let symbol) = current, symbol == "*" || symbol == "/" || symbol == "%" {
            advance()
            node = .binary(symbol, node, try parseUnary())
        }
        return node
    }

    private mutating func parseUnary() throws -> FormulaNode {
        if current == .op("-") {
            advance()
            return .unary("-", try parseUnary())
        }
        if current == .notOp {
            advance()
            return .unary("!", try parseUnary())
        }
        return try parsePrimary()
    }

    private mutating func parsePrimary() throws -> FormulaNode {
        switch current {
        case .number(let n):
            advance()
            return .number(n)
        case .string(let s):
            advance()
            return .string(s)
        case .identifier(let name):
            advance()
            if current == .op("(") {
                advance()
                var args: [FormulaNode] = []
                if current != .op(")") {
                    args.append(try parseExpression())
                    while current == .op(",") {
                        advance()
                        args.append(try parseExpression())
                    }
                }
                guard current == .op(")") else { throw FormulaEngine.FormulaError(message: "Expected ')'") }
                advance()
                return .call(name, args)
            }
            return .variable(name)
        case .op("("):
            advance()
            let node = try parseExpression()
            guard current == .op(")") else { throw FormulaEngine.FormulaError(message: "Expected ')'") }
            advance()
            return node
        default:
            throw FormulaEngine.FormulaError(message: "Expected a value in the formula")
        }
    }
}

// MARK: - AST

indirect enum FormulaNode {
    case number(Double)
    case string(String)
    case variable(String)
    case call(String, [FormulaNode])
    case unary(String, FormulaNode)
    case binary(String, FormulaNode, FormulaNode)
    case ternary(FormulaNode, FormulaNode, FormulaNode)

    func evaluate(context: FormulaContext) throws -> FormulaValue {
        switch self {
        case .number(let n):
            return .number(n)
        case .string(let s):
            return .string(s)
        case .variable(let name):
            guard let value = context.variable(name) else {
                throw FormulaEngine.FormulaError(message: "Unknown value '\(name)'")
            }
            return value
        case .call(let name, let argumentNodes):
            let args = try argumentNodes.map { try $0.evaluate(context: context) }
            return try FormulaFunctions.call(name, args, context: context)
        case .unary(let op, let node):
            let value = try node.evaluate(context: context)
            switch op {
            case "-": return .number(-value.numberValue)
            case "!": return .number(value.isTruthy ? 0 : 1)
            default: throw FormulaEngine.FormulaError(message: "Unknown operator \(op)")
            }
        case .binary(let op, let lhsNode, let rhsNode):
            return try evaluateBinary(op, lhsNode, rhsNode, context: context)
        case .ternary(let conditionNode, let whenTrueNode, let whenFalseNode):
            let condition = try conditionNode.evaluate(context: context)
            return try (condition.isTruthy ? whenTrueNode : whenFalseNode).evaluate(context: context)
        }
    }

    private func evaluateBinary(
        _ op: String, _ lhsNode: FormulaNode, _ rhsNode: FormulaNode, context: FormulaContext
    ) throws -> FormulaValue {
        if op == "&&" {
            guard try lhsNode.evaluate(context: context).isTruthy else { return .number(0) }
            return .number(try rhsNode.evaluate(context: context).isTruthy ? 1 : 0)
        }
        if op == "||" {
            if try lhsNode.evaluate(context: context).isTruthy { return .number(1) }
            return .number(try rhsNode.evaluate(context: context).isTruthy ? 1 : 0)
        }
        let lhs = try lhsNode.evaluate(context: context)
        let rhs = try rhsNode.evaluate(context: context)
        switch op {
        case "+":
            if case .string = lhs { return .string(lhs.stringValue + rhs.stringValue) }
            if case .string = rhs { return .string(lhs.stringValue + rhs.stringValue) }
            return .number(lhs.numberValue + rhs.numberValue)
        case "-":
            return .number(lhs.numberValue - rhs.numberValue)
        case "*":
            return .number(lhs.numberValue * rhs.numberValue)
        case "/":
            let denominator = rhs.numberValue
            return .number(denominator == 0 ? 0 : lhs.numberValue / denominator)
        case "%":
            let denominator = rhs.numberValue
            return .number(denominator == 0 ? 0 : lhs.numberValue.truncatingRemainder(dividingBy: denominator))
        case "==":
            return .number(valuesEqual(lhs, rhs) ? 1 : 0)
        case "!=":
            return .number(valuesEqual(lhs, rhs) ? 0 : 1)
        case "<":
            return .number(lhs.numberValue < rhs.numberValue ? 1 : 0)
        case "<=":
            return .number(lhs.numberValue <= rhs.numberValue ? 1 : 0)
        case ">":
            return .number(lhs.numberValue > rhs.numberValue ? 1 : 0)
        case ">=":
            return .number(lhs.numberValue >= rhs.numberValue ? 1 : 0)
        default:
            throw FormulaEngine.FormulaError(message: "Unknown operator \(op)")
        }
    }

    private func valuesEqual(_ lhs: FormulaValue, _ rhs: FormulaValue) -> Bool {
        if case .number(let a) = lhs, case .number(let b) = rhs { return a == b }
        return lhs.stringValue == rhs.stringValue
    }
}

enum FormulaFunctions {
    static func call(_ name: String, _ args: [FormulaValue], context: FormulaContext) throws -> FormulaValue {
        func argument(_ i: Int) throws -> FormulaValue {
            guard i < args.count else {
                throw FormulaEngine.FormulaError(message: "\(name)(…) needs \(i + 1) argument(s)")
            }
            return args[i]
        }
        switch name {
        case "round": return .number(try argument(0).numberValue.rounded())
        case "floor": return .number(try argument(0).numberValue.rounded(.down))
        case "ceil": return .number(try argument(0).numberValue.rounded(.up))
        case "abs": return .number(Swift.abs(try argument(0).numberValue))
        case "min": return .number(Swift.min(try argument(0).numberValue, try argument(1).numberValue))
        case "max": return .number(Swift.max(try argument(0).numberValue, try argument(1).numberValue))
        case "percent":
            let value = Int((try argument(0).numberValue * 100).rounded())
            return .string("\(value)%")
        case "date":
            let pattern = try argument(0).stringValue
            let formatter = DateFormatter()
            formatter.dateFormat = pattern
            return .string(formatter.string(from: context.now))
        default:
            throw FormulaEngine.FormulaError(message: "Unknown function '\(name)'")
        }
    }
}
