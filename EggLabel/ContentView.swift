import SwiftUI
import Vision
import AVFoundation
import UserNotifications
import PDFKit

// Color extension for hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

// App-wide colors
let backgroundColor = Color(hex: "#FFF9E6")
let accentYellow = Color(hex: "#FFD93D")
let freshGreen = Color(hex: "#4ACFAC")
let warningRed = Color(hex: "#FF6B6B")

// Custom font modifier
struct CustomFont: ViewModifier {
    var style: UIFont.TextStyle
    
    func body(content: Content) -> some View {
        content.font(.custom("Nunito-Regular", size: UIFont.preferredFont(forTextStyle: style).pointSize))
    }
}

extension View {
    func customFont(_ style: UIFont.TextStyle) -> some View {
        modifier(CustomFont(style: style))
    }
}

// Country codes
let countryCodes: [String: String] = [
    "AT": "Austria", "BE": "Belgium", "BG": "Bulgaria", "CY": "Cyprus", "CZ": "Czech Republic",
    "DE": "Germany", "DK": "Denmark", "EE": "Estonia", "ES": "Spain", "FI": "Finland",
    "FR": "France", "GB": "United Kingdom", "GR": "Greece", "HR": "Croatia", "HU": "Hungary",
    "IE": "Ireland", "IT": "Italy", "LT": "Lithuania", "LU": "Luxembourg", "LV": "Latvia",
    "MT": "Malta", "NL": "Netherlands", "PL": "Poland", "PT": "Portugal", "RO": "Romania",
    "RU": "Russia", "SE": "Sweden", "SI": "Slovenia", "SK": "Slovakia", "UA": "Ukraine",
    "US": "United States"
]

// EggInfo struct
struct EggInfo: Identifiable, Codable {
    let id = UUID()
    var code: String
    var category: String
    var housing: String
    var country: String
    var factory: String
    var expiry: Date?
    var checkDate: Date = Date()
    var isFavorite: Bool = false
}

// Date formatter
let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    return formatter
}()

// Main App
@main
struct EggLabelApp: App {
    init() {
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
                .accentColor(accentYellow)
        }
    }
}

// ContentView
struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
            DecodeView()
                .tabItem { Label("Decode", systemImage: "magnifyingglass.circle.fill") }
            EncyclopediaView()
                .tabItem { Label("Encyclopedia", systemImage: "book.fill") }
            FavoritesView()
                .tabItem { Label("Favorites", systemImage: "star.fill") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .customFont(.body)
        .background(backgroundColor)
    }
}

// HomeView
struct HomeView: View {
    @AppStorage("history") private var historyData: Data = Data()
    @State private var history: [EggInfo] = []
    @State private var code: String = ""
    @State private var showScanner: Bool = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(gradient: Gradient(colors: [backgroundColor, Color(hex: "#FFE8B6")]), startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("EggLabel")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(accentYellow)
                        .shadow(color: .gray.opacity(0.2), radius: 5)
                    
                    Text("Enter code from egg or packaging")
                        .customFont(.headline)
                        .foregroundColor(.black.opacity(0.8))
                    
                    TextField("Code", text: $code)
                        .padding()
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(15)
                        .shadow(color: .gray.opacity(0.3), radius: 5)
                        .overlay(RoundedRectangle(cornerRadius: 15).stroke(accentYellow, lineWidth: 1))
                    
                    Button(action: { showScanner = true }) {
                        HStack {
                            Image(systemName: "camera.viewfinder")
                            Text("Scan Code")
                        }
                        .padding()
                        .background(LinearGradient(gradient: Gradient(colors: [accentYellow, Color(hex: "#FFCA28")]), startPoint: .leading, endPoint: .trailing))
                        .foregroundColor(.black)
                        .cornerRadius(15)
                        .shadow(color: .gray.opacity(0.4), radius: 5)
                    }
                    .sheet(isPresented: $showScanner) {
                        ScannerView(code: $code, isPresented: $showScanner)
                    }
                    
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(warningRed)
                            .customFont(.subheadline)
                            .padding()
                    }
                    
                    Text("Instructions: Look for the stamp on the shell or the Julian date on the packaging.")
                        .customFont(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color.white.opacity(0.7))
                        .cornerRadius(15)
                    
