import Combine
import Foundation

@MainActor
final class ConverterViewModel: ObservableObject {
    private static let refreshInterval: Duration = .seconds(5)

    @Published var amount = "1"
    @Published private(set) var selectedCurrency: Currency = .eur
    @Published private(set) var rates: ExchangeRates?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let networkService = NetworkService()
    private let store = RatesStore()
    private var isRefreshing = false

    init() {
        rates = store.load()
    }

    var availableCurrencies: [Currency] {
        Currency.allCases.filter { rates?.rate(for: $0) != nil }
    }

    var convertedAmount: String {
        guard
            let amount = Decimal(string: amount.replacingOccurrences(of: ",", with: ".")),
            let rate = rates?.rate(for: selectedCurrency)
        else {
            return "—"
        }

        let convertedAmount = NSDecimalNumber(decimal: amount)
            .multiplying(by: NSDecimalNumber(value: rate))
        return String(format: "%.3f", convertedAmount.doubleValue)
    }

    func select(_ currency: Currency) {
        selectedCurrency = currency
    }

    func autoRefresh() async {
        while !Task.isCancelled {
            await refresh()

            do {
                try await Task.sleep(for: Self.refreshInterval)
            } catch {
                return
            }
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }

        isRefreshing = true
        isLoading = rates == nil
        defer {
            isRefreshing = false
            isLoading = false
        }

        do {
            let latestRates = try await networkService.fetchRates()
            rates = latestRates
            store.save(latestRates)
            errorMessage = nil
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
    }
}

private struct RatesStore {
    private static let key = "latestExchangeRates"

    func load() -> ExchangeRates? {
        guard let data = UserDefaults.standard.data(forKey: Self.key) else {
            return nil
        }
        return try? JSONDecoder().decode(ExchangeRates.self, from: data)
    }

    func save(_ rates: ExchangeRates) {
        guard let data = try? JSONEncoder().encode(rates) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }
}
