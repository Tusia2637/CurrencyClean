import Foundation

class NetworkService {
    func fetchRates() async throws -> ExchangeRate {
        // Стабильный файл на GitHub с курсами валют
        let urlString = "https://githubusercontent.com"
        
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        // Декодируем чистый JSON
        return try JSONDecoder().decode(ExchangeRate.self, from: data)
    }
}
