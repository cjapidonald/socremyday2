import SwiftUI

extension DeedCard {
    func accessibilityLabel(lastAmount: Double?, unit: String) -> String {
        let polarityDescription = polarity == .positive ? "Positive" : "Negative"
        let lastAmountDescription: String
        if let lastAmount {
            let amountString = Int(lastAmount)
            let unitPart = unit.isEmpty ? "" : " \(unit)"
            lastAmountDescription = ", last amount \(amountString)\(unitPart)"
        } else {
            lastAmountDescription = ""
        }
        return "\(emoji) \(name), \(polarityDescription)\(lastAmountDescription). Double tap to log. Long-press for custom amount."
    }
}