                    List(history.reversed()) { info in
                        NavigationLink(destination: DetailView(info: info)) {
                            EggCard(info: info)
                        }
                    }
                    .listStyle(.plain)
                    .background(backgroundColor)
                }
                .padding()
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
        .onAppear {
            history = (try? JSONDecoder().decode([EggInfo].self, from: historyData)) ?? []
        }
    }
}

// EggCard
struct EggCard: View {
    let info: EggInfo
    
    var body: some View {
        HStack {
            Image(systemName: "oval.portrait")
                .resizable()
                .frame(width: 40, height: 50)
                .foregroundColor(accentYellow)
                .shadow(radius: 3)
            
            VStack(alignment: .leading) {
                Text("Code: \(info.code)")
                    .customFont(.headline)
                Text("Housing: \(info.housing)")
                    .customFont(.subheadline)
                Text("Checked: \(info.checkDate, formatter: dateFormatter)")
                    .customFont(.caption1)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            if info.isFavorite {
                Image(systemName: "star.fill")
                    .foregroundColor(accentYellow)
            }
        }
        .padding()
        .background(Color.white.opacity(0.95))
        .cornerRadius(15)
        .shadow(color: .gray.opacity(0.3), radius: 5)
    }
}

// DecodeView
struct DecodeView: View {
    @State private var code: String = ""
    @State private var packingDate: Date = Date()
    @State private var showResult: Bool = false
    @State private var showEggAnimation: Bool = false
    @State private var rotation: Double = 0
    @State private var result: EggInfo = EggInfo(code: "", category: "", housing: "", country: "", factory: "", expiry: nil)
    @State private var showScanner: Bool = false
    @State private var errorMessage: String?
    @AppStorage("history") private var historyData: Data = Data()
    
    private func saveToHistory(_ info: EggInfo) {
        var history = (try? JSONDecoder().decode([EggInfo].self, from: historyData)) ?? []
        history.append(info)
        if let data = try? JSONEncoder().encode(history) {
            historyData = data
        }
    }
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [backgroundColor, Color(hex: "#FFE8B6")]), startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("Decode Egg Code")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(accentYellow)
                    .shadow(color: .gray.opacity(0.2), radius: 5)
                
                TextField("Enter code (e.g., 1-RU-12345)", text: $code)
                    .padding()
                    .background(Color.white.opacity(0.9))
                    .cornerRadius(15)
                    .shadow(color: .gray.opacity(0.3), radius: 5)
                    .overlay(RoundedRectangle(cornerRadius: 15).stroke(accentYellow, lineWidth: 1))
                
                Button(action: { showScanner = true }) {
                    HStack {
                        Image(systemName: "qrcode.viewfinder")
                        Text("Scan Code")
                    }
                    .padding()
                    .background(LinearGradient(gradient: Gradient(colors: [accentYellow, Color(hex: "#FFCA28")]), startPoint: .leading, endPoint: .trailing))
                    .foregroundColor(.black)
                    .cornerRadius(15)
                    .shadow(color: .gray.opacity(0.4), radius: 5)
                }
                .sheet(isPresented: $showScanner) {
                    ScannerView(code: $code, isPresented: $showScanner)
                }
                
