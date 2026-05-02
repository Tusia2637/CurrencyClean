import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ConverterViewModel()
    
    var body: some View {
        NavigationView { 
            Form {
                Section(header: Text("Сумма в USD")) {
                    TextField("Введите сумму", text: $viewModel.amount)
                        .keyboardType(.decimalPad)
                }
                
                Section(header: Text("Выберите валюту")) {
                    if viewModel.isLoading {
                        ProgressView("Загрузка...")
                    } else {
                        Picker("Валюта", selection: $viewModel.selectedCurrency) {
                            ForEach(viewModel.rates.keys.sorted(), id: \.self) { currency in
                                Text(currency).tag(currency)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }
                }
                
                Section(header: Text("Результат")) {
                    Text("\(viewModel.convertedAmount) \(viewModel.selectedCurrency)")
                        .font(.title).bold()
                        .foregroundColor(.blue)
                }
            }
            .navigationTitle("Global Currency")
            .task {
                await viewModel.loadData()
            }
        }
    }
}
