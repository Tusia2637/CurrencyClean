import Foundation
import Combine

@MainActor
class ConverterViewModel: ObservableObject {
    @Published var rates: [String: Double] = [:]
    @Published var amount: String = "1"
    @Published var selectedCurrency = "EUR"
    @Published var isLoading = false
    
    private let service = NetworkService()
    
    func loadData() async {
        isLoading = true
        do {
            let data = try await service.fetchRates()
            self.rates = data.rates
        } catch {
            print("Ошибка загрузки: \(error)")
            // Заглушка на случай, если даже GitHub не ответит
            self.rates = ["USD": 1.0, "EUR": 0.92, "RUB": 91.5, "GBP": 0.79]
        }
        isLoading = false
    }
    
    var convertedAmount: String {
        guard let rate = rates[selectedCurrency],
              let value = Double(amount.replacingOccurrences(of: ",", with: "."))
        else { return "0.00" }
        return String(format: "%.2f", value * rate)
    }
}