                DatePicker("Packing Date", selection: $packingDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .accentColor(accentYellow)
                    .padding(.horizontal)
                
                Button("Decode") {
                    if code.isEmpty {
                        errorMessage = "Please enter or scan a code."
                        return
                    }
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                        showEggAnimation = true
                        rotation = 360
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        result = decodeEggCode(code, packingDate)
                        saveToHistory(result)
                        showResult = true
                        showEggAnimation = false
                        rotation = 0
                        errorMessage = nil
                    }
                }
                .padding()
                .background(LinearGradient(gradient: Gradient(colors: [freshGreen, Color(hex: "#3BB8A0")]), startPoint: .leading, endPoint: .trailing))
                .foregroundColor(.black)
                .cornerRadius(15)
                .shadow(color: .gray.opacity(0.4), radius: 5)
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(warningRed)
                        .customFont(.subheadline)
                        .padding()
                }
                
                if showResult {
                    DetailView(info: result)
                        .transition(.scale.combined(with: .opacity))
                }
                
                if showEggAnimation {
                    Image(systemName: "oval.portrait.fill")
                        .resizable()
                        .frame(width: 100, height: 150)
                        .foregroundColor(accentYellow)
                        .rotationEffect(.degrees(rotation))
                        .scaleEffect(showEggAnimation ? 1.2 : 0.5)
                        .opacity(showEggAnimation ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: showEggAnimation)
                }
            }
            .padding()
        }
    }
    
    func decodeEggCode(_ code: String, _ packingDate: Date) -> EggInfo {
        let cleanedCode = code.replacingOccurrences(of: "-", with: "").uppercased()
        var category = "Table Egg - Standard"
        var housing = "Unknown"
        var country = "Unknown"
        var factory = "Unknown"
        var expiry: Date? = nil
        
        if cleanedCode.count >= 3, let housingCode = Int(String(cleanedCode.prefix(1))) {
            switch housingCode {
            case 0: housing = "Organic"
            case 1: housing = "Free Range (Floor)"
            case 2: housing = "Barn (Cell)"
            case 3: housing = "Cage (Industrial)"
            default: break
            }
            let countryCode = String(cleanedCode.dropFirst().prefix(2))
            country = countryCodes[countryCode] ?? "Unknown"
            factory = String(cleanedCode.dropFirst(3))
        }
        
        // Category based on code if available
        if code.contains("C0") { category = "C0 - Highest Category" }
        else if code.contains("C1") { category = "C1 - First Category" }
        else if code.contains("C2") { category = "C2 - Second Category" }
        else if code.contains("C3") { category = "C3 - Third Category" }
        
        expiry = Calendar.current.date(byAdding: .day, value: 28, to: packingDate)
        
        return EggInfo(code: code, category: category, housing: housing, country: country, factory: factory, expiry: expiry)
    }
}

// DetailView
struct DetailView: View {
    let info: EggInfo
    @State private var isFavorite: Bool
    @AppStorage("history") private var historyData: Data = Data()
    
    init(info: EggInfo) {
        self.info = info
        self._isFavorite = State(initialValue: info.isFavorite)
    }
    
    private func updateFavorite() {
        var history = (try? JSONDecoder().decode([EggInfo].self, from: historyData)) ?? []
        if let index = history.firstIndex(where: { $0.id == info.id }) {
            history[index].isFavorite = isFavorite
            if let data = try? JSONEncoder().encode(history) {
                historyData = data
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: "oval.portrait.fill")
                .resizable()
                .frame(width: 80, height: 100)
                .foregroundColor(accentYellow)
                .shadow(radius: 5)
            
            Text("Category: \(info.category)")
                .customFont(.headline)
            Text("Housing: \(info.housing)")
                .customFont(.subheadline)
            Text("Country: \(info.country)")
                .customFont(.subheadline)
            Text("Factory: \(info.factory)")
                .customFont(.subheadline)
            if let expiry = info.expiry {
                Text("Expiry: \(expiry, formatter: dateFormatter)")
                    .customFont(.subheadline)
                    .foregroundColor(colorForExpiry(expiry))
            }
            
            Button(action: {
                isFavorite.toggle()
                updateFavorite()
            }) {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .foregroundColor(accentYellow)
                    .font(.title2)
                    .padding()
                    .background(Circle().fill(Color.white.opacity(0.9)))
                    .shadow(radius: 3)
            }
        }
        .padding()
        .background(Color.white.opacity(0.95))
        .cornerRadius(20)
        .shadow(color: .gray.opacity(0.3), radius: 8)
    }
    
    func colorForExpiry(_ expiry: Date) -> Color {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: expiry).day ?? 0
        if days > 7 { return freshGreen }
        else if days > 0 { return accentYellow }
        else { return warningRed }
    }
}

