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
    
    
    
    
    // MARK: - 生命周期
    public override func viewDidLoad() {
        super.viewDidLoad()
        title = "json预览"
        m_web.navigationDelegate = self
        updateJSONView()
        
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
        updateJSONView()
    }
}
