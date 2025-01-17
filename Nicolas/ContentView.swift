import SwiftUI

struct Transaction: Identifiable {
    let id = UUID()
    let date: Date
    var type: TransactionType
    var description: String
    var amount: Double
    
    enum TransactionType: String, CaseIterable {
        case income = "Income"
        case expense = "Expense"
        case pending = "Pending"
        
        var color: Color {
            switch self {
            case .income: return .green
            case .expense: return .red
            case .pending: return .orange
            }
        }
        
        var icon: String {
            switch self {
            case .income: return "arrow.down.circle.fill"
            case .expense: return "arrow.up.circle.fill"
            case .pending: return "clock.fill"
            }
        }
    }
}

struct ContentView: View {
    @State private var balance: Double = 0.0
    @State private var transactions: [Transaction] = []
    @State private var isAddingTransaction = false
    @State private var showingChart = false
    @State private var editingTransaction: Transaction?
    
    // Form fields
    @State private var amount = ""
    @State private var description = ""
    @State private var selectedDate = Date()
    @State private var transactionType = Transaction.TransactionType.income
    @State private var visibleTransactions = 15 // Número inicial de transacciones visibles

    
    var body: some View {
        NavigationView {
            ZStack {
                Color.white.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // Top Safe Area Color
                        Color.white.ignoresSafeArea()
                            .frame(height: 0)

                        // Balance Card
                        BalanceCard(balance: balance)
                            .padding(.horizontal)
                            .padding(.top, 10)

                        // Action Buttons
                        ActionButtonsView(
                            isAddingTransaction: $isAddingTransaction,
                            showingChart: $showingChart
                        )
                        .padding(.horizontal)
                        .padding(.vertical, 10)

                        // Transactions List
                        VStack(alignment: .leading) {
                            Text("Recent Transactions")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                                .padding(.top, 10)

                            LazyVStack(spacing: 9) {
                                ForEach(0..<min(visibleTransactions, transactions.count), id: \.self) { index in
                                    TransactionRow(transaction: transactions[index])
                                        .padding(.horizontal)
                                        .contextMenu {
                                            Button(action: {
                                                editingTransaction = transactions[index]
                                                amount = String(format: "%.2f", transactions[index].amount)
                                                description = transactions[index].description
                                                selectedDate = transactions[index].date
                                                transactionType = transactions[index].type
                                                isAddingTransaction = true
                                            }) {
                                                Label("Edit", systemImage: "pencil")
                                            }

                                            Button(action: {
                                                deleteTransaction(at: index)
                                            }) {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                            .padding(.vertical, 8)

                            if visibleTransactions < transactions.count {
                                Button(action: {
                                    visibleTransactions += 10 // Carga 10 transacciones más
                                }) {
                                    Text("Ver más")
                                        .font(.body)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.blue)
                                        .padding(.vertical, 10)
                                }
                                .frame(maxWidth: .infinity)
                                .background(Color.white)
                                .cornerRadius(10)
                                .padding(.horizontal)
                            }
                        }
                    }
                    .background(Color.white.opacity(0.95))

                    // Bottom Safe Area Color
                    Color.white.ignoresSafeArea()
                        .frame(height: 0)
                }
            }
            .sheet(isPresented: $isAddingTransaction) {
                AddTransactionView(
                    isPresented: $isAddingTransaction,
                    amount: $amount,
                    description: $description,
                    selectedDate: $selectedDate,
                    transactionType: $transactionType,
                    editingTransaction: editingTransaction,
                    onSave: {
                        if let editingTransaction = editingTransaction {
                            updateTransaction(editingTransaction)
                        } else {
                            addTransaction()
                        }
                    }
                )
            }
            .onAppear {
                loadTransactions()  // Llamada al cargar la vista
            }
        }
    }
    
    private func saveTransactions() {
        let transactionDictionaries = transactions.map { transaction in
            return [
                "id": transaction.id.uuidString,
                "date": transaction.date,
                "type": transaction.type.rawValue,
                "description": transaction.description,
                "amount": transaction.amount
            ]
        }
        
        UserDefaults.standard.set(transactionDictionaries, forKey: "transactions")
    }
    
    private func addTransaction() {
        guard let amountDouble = Double(amount) else { return }
        
        let newTransaction = Transaction(
            date: selectedDate,
            type: transactionType,
            description: description,
            amount: amountDouble
        )
        
        transactions.insert(newTransaction, at: 0)
        updateBalance()
        resetForm()
        saveTransactions()  // Guardar después de agregar
    }
    
    private func updateTransaction(_ transaction: Transaction) {
        guard let amountDouble = Double(amount),
              let index = transactions.firstIndex(where: { $0.id == transaction.id }) else { return }
        
        // Revertir el cambio anterior en el balance
        revertBalanceChange(for: transactions[index])
        
        // Crear la transacción actualizada
        let updatedTransaction = Transaction(
            date: selectedDate,
            type: transactionType,
            description: description,
            amount: amountDouble
        )
        
        transactions[index] = updatedTransaction
        updateBalance()
        resetForm()
        saveTransactions()  // Guardar después de actualizar
    }
    
    private func deleteTransaction(at index: Int) {
        revertBalanceChange(for: transactions[index])
        transactions.remove(at: index)
        saveTransactions()  // Guardar después de eliminar
    }
    
    private func revertBalanceChange(for transaction: Transaction) {
        switch transaction.type {
        case .income:
            balance -= transaction.amount
        case .expense:
            balance += transaction.amount
        case .pending:
            break
        }
    }
    
    private func loadTransactions() {
        if let savedTransactions = UserDefaults.standard.array(forKey: "transactions") as? [[String: Any]] {
            transactions = savedTransactions.map { dictionary in
                // Deserializamos cada valor asumiendo que siempre son válidos
                let date = dictionary["date"] as! Date
                let typeString = dictionary["type"] as! String
                let type = Transaction.TransactionType(rawValue: typeString)!
                let description = dictionary["description"] as! String
                let amount = dictionary["amount"] as! Double
                
                // Creamos y retornamos el objeto Transaction
                return Transaction(date: date, type: type, description: description, amount: amount)
            }
            // Luego de cargar las transacciones, actualizamos el balance
            updateBalance()
        }
    }

    
    private func updateBalance() {
        balance = transactions.reduce(0) { result, transaction in
            switch transaction.type {
            case .income:
                return result + transaction.amount
            case .expense:
                return result - transaction.amount
            case .pending:
                return result
            }
        }
    }
    
    private func resetForm() {
        amount = ""
        description = ""
        selectedDate = Date()
        transactionType = .income
        editingTransaction = nil
        isAddingTransaction = false
    }
}

struct BalanceCard: View {
    let balance: Double
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Nico's Balance")
                .font(.title3)
                .foregroundColor(.gray)
            