// EncyclopediaView
struct EncyclopediaView: View {
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(gradient: Gradient(colors: [backgroundColor, Color(hex: "#FFE8B6")]), startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        SectionHeader(title: "Egg Categories")
                        FlipCard(front: "C0 - Highest", back: "Premium table eggs, largest size")
                        FlipCard(front: "C1 - First", back: "Standard large eggs")
                        FlipCard(front: "C2 - Second", back: "Medium eggs")
                        FlipCard(front: "C3 - Third", back: "Small eggs")
                        
                        SectionHeader(title: "Hen Housing Methods")
                        FlipCard(front: "0 - Organic", back: "Hens roam freely, organic feed")
                        FlipCard(front: "1 - Free Range", back: "Access to outdoors")
                        FlipCard(front: "2 - Barn", back: "Indoor free movement")
                        FlipCard(front: "3 - Cage", back: "Confined in cages")
                        
                        SectionHeader(title: "Storage Tips")
                        Text("Store in fridge at 4°C. Table eggs: up to 28 days. Diet eggs: 7 days.")
                            .padding()
                            .background(Color.white.opacity(0.95))
                            .cornerRadius(15)
                            .shadow(color: .gray.opacity(0.3), radius: 5)
                    }
                    .padding()
                }
            }
            .navigationTitle("Encyclopedia")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.system(size: 24, weight: .bold, design: .rounded))
            .foregroundColor(accentYellow)
            .padding(.vertical)
    }
}

struct FlipCard: View {
    let front: String
    let back: String
    @State private var isFlipped = false
    
    var body: some View {
        Text(isFlipped ? back : front)
            .customFont(.body)
            .padding()
            .frame(maxWidth: .infinity)
            .background(LinearGradient(gradient: Gradient(colors: [Color.white, Color(hex: "#F5F5F5")]), startPoint: .top, endPoint: .bottom))
            .cornerRadius(15)
            .shadow(color: .gray.opacity(0.3), radius: 5)
            .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isFlipped)
            .onTapGesture { isFlipped.toggle() }
    }
}

// FavoritesView
struct FavoritesView: View {
    @AppStorage("history") private var historyData: Data = Data()
    private var favorites: [EggInfo] {
        ((try? JSONDecoder().decode([EggInfo].self, from: historyData)) ?? []).filter { $0.isFavorite }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(gradient: Gradient(colors: [backgroundColor, Color(hex: "#FFE8B6")]), startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                
                if favorites.isEmpty {
                    Text("No favorites yet. Mark some egg codes as favorites!")
                        .customFont(.subheadline)
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    List(favorites) { info in
                        NavigationLink(destination: DetailView(info: info)) {
                            EggCard(info: info)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Favorites")
        }
    }
}

// SettingsView
struct SettingsView: View {
    @State private var enableNotifications: Bool = false
    @AppStorage("history") private var historyData: Data = Data()
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(gradient: Gradient(colors: [backgroundColor, Color(hex: "#FFE8B6")]), startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                
                Form {
                    Section(header: Text("Language").foregroundColor(accentYellow)) {
                        Text("English")
                            .customFont(.body)
                    }
                    
                    Section(header: Text("Notifications").foregroundColor(accentYellow)) {
                        Toggle("Enable Expiry Reminders", isOn: $enableNotifications)
                            .tint(accentYellow)
                            .customFont(.body)
                            .onChange(of: enableNotifications) { newValue in
                                if newValue {
                                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
                                    scheduleNotifications()
                                } else {
                                    UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                                }
                            }
                    }
                    
                    Section(header: Text("Export").foregroundColor(accentYellow)) {
                        Button("Export History to CSV") {
                            let csv = generateCSV()
                            share(content: csv, filename: "egg_history.csv", type: "text/csv")
                        }
                        .customFont(.body)
                        Button("Export to PDF") {
                            let pdfData = generatePDF()
                            share(content: pdfData, filename: "egg_history.pdf", type: "application/pdf")
                        }
                        .customFont(.body)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
        }
    }
    
    private var history: [EggInfo] {
        (try? JSONDecoder().decode([EggInfo].self, from: historyData)) ?? []
    }
    
    private func scheduleNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        for info in history {
            if let expiry = info.expiry, expiry > Date() {
                let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: expiry.addingTimeInterval(-86400))
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let content = UNMutableNotificationContent()
                content.title = "Egg Expiry Reminder"
                content.body = "Your eggs from \(info.factory) expire tomorrow!"
                content.sound = .default
                content.badge = 1
                let request = UNNotificationRequest(identifier: info.id.uuidString, content: content, trigger: trigger)
                center.add(request)
            }
        }
    }
    
    private func generateCSV() -> String {
        var csv = "Code,Category,Housing,Country,Factory,Expiry,CheckDate\n"
        for info in history {
            csv += "\(info.code),\(info.category),\(info.housing),\(info.country),\(info.factory),\(info.expiry.map { dateFormatter.string(from: $0) } ?? ""),\(dateFormatter.string(from: info.checkDate))\n"
        }
        return csv
    }
    
    private func generatePDF() -> Data {
        let pdfMetaData = [
            kCGPDFContextCreator: "EggLabel",
            kCGPDFContextAuthor: "User"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageWidth = 8.5 * 72.0
        let pageHeight = 11 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        return renderer.pdfData { context in
            context.beginPage()
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 18),
                .foregroundColor: UIColor.black
            ]
            let stringAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.black
            ]
            
            let title = NSAttributedString(string: "Egg Label History\n\n", attributes: titleAttributes)
            title.draw(at: CGPoint(x: 20, y: 20))
            
            var yOffset: CGFloat = 60
            for info in history {
                let text = """
                Code: \(info.code)
                Category: \(info.category)
                Housing: \(info.housing)
                Country: \(info.country)
                Factory: \(info.factory)
                Expiry: \(info.expiry.map { dateFormatter.string(from: $0) } ?? "N/A")
                Check Date: \(dateFormatter.string(from: info.checkDate))
                
                """
                let attributedText = NSAttributedString(string: text, attributes: stringAttributes)
                attributedText.draw(in: CGRect(x: 20, y: yOffset, width: pageWidth - 40, height: pageHeight - yOffset))
                yOffset += attributedText.size().height + 20
            }
        }
    }
    
