import Auth
import SwiftUI
import UniformTypeIdentifiers
import VisionKit
import os

private let logger = Logger(subsystem: "com.rentalmngr", category: "DocumentListView")

struct DocumentListView: View {
    @State private var viewModel: DocumentListViewModel
    @State private var isFileImporterPresented = false
    @State private var isScannerPresented = false
    @Environment(\.openURL) var openURL
    @Environment(AppState.self) private var appState

    init(appState: AppState, propertyId: UUID, tenantId: UUID? = nil) {
        let userId = appState.authService.currentUser?.id ?? UUID()
        _viewModel = State(
            initialValue: DocumentListViewModel(
                documentService: appState.documentService,
                userId: userId,
                propertyId: propertyId,
                tenantId: tenantId
            ))
    }

    var body: some View {
        VStack(spacing: 16) {
            if viewModel.isLoading {
                ProgressView().id(UUID())
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text("Error loading documents", comment: "Error heading when documents fail to load")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button(String(localized: "Retry", locale: LanguageService.currentLocale, comment: "Retry loading button")) {
                        Task { await viewModel.fetchDocuments() }
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 40)
            } else if viewModel.documents.isEmpty {
                ContentUnavailableView(
                    String(localized: "No documents", locale: LanguageService.currentLocale, comment: "Empty state title for documents"),
                    systemImage: "doc.text",
                    description: Text("Upload contracts, invoices, or IDs.", comment: "Empty state subtitle for documents")
                )
                .padding(.top, 40)
            } else {
                // Grouped by year — useful for tax/annual review (contracts, invoices).
                ForEach(documentsByYear, id: \.year) { group in
                    HStack {
                        Text(verbatim: String(group.year))
                            .font(.title3.bold())
                        Spacer()
                        Text("\(group.docs.count)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)

                    ForEach(group.docs) { doc in
                        documentRow(doc)
                    }
                }
            }
        }
        .padding(.bottom, 20)
        .refreshable {
            await viewModel.refresh()
        }
        .navigationTitle(String(localized: "Documents", locale: LanguageService.currentLocale, comment: "Navigation title for documents list"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        isFileImporterPresented = true
                    } label: {
                        Label(
                            String(localized: "Upload file", locale: LanguageService.currentLocale, comment: "Menu option to upload a file"),
                            systemImage: "folder")
                    }
                    if VNDocumentCameraViewController.isSupported {
                        Button {
                            isScannerPresented = true
                        } label: {
                            Label(
                                String(localized: "Scan document", locale: LanguageService.currentLocale, comment: "Menu option to scan a document with camera"),
                                systemImage: "doc.viewfinder")
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(String(localized: "Añadir documento", locale: LanguageService.currentLocale, comment: "Accessibility label for add document menu"))
                .disabled(viewModel.isUploading)
            }
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.pdf, .image],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    Task { await viewModel.uploadDocument(url: url, onSuccess: {}) }
                }
            case .failure(let error):
                logger.error("Error picking file: \(error.localizedDescription)")
            }
        }
        .sheet(isPresented: $isScannerPresented) {
            DocumentScannerView { data, name in
                Task { await viewModel.uploadScannedDocument(data: data, name: name) }
            }
            .preferredColorScheme(appState.userInterfaceStyle.colorScheme)
        }
        .task {
            await viewModel.fetchDocuments()
        }
        .overlay {
            if viewModel.isUploading {
                ProgressView(String(localized: "Uploading...", locale: LanguageService.currentLocale, comment: "Upload progress indicator"))
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .alert(
            String(localized: "Upload error", locale: LanguageService.currentLocale, comment: "Alert title for upload error"),
            isPresented: Binding(
                get: { viewModel.uploadError != nil },
                set: { if !$0 { viewModel.uploadError = nil } }
            )
        ) {
            Button(String(localized: "OK", locale: LanguageService.currentLocale, comment: "Alert dismiss button")) {
                viewModel.uploadError = nil
            }
        } message: {
            Text(viewModel.uploadError ?? "")
        }
    }

    /// Documents grouped by calendar year, newest year first.
    private var documentsByYear: [(year: Int, docs: [Document])] {
        let groups = Dictionary(grouping: viewModel.documents) {
            Calendar.current.component(.year, from: $0.createdAt)
        }
        return groups
            .map { (year: $0.key, docs: $0.value.sorted { $0.createdAt > $1.createdAt }) }
            .sorted { $0.year > $1.year }
    }

    @ViewBuilder
    private func documentRow(_ doc: Document) -> some View {
        HStack {
            Image(systemName: iconName(for: doc.fileType))
                .foregroundStyle(.blue)
                .font(.title2)

            VStack(alignment: .leading) {
                Text(doc.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(doc.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            Menu {
                Button(String(localized: "View", locale: LanguageService.currentLocale, comment: "Button to view document"), systemImage: "eye") {
                    openDocument(doc)
                }
                Button(String(localized: "Delete", locale: LanguageService.currentLocale, comment: "Button to delete document"), systemImage: "trash", role: .destructive) {
                    Task { await viewModel.deleteDocument(doc) }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .padding(8)
            }
            .accessibilityLabel(String(localized: "Más opciones", locale: LanguageService.currentLocale, comment: "Accessibility label for document options menu"))
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func iconName(for fileType: String) -> String {
        if fileType.contains("pdf") { return "doc.text.fill" }
        if fileType.contains("image") { return "photo.fill" }
        return "doc.fill"
    }

    private func openDocument(_ doc: Document) {
        if let url = viewModel.getDocumentURL(doc) {
            openURL(url)
        }
    }
}
