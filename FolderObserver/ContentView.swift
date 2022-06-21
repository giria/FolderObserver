//
//  ContentView.swift
//  FolderObserver
//
//  Created by jbarrull on 21/06/2022.
//

import SwiftUI


struct ContentView: View {
    @ObservedObject var folder = Folder()
    
    var body: some View {
        NavigationView {
            List(folder.files) { file in
                Text(file.lastPathComponent)
            }
            .navigationBarTitle("Folder Monitor")
    
            .navigationBarItems(leading: rightNavItem, trailing: deleteFileNavItem)
        }
    }
    
    var deleteFileNavItem: some View {
        Group {
            if folder.files.count > 0 {
                Button(action: deleteFile) {
                    Image(systemName: "trash")
                }
            }
        }
    }
    
    var rightNavItem: some View {
        Button(action: createFile) {
            Image(systemName: "plus.square")
        }
    }
    
    func createFile() {
        let file = UUID().uuidString
        try? file.write(to: folder.url.appendingPathComponent(file), atomically: true, encoding: .utf8)
    }
    
    func deleteFile() {
        try? FileManager.default.removeItem(at: folder.files.first!)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}


extension URL: Identifiable {
    public var id: URL { self }
}


class Folder: ObservableObject {
    @Published var files: [URL] = []
   
    
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
    private lazy var folderMonitor = FolderMonitor(url: self.url)
    
    init() {
        folderMonitor.folderDidChange = { [weak self] in
            self?.handleChanges()
        }
        folderMonitor.startMonitoring()
        self.handleChanges()
    }
    
    func handleChanges() {
        let files = (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: .producesRelativePathURLs)) ?? []
        DispatchQueue.main.async {
            self.files = files
        }
    }
}

class FolderMonitor {
    // MARK: Properties
    
    /// A file descriptor for the monitored directory.
    private var monitoredFolderFileDescriptor: CInt = -1
/// A dispatch queue used for sending file changes in the directory.
    private let folderMonitorQueue = DispatchQueue(label: "FolderMonitorQueue", attributes: .concurrent)
/// A dispatch source to monitor a file descriptor created from the directory.
    private var folderMonitorSource: DispatchSourceFileSystemObject?
/// URL for the directory being monitored.
    let url: Foundation.URL
    
    var folderDidChange: (() -> Void)?
// MARK: Initializers
init(url: Foundation.URL) {
        self.url = url
    }
// MARK: Monitoring
/// Listen for changes to the directory (if we are not already).
    func startMonitoring() {
        guard folderMonitorSource == nil && monitoredFolderFileDescriptor == -1 else {
            return
            
        }
            // Open the directory referenced by URL for monitoring only.
            monitoredFolderFileDescriptor = open(url.path, O_EVTONLY)
// Define a dispatch source monitoring the directory for additions, deletions, and renamings.
            folderMonitorSource = DispatchSource.makeFileSystemObjectSource(fileDescriptor: monitoredFolderFileDescriptor, eventMask: .write, queue: folderMonitorQueue)
// Define the block to call when a file change is detected.
            folderMonitorSource?.setEventHandler { [weak self] in
                self?.folderDidChange?()
            }
// Define a cancel handler to ensure the directory is closed when the source is cancelled.
            folderMonitorSource?.setCancelHandler { [weak self] in
                guard let strongSelf = self else { return }
                close(strongSelf.monitoredFolderFileDescriptor)
strongSelf.monitoredFolderFileDescriptor = -1
strongSelf.folderMonitorSource = nil
            }
// Start monitoring the directory via the source.
            folderMonitorSource?.resume()
    }
/// Stop listening for changes to the directory, if the source has been created.
    func stopMonitoring() {
        folderMonitorSource?.cancel()
    }
}