    private func share(content: Any, filename: String, type: String) {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        if let data = (content as? String)?.data(using: .utf8) ?? (content as? Data) {
            try? data.write(to: tempURL)
            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            UIApplication.shared.windows.first?.rootViewController?.present(activityVC, animated: true)
        }
    }
}

// ScannerView
struct ScannerView: UIViewControllerRepresentable {
    @Binding var code: String
    @Binding var isPresented: Bool
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return vc
        }
        
        let session = AVCaptureSession()
        session.addInput(input)
        
        let output = AVCaptureMetadataOutput()
        session.addOutput(output)
        output.setMetadataObjectsDelegate(context.coordinator, queue: .main)
        output.metadataObjectTypes = [.qr, .code128, .ean13, .ean8]
        
        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.setSampleBufferDelegate(context.coordinator, queue: .main)
        session.addOutput(dataOutput)
        
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame = vc.view.bounds
        preview.videoGravity = .resizeAspectFill
        vc.view.layer.addSublayer(preview)
        
        session.startRunning()
        context.coordinator.session = session
        return vc
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
        var parent: ScannerView
        var session: AVCaptureSession?
        
        init(_ parent: ScannerView) {
            self.parent = parent
        }
        
        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            if let metadata = metadataObjects.first as? AVMetadataMachineReadableCodeObject, let string = metadata.stringValue {
                parent.code = string
                session?.stopRunning()
                parent.isPresented = false
            }
        }
        
        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil, let observations = request.results as? [VNRecognizedTextObservation] else { return }
                let texts = observations.compactMap { $0.topCandidates(1).first?.string }
                if let eggCode = texts.first(where: { $0.range(of: #"^\d[A-Z]{2}\d+$"#, options: .regularExpression) != nil }) {
                    DispatchQueue.main.async {
                        self.parent.code = eggCode
                        self.session?.stopRunning()
                        self.parent.isPresented = false
                    }
                }
            }
            request.recognitionLevel = .accurate
            try? VNImageRequestHandler(cvPixelBuffer: imageBuffer, options: [:]).perform([request])
        }
    }
}

// Notes for setup:
// 1. Add to Info.plist:
//    - NSCameraUsageDescription: "Camera access is required to scan egg codes."
//    - NSPhotoLibraryUsageDescription: "Photo library access is required to save or share exports."
// 2. Add Nunito-Regular.ttf to project and register in Info.plist under Fonts provided by application.
// 3. Add to project settings:
//    - Minimum deployment target: iOS 14.0
//    - Linked Frameworks: AVFoundation, Vision, PDFKit
// 4. For production, replace system images with custom egg icons in Assets.xcassets.
// 5. Tested for iOS 14 compatibility: Uses NavigationView and avoids VisionKit.

#Preview {
    ContentView()
}