            Text("$\(balance, specifier: "%.2f")")
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(.black.opacity(0.6))
            
            HStack {
                Label("Last updated", systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(20)
    }
}

struct ActionButtonsView: View {
    @Binding var isAddingTransaction: Bool
    @Binding var showingChart: Bool
    
    var body: some View {
        HStack(spacing: 20) {
            Button(action: { isAddingTransaction = true }) {
                VStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                    Text("Add")
                        .font(.callout)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.black)
                .foregroundColor(.white)
                .cornerRadius(15)
            }
            
        }
    }
}

struct TransactionRow: View {
    let transaction: Transaction
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: transaction.type.icon)
                .foregroundColor(transaction.type.color)
                .font(.title2)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.description)
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.black)
                Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Text(transaction.type == .expense ? "-$\(transaction.amount, specifier: "%.2f")" : "+$\(transaction.amount, specifier: "%.2f")")
                .font(.system(.body, design: .rounded))
                .foregroundColor(transaction.type.color)
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(15)
    }
}

struct AddTransactionView: View {
    @Binding var isPresented: Bool
    @Binding var amount: String
    @Binding var description: String
    @Binding var selectedDate: Date
    @Binding var transactionType: Transaction.TransactionType
    let editingTransaction: Transaction?
    let onSave: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Transaction Details")) {
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    
                    TextField("Description", text: $description)
                    
                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                    
                    Picker("Type", selection: $transactionType) {
                        ForEach(Transaction.TransactionType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                }
            }
            .navigationTitle(editingTransaction != nil ? "Edit Transaction" : "New Transaction")
            .navigationBarItems(
                leading: Button("Cancel") { isPresented = false },
                trailing: Button("Save") { onSave() }
            )
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
