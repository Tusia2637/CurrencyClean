enum Currency: String, CaseIterable, Codable, Identifiable, Sendable {
    case usd = "USD"
    case eur = "EUR"
    case gbp = "GBP"
    case jpy = "JPY"
    case rub = "RUB"
    case byn = "BYN"

    var id: Self { self }
}

struct ExchangeRates: Codable, Equatable, Sendable {
    let values: [Currency: Double]

    func rate(for currency: Currency) -> Double? {
        values[currency]
    }
}
