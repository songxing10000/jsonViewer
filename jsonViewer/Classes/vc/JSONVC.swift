//
//  JSONVC.swift
//  jsonViewer-jsonViewer
//
//  Created by dfpo on 22/02/2022.
//

import Cocoa
import WebKit

func getLibBundle() -> Bundle? {
    let fb = Bundle(for: JSONVC.self)
    guard let path = fb.path(forResource: "jsonViewer", ofType: "bundle") else {
        return nil
    }
    return Bundle(path: path)
    
}
func getImg(_ imgName: String?) -> NSImage? {
    guard let imgName = imgName else {
        return nil
    }
    return getLibBundle()?.image(forResource:  imgName )
}
public class JSONVC: NSViewController {
    // MARK: - 初始方法
    public static func vc(urlStr: String?) -> JSONVC {
        let vc = JSONVC(nibName: "JSONVC", bundle: getLibBundle())
        vc.urlStr = urlStr
         return vc
    }
    public static func vc(jsonString: String?) -> JSONVC {
        let vc = JSONVC(nibName: "JSONVC", bundle: getLibBundle())
        vc.jsonString = jsonString
         return vc
        
    }
    // MARK: - 其他属性
    @IBOutlet private weak var m_web: WKWebView!
    @IBOutlet private var m_textView: NSTextView!
    private var isWebViewLoaded = false
    private var urlStr:String? {
        didSet {
            updateJSONView()
        }
    }
    private var jsonString:String? {
        didSet {
            if let str = jsonString {
                m_textView.string = str
            }
            updateJSONView()
        }
    }
   
    
    // MARK: - 生命周期
    public override func viewDidLoad() {
        super.viewDidLoad()
        title = "json预览"
        m_web.navigationDelegate = self
        
        if let json = jsonString {
            m_textView.string = json
            updateJSONView()
        } else if let urlStr = urlStr, let url = URL(string: urlStr)  {
            let  semaphore = DispatchSemaphore (value: 0)
            
            var request = URLRequest(url: url, timeoutInterval: Double.infinity)
     
            request.httpMethod = "GET"
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                guard let data = data else {
                    print(String(describing: error))
                    semaphore.signal()
                    return
                }
                let jsonStr = String(data: data, encoding: .utf8)
                DispatchQueue.main.async {
                    self.jsonString = jsonStr
                }
                
                semaphore.signal()
            }
            
            task.resume()
            semaphore.wait()
        }
       
        
        
        
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
        guard let jsParam = jsonString else {
            return
        }
        let funName = "renderJSONString"
        m_web.evaluateJavaScript("\(funName)(\(jsParam))") { res, error in
            if let error = error {
                print(error.localizedDescription)
            } else if let obj = res as AnyObject?{
                print(obj)
            }
        }
    }
    private func setupWebJSONViewer() {
        guard let filePath = getLibBundle()?.path(forResource: "jsonviewer", ofType: "html") else {return}
        let fileURL = URL(fileURLWithPath: filePath)
        let htmlRequest = URLRequest(url: fileURL)
        m_web?.load(htmlRequest)

    }
    
}
// MARK: - WKNavigationDelegate
extension JSONVC: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        
        
        if !isWebViewLoaded {
            isWebViewLoaded = true
            renderJSONString()
        }
    }
}
// MARK: - NSSplitViewDelegate
extension JSONVC: NSSplitViewDelegate {
    // 最小最大滑动宽度
    public func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        return proposedMinimumPosition + 100
    }
    public func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        return proposedMaximumPosition - 100
    }
}
