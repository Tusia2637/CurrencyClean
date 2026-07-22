import SwiftUI

struct CurrencyConverterView: View {
    @StateObject private var viewModel = ConverterViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            Form {
                Section("Сумма в USD") {
                    TextField("Введите сумму", text: $viewModel.amount)
                        .keyboardType(.decimalPad)
                }

                Section("Валюта") {
                    currencyContent
                }

                Section("Результат") {
                    Text("\(viewModel.convertedAmount) \(viewModel.selectedCurrency.rawValue)")
                        .font(.title.bold())
                        .foregroundStyle(.blue)
                }

                if let errorMessage = viewModel.errorMessage {
                    errorSection(message: errorMessage)
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .navigationTitle("Global Currency")
            .task(id: scenePhase) {
                await handleScenePhase()
            }
        }
    }

    @ViewBuilder
    private var currencyContent: some View {
        if viewModel.isLoading {
            ProgressView("Загружаем актуальные курсы…")
        } else if viewModel.availableCurrencies.isEmpty {
            ContentUnavailableView(
                "Курсы недоступны",
                systemImage: "wifi.exclamationmark",
                description: Text("Проверьте соединение и попробуйте снова.")
            )
        } else {
            NavigationLink {
                CurrencySelectionView(viewModel: viewModel)
            } label: {
                LabeledContent("Валюта", value: viewModel.selectedCurrency.rawValue)
            }
        }
    }

    private func errorSection(message: String) -> some View {
        Section {
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)

            Button("Повторить") {
                Task { await viewModel.refresh() }
            }
        }
    }

    private func handleScenePhase() async {
        switch scenePhase {
        case .active:
            await viewModel.autoRefresh()
        case .background:
            await viewModel.refresh()
        case .inactive:
            break
        @unknown default:
            break
        }
    }
}

private struct CurrencySelectionView: View {
    @ObservedObject var viewModel: ConverterViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(viewModel.availableCurrencies) { currency in
            Button {
                viewModel.select(currency)
                dismiss()
            } label: {
                HStack {
                    Text(currency.rawValue)
                        .foregroundStyle(.primary)
                    Spacer()
                    if currency == viewModel.selectedCurrency {
                        Image(systemName: "checkmark")
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .navigationTitle("Выбор валюты")
        .task {
            await viewModel.refresh()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
}
