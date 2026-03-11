import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    
    // UI Elements
    private let containerView = UIView()
    private let handleBar = UIView()
    private let headerLabel = UILabel()
    private let typeSegment = UISegmentedControl(items: ["Auto", "Text", "Link", "Photo"])
    private let textView = UITextView()
    private let noteField = UITextView()
    private let saveButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    
    private var detectedURL: String?
    private var detectedText: String?
    private var detectedImageData: Data?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        extractSharedContent()
    }
    
    // MARK: - UI Setup
    func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        
        // Container
        containerView.backgroundColor = UIColor.systemBackground
        containerView.layer.cornerRadius = 16
        containerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            containerView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.75)
        ])
        
        // Handle bar
        handleBar.backgroundColor = UIColor.systemGray4
        handleBar.layer.cornerRadius = 2.5
        handleBar.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(handleBar)
        
        NSLayoutConstraint.activate([
            handleBar.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            handleBar.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            handleBar.widthAnchor.constraint(equalToConstant: 36),
            handleBar.heightAnchor.constraint(equalToConstant: 5)
        ])
        
        // Header
        headerLabel.text = "Save to Commonplace"
        headerLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(headerLabel)
        
        // Cancel button
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)
        containerView.addSubview(cancelButton)
        
        // Save button
        saveButton.setTitle("Save", for: .normal)
        saveButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.addTarget(self, action: #selector(save), for: .touchUpInside)
        containerView.addSubview(saveButton)
        
        NSLayoutConstraint.activate([
            cancelButton.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            cancelButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            
            headerLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            headerLabel.centerYAnchor.constraint(equalTo: cancelButton.centerYAnchor),
            
            saveButton.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            saveButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16)
        ])
        
        // Scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: cancelButton.bottomAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.bottomAnchor)
        ])
        
        // Stack view
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 8),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])
        
        // Type segment
        typeSegment.selectedSegmentIndex = 0
        typeSegment.addTarget(self, action: #selector(typeChanged), for: .valueChanged)
        stackView.addArrangedSubview(typeSegment)
        
        // Preview label
        textView.isEditable = false
        textView.backgroundColor = UIColor.systemGray6
        textView.layer.cornerRadius = 8
        textView.font = UIFont.systemFont(ofSize: 14)
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        textView.heightAnchor.constraint(equalToConstant: 80).isActive = true
        stackView.addArrangedSubview(textView)
        
        // Note label
        let noteLabel = UILabel()
        noteLabel.text = "Add a note..."
        noteLabel.font = UIFont.systemFont(ofSize: 13)
        noteLabel.textColor = .secondaryLabel
        stackView.addArrangedSubview(noteLabel)
        
        // Note field
        noteField.backgroundColor = UIColor.systemGray6
        noteField.layer.cornerRadius = 8
        noteField.font = UIFont.systemFont(ofSize: 15)
        noteField.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        noteField.heightAnchor.constraint(equalToConstant: 80).isActive = true
        stackView.addArrangedSubview(noteField)
    }
    
    // MARK: - Extract Content
    func extractSharedContent() {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { return }
        
        for item in items {
            guard let attachments = item.attachments else { continue }
            for attachment in attachments {
                
                // URL
                if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    attachment.loadItem(forTypeIdentifier: UTType.url.identifier) { [weak self] data, _ in
                        DispatchQueue.main.async {
                            if let url = data as? URL {
                                self?.detectedURL = url.absoluteString
                                self?.textView.text = url.absoluteString
                                self?.typeSegment.selectedSegmentIndex = 2
                            }
                        }
                    }
                    return
                }
                
                // Text
                if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier) { [weak self] data, _ in
                        DispatchQueue.main.async {
                            if let text = data as? String {
                                self?.detectedText = text
                                self?.textView.text = text
                                self?.typeSegment.selectedSegmentIndex = 1
                            }
                        }
                    }
                    return
                }
                
                // Image
                if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    attachment.loadItem(forTypeIdentifier: UTType.image.identifier) { [weak self] data, _ in
                        DispatchQueue.main.async {
                            if let url = data as? URL,
                               let imageData = try? Data(contentsOf: url) {
                                self?.detectedImageData = imageData
                                self?.textView.text = "📷 Image ready to save"
                                self?.typeSegment.selectedSegmentIndex = 3
                            } else if let image = data as? UIImage,
                                      let imageData = image.jpegData(compressionQuality: 0.8) {
                                self?.detectedImageData = imageData
                                self?.textView.text = "📷 Image ready to save"
                                self?.typeSegment.selectedSegmentIndex = 3
                            }
                        }
                    }
                    return
                }
            }
        }
    }
    
    // MARK: - Actions
    @objc func typeChanged() {
        // Update preview based on selected type
    }
    
    @objc func cancel() {
        extensionContext?.completeRequest(returningItems: nil)
    }
    
    @objc func save() {
        let note = noteField.text ?? ""
        let selectedIndex = typeSegment.selectedSegmentIndex
        
        var entry: QueuedEntry
        
        switch selectedIndex {
        case 1: // Text
            entry = QueuedEntry(type: "text", text: detectedText ?? note)
        case 2: // Link
            entry = QueuedEntry(type: "link", text: note, url: detectedURL)
        case 3: // Photo
            entry = QueuedEntry(type: "photo", text: note, imageData: detectedImageData)
        default: // Auto
            if let url = detectedURL {
                entry = QueuedEntry(type: "link", text: note, url: url)
            } else if let imageData = detectedImageData {
                entry = QueuedEntry(type: "photo", text: note, imageData: imageData)
            } else {
                entry = QueuedEntry(type: "text", text: detectedText ?? note)
            }
        }
        
        ShareQueue.append(entry)
        extensionContext?.completeRequest(returningItems: nil)
    }
}
