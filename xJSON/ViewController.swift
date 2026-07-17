//
//  JSONVC.swift
//  jsonViewer-jsonViewer
//
//  Created by dfpo on 22/02/2022.
//

import Cocoa
import WebKit

public class ViewController: NSViewController {
    
    
    // MARK: - 其他属性
    
    @IBOutlet private weak var m_web: WKWebView!
    @IBOutlet private var m_textView: NSTextView!
    private var isWebViewLoaded = false
    private let historyKey = "xjson.history.items"
    private let lastJSONKey = "xjson.history.last"
    private let maxHistoryCount = 30
    private var jsonHistory: [String] = []
    private var historyIndex: Int?
    private var isApplyingHistoryText = false
    private var historySaveWorkItem: DispatchWorkItem?
    private weak var previousHistoryMenuItem: NSMenuItem?
    private weak var nextHistoryMenuItem: NSMenuItem?
    
    
    
    
    // MARK: - 生命周期
    public override func viewDidLoad() {
        super.viewDidLoad()
        title = "json预览"
        m_web.navigationDelegate = self
        setupHistoryMenu()
        loadHistoryFromDefaults()
        restoreLastJSONIfNeeded()
        updateJSONView()
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillTerminate), name: NSApplication.willTerminateNotification, object: nil)
    }
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - 其他方法
    private func updateJSONView()  {
        if  isWebViewLoaded {
            renderJSONString()
        }else{
            setupWebJSONViewer()
        }
    }
    private func renderJSONString () {
        let jsParam = m_textView.string
        guard  jsParam.count > 0 else {
            return
        }
        // 如果是链接get
        if jsParam.starts(with: "http") {
            
            if let url = URL(string: m_textView.string)  {
                let  semaphore = DispatchSemaphore (value: 0)
                
                var request = URLRequest(url: url, timeoutInterval: Double.infinity)
                
                request.httpMethod = "GET"
                
                let task = URLSession.shared.dataTask(with: request) { data, response, error in
                    guard let data = data else {
                        print(String(describing: error))
                        semaphore.signal()
                        return
                    }
                    if let jsonStr = String(data: data, encoding: .utf8) {
                        
                        DispatchQueue.main.async {
                            self.renderJSONString(JSONString: jsonStr)
                        }
                    }
                    
                    semaphore.signal()
                }
                
                task.resume()
                semaphore.wait()
            }
            
            return
        }
        
        renderJSONString(JSONString: jsParam)
        
    }

    private func renderJSONString(JSONString: String) {
        let funName = "renderJSONString"
        m_web.evaluateJavaScript("\(funName)(\(JSONString))") { res, error in
            if let error = error {
                print(error.localizedDescription)
            } else if let obj = res as AnyObject?{
                print(obj)
            }
        }
    }
    private func setupWebJSONViewer() {
        guard let filePath = Bundle.main.path(forResource: "jsonviewer", ofType: "html") else {return}
        let fileURL = URL(fileURLWithPath: filePath)
        let htmlRequest = URLRequest(url: fileURL)
        m_web?.load(htmlRequest)
        
    }

    private func setupHistoryMenu() {
        guard let mainMenu = NSApp.mainMenu else { return }
        if mainMenu.item(withTitle: "历史") != nil { return }

        let historyRootItem = NSMenuItem(title: "历史", action: nil, keyEquivalent: "")
        let historyMenu = NSMenu(title: "历史")

        let previousItem = NSMenuItem(title: "上一个历史", action: #selector(showPreviousHistory), keyEquivalent: "[")
        previousItem.target = self
        previousItem.keyEquivalentModifierMask = [.command]
        historyMenu.addItem(previousItem)

        let nextItem = NSMenuItem(title: "下一个历史", action: #selector(showNextHistory), keyEquivalent: "]")
        nextItem.target = self
        nextItem.keyEquivalentModifierMask = [.command]
        historyMenu.addItem(nextItem)

        historyMenu.addItem(NSMenuItem.separator())

        let listItem = NSMenuItem(title: "查看历史列表...", action: #selector(showHistoryList), keyEquivalent: "h")
        listItem.target = self
        listItem.keyEquivalentModifierMask = [.command, .shift]
        historyMenu.addItem(listItem)

        let clearItem = NSMenuItem(title: "清空历史", action: #selector(clearHistory), keyEquivalent: "")
        clearItem.target = self
        historyMenu.addItem(clearItem)

        historyRootItem.submenu = historyMenu
        mainMenu.addItem(historyRootItem)
        previousHistoryMenuItem = previousItem
        nextHistoryMenuItem = nextItem
        updateHistoryMenuState()
    }

    private func loadHistoryFromDefaults() {
        let defaults = UserDefaults.standard
        if let list = defaults.array(forKey: historyKey) as? [String] {
            jsonHistory = list.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        } else {
            jsonHistory = []
        }
    }

    private func restoreLastJSONIfNeeded() {
        let defaults = UserDefaults.standard
        guard let lastJSON = defaults.string(forKey: lastJSONKey),
              !lastJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            updateHistoryMenuState()
            return
        }

        applyTextWithoutFeedback(lastJSON)
        saveToHistoryIfNeeded(lastJSON, markAsCurrent: true)

        if let index = jsonHistory.firstIndex(of: lastJSON) {
            historyIndex = index
        } else {
            historyIndex = 0
        }

        updateHistoryMenuState()
    }

    private func scheduleHistorySave() {
        historySaveWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.saveToHistoryIfNeeded(self.m_textView.string, markAsCurrent: true)
        }
        historySaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: workItem)
    }

    private func saveToHistoryIfNeeded(_ text: String, markAsCurrent: Bool) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let oldIndex = jsonHistory.firstIndex(of: text) {
            jsonHistory.remove(at: oldIndex)
        }
        jsonHistory.insert(text, at: 0)

        if jsonHistory.count > maxHistoryCount {
            jsonHistory = Array(jsonHistory.prefix(maxHistoryCount))
        }

        UserDefaults.standard.set(jsonHistory, forKey: historyKey)
        if markAsCurrent {
            UserDefaults.standard.set(text, forKey: lastJSONKey)
            historyIndex = 0
        }
        updateHistoryMenuState()
    }

    private func updateHistoryMenuState() {
        let count = jsonHistory.count
        guard count > 0 else {
            previousHistoryMenuItem?.isEnabled = false
            nextHistoryMenuItem?.isEnabled = false
            return
        }

        let index = historyIndex ?? 0
        previousHistoryMenuItem?.isEnabled = index < (count - 1)
        nextHistoryMenuItem?.isEnabled = index > 0
    }

    private func applyTextWithoutFeedback(_ text: String) {
        isApplyingHistoryText = true
        m_textView.string = text
        isApplyingHistoryText = false
    }

    private func applyHistory(at index: Int) {
        guard jsonHistory.indices.contains(index) else { return }
        let text = jsonHistory[index]
        historyIndex = index
        applyTextWithoutFeedback(text)
        UserDefaults.standard.set(text, forKey: lastJSONKey)
        updateJSONView()
        updateHistoryMenuState()
    }

    private func previewText(for text: String) -> String {
        let compact = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if compact.count <= 70 {
            return compact
        }
        return String(compact.prefix(70)) + "..."
    }

    @objc
    private func showPreviousHistory() {
        guard !jsonHistory.isEmpty else { return }
        let nextIndex: Int
        if let current = historyIndex {
            nextIndex = min(current + 1, jsonHistory.count - 1)
        } else {
            nextIndex = 0
        }
        applyHistory(at: nextIndex)
    }

    @objc
    private func showNextHistory() {
        guard !jsonHistory.isEmpty else { return }
        let nextIndex: Int
        if let current = historyIndex {
            nextIndex = max(current - 1, 0)
        } else {
            nextIndex = 0
        }
        applyHistory(at: nextIndex)
    }

    @objc
    private func showHistoryList() {
        guard !jsonHistory.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "暂无历史"
            alert.informativeText = "输入或粘贴 JSON 后会自动保存到历史。"
            alert.addButton(withTitle: "确定")
            alert.runModal()
            return
        }

        let alert = NSAlert()
        alert.messageText = "选择历史 JSON"
        alert.informativeText = "共 \(jsonHistory.count) 条，选择后会立即切换。"
        alert.addButton(withTitle: "切换")
        alert.addButton(withTitle: "取消")

        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 460, height: 28))
        for (index, value) in jsonHistory.enumerated() {
            popup.addItem(withTitle: "\(index + 1). \(previewText(for: value))")
        }
        if let current = historyIndex, jsonHistory.indices.contains(current) {
            popup.selectItem(at: current)
        }
        alert.accessoryView = popup

        let result = alert.runModal()
        if result == .alertFirstButtonReturn {
            applyHistory(at: popup.indexOfSelectedItem)
        }
    }

    @objc
    private func clearHistory() {
        let alert = NSAlert()
        alert.messageText = "确认清空历史吗？"
        alert.informativeText = "会删除已保存的所有 JSON 历史记录。"
        alert.addButton(withTitle: "清空")
        alert.addButton(withTitle: "取消")

        if alert.runModal() == .alertFirstButtonReturn {
            jsonHistory.removeAll()
            historyIndex = nil
            let defaults = UserDefaults.standard
            defaults.removeObject(forKey: historyKey)
            defaults.removeObject(forKey: lastJSONKey)
            updateHistoryMenuState()
        }
    }

    @objc
    private func applicationWillTerminate() {
        saveToHistoryIfNeeded(m_textView.string, markAsCurrent: true)
    }
    
}
// MARK: - WKNavigationDelegate
extension ViewController: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        
        
        if !isWebViewLoaded {
            isWebViewLoaded = true
            renderJSONString()
        }
    }
}
// MARK: - NSSplitViewDelegate
extension ViewController: NSSplitViewDelegate {
    // 最小最大滑动宽度
    public func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        return proposedMinimumPosition + 100
    }
    public func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        return proposedMaximumPosition - 100
    }
}
extension ViewController: NSTextDelegate {
    public func textDidChange(_ notification: Notification) {
        if isApplyingHistoryText {
            return
        }
        historyIndex = nil
        updateJSONView()
        scheduleHistorySave()
    }
}
