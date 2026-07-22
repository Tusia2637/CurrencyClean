import Foundation

final class NetworkService {
    private enum NetworkError: LocalizedError {
        case invalidResponse
        case httpStatus(Int)
        case providerFailure(String)
        case missingCurrencies

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "Сервер вернул некорректный ответ."
            case .httpStatus(let status):
                return "Сервер вернул ошибку HTTP \(status)."
            case .providerFailure(let message):
                return "Сервис курсов сообщил об ошибке: \(message)."
            case .missingCurrencies:
                return "Сервер вернул не все необходимые валюты."
            }
        }
    }

    private struct LiveTick: Decodable {
        let mid: Double
    }

    private struct ReferenceResponse: Decodable {
        let result: String
        let rates: [String: Double]
        let errorType: String?

        enum CodingKeys: String, CodingKey {
            case result
            case rates
            case errorType = "error-type"
        }
    }

    private static let liveURL = URL(
        string: "https://biquote.io/api/latest?symbols=EURUSD&symbols=GBPUSD&symbols=USDJPY"
    )!
    private static let referenceURL = URL(string: "https://open.er-api.com/v6/latest/USD")!
    private static let referenceCacheLifetime: TimeInterval = 60 * 60

    private var referenceRatesCache: [Currency: Double]?
    private var referenceCacheExpirationDate: Date?

    func fetchRates() async throws -> ExchangeRates {
        var values = try await fetchLiveRates()
        let referenceRates = try await fetchReferenceRates()
        values.merge(referenceRates) { _, newValue in newValue }
        values[.usd] = 1

        guard Currency.allCases.allSatisfy({ values[$0] != nil }) else {
            throw NetworkError.missingCurrencies
        }
        return ExchangeRates(values: values)
    }

    private func fetchLiveRates() async throws -> [Currency: Double] {
        let data = try await loadData(from: Self.liveURL)
        let ticks = try JSONDecoder().decode([String: LiveTick].self, from: data)

        guard
            let eurUSD = ticks["EURUSD"]?.mid, eurUSD > 0,
            let gbpUSD = ticks["GBPUSD"]?.mid, gbpUSD > 0,
            let usdJPY = ticks["USDJPY"]?.mid, usdJPY > 0
        else {
            throw NetworkError.missingCurrencies
        }

        return [
            .eur: 1 / eurUSD,
            .gbp: 1 / gbpUSD,
            .jpy: usdJPY
        ]
    }

    private func fetchReferenceRates() async throws -> [Currency: Double] {
        if let referenceRatesCache,
           let expirationDate = referenceCacheExpirationDate,
           expirationDate > .now {
            return referenceRatesCache
        }

        let data = try await loadData(from: Self.referenceURL)
        let response = try JSONDecoder().decode(ReferenceResponse.self, from: data)

        guard response.result == "success" else {
            throw NetworkError.providerFailure(response.errorType ?? "unknown")
        }
        guard let rub = response.rates[Currency.rub.rawValue],
              let byn = response.rates[Currency.byn.rawValue] else {
            throw NetworkError.missingCurrencies
        }

        let rates: [Currency: Double] = [.rub: rub, .byn: byn]
        referenceRatesCache = rates
        referenceCacheExpirationDate = Date().addingTimeInterval(Self.referenceCacheLifetime)
        return rates
    }

    private func loadData(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        guard (200..<300).contains(response.statusCode) else {
            throw NetworkError.httpStatus(response.statusCode)
        }
        return data
    }
}
