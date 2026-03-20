import Foundation

enum AIReviewParser {
    static func parseMetadata(author: String, body: String) -> AIReviewMetadata? {
        guard AIReviewer.isAIReviewer(author) else { return nil }
        let reviewer = AIReviewer.allCases.first { $0.rawValue == author }
        let confidence = parseConfidence(body: body, reviewer: reviewer)
        let severity = parseSeverity(body: body, reviewer: reviewer)
        return AIReviewMetadata(reviewer: reviewer, confidence: confidence, severity: severity)
    }

    // MARK: - Confidence

    private static func parseConfidence(body: String, reviewer: AIReviewer?) -> Double? {
        switch reviewer {
        case .greptile:
            // Greptile: "Confidence Score: 4/5" or "Confidence: 3/5"
            if let match = body.range(of: #"[Cc]onfidence(?:\s+[Ss]core)?:\s*(\d+)/(\d+)"#, options: .regularExpression) {
                let text = String(body[match])
                let digits = text.filter(\.isNumber)
                if digits.count >= 2 {
                    let num = Double(String(digits.first!)) ?? 0
                    let den = Double(String(digits.last!)) ?? 5
                    return den > 0 ? num / den : nil
                }
            }
            return nil
        default:
            // Generic: look for percentage or N/M patterns
            if let match = body.range(of: #"(\d+)%\s*confidence"#, options: [.regularExpression, .caseInsensitive]) {
                let text = String(body[match])
                let digits = text.prefix(while: \.isNumber)
                if let pct = Double(digits) { return pct / 100 }
            }
            return nil
        }
    }

    // MARK: - Severity

    private static func parseSeverity(body: String, reviewer: AIReviewer?) -> String? {
        switch reviewer {
        case .coderabbit:
            // CodeRabbit: "[severity: warning]" or "**Severity:** critical"
            if let match = body.range(of: #"\[severity:\s*(\w+)\]"#, options: [.regularExpression, .caseInsensitive]) {
                let text = String(body[match])
                return text.components(separatedBy: ":").last?.trimmingCharacters(in: CharacterSet(charactersIn: " ]"))
            }
            return genericSeverity(body)
        default:
            return genericSeverity(body)
        }
    }

    private static func genericSeverity(_ body: String) -> String? {
        let lower = body.lowercased()
        if lower.contains("critical") || lower.contains("🚨") { return "critical" }
        if lower.contains("warning") || lower.contains("⚠") { return "warning" }
        if lower.contains("suggestion") || lower.contains("💡") { return "suggestion" }
        if lower.contains("nitpick") || lower.contains("nit:") || lower.contains("nit ") { return "nitpick" }
        return nil
    }
}
