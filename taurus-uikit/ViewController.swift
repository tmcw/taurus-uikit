//
//  ViewController.swift
//  taurus-uikit
//
//  Created by Tom MacWright on 2/5/21.
//

import Network
import UIKit
import WebKit

class ViewController: UIViewController, WKNavigationDelegate {
    private var tcpStreamAlive: Bool = false
    private var online: Bool = false
    private var page = Page(url: nil, status: PageStatus.none, document: nil, source: "")
    private var content: String = ""

    @IBOutlet var addressBar: UITextField!
    @IBOutlet var webView: WKWebView!

    @IBAction func enteredAddress(_ sender: UITextField) {
        loadUrl(inputUrl: sender.text!)
    }

    private func drawPage() {
        webView.navigationDelegate = self
        webView.loadHTMLString(geminiToHTML(page: page), baseURL: URL(string: "http://localhost"))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        print(navigationAction.request.url)
        if navigationAction.request.url?.absoluteString == "http://localhost/" {
            decisionHandler(.allow)
            return
        }
        if let scheme = navigationAction.request.url?.scheme {
            if scheme == "gemini" {
                loadUrl(inputUrl: navigationAction.request.url!.absoluteString)
                decisionHandler(.cancel)
                return
            }
        }
        decisionHandler(.cancel)
    }

    // https://stackoverflow.com/questions/54452129/how-to-create-ios-nwconnection-for-tls-with-self-signed-cert
    func createTLSParameters(allowInsecure _: Bool, queue: DispatchQueue) -> NWParameters {
        let options = NWProtocolTLS.Options()
        sec_protocol_options_set_verify_block(options.securityProtocolOptions, { _, sec_trust, sec_protocol_verify_complete in
            let trust = sec_trust_copy_ref(sec_trust).takeRetainedValue()
            var error: CFError?
            sec_protocol_verify_complete(true)
            /*
             if SecTrustEvaluateWithError(trust, &error) {
             sec_protocol_verify_complete(true)
             } else {
             if allowInsecure == true {
             sec_protocol_verify_complete(true)
             } else {
             sec_protocol_verify_complete(false)
             }
             }
             */
        }, queue)
        return NWParameters(tls: options)
    }

    private func loadUrl(inputUrl: String) {
        content = ""
        print("turning \(inputUrl) into a url…")
        // TODO: safe unwrap
        let u = URL(string: inputUrl)!

        if u.scheme != "gemini" {
            // Exit
            return
        }
        page.url = URL(string: inputUrl)
        let host = u.host

        let queue = DispatchQueue(label: "taurus")
        let hostEndpoint = NWEndpoint.Host(host!)
        let nwConnection = NWConnection(
            host: hostEndpoint,
            port: 1965,
            using: createTLSParameters(allowInsecure: true, queue: queue)
        )
        nwConnection.stateUpdateHandler = stateDidChange(to:)
        setupReceive(on: nwConnection)

        nwConnection.start(queue: queue)
        print("Sending \(inputUrl) to host")
        nwConnection.send(content: "\(inputUrl)\r\n".data(using: .utf8)!, completion: .contentProcessed { error in
            print("data sent")
            if let error = error {
                print("got error")
                // self.connectionDidFail(error: error)
                return
            }
        })
    }

    private func setupReceive(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
            // Read data off the stream
            if let data = data, !data.isEmpty {
                self.content += String(decoding: data, as: UTF8.self)
            }

            if isComplete {
                connection.cancel()
                self.tcpStreamAlive = false
                self.page.source = self.content
                self.page.document = parseResponse(content: self.content)
            } else if let error = error {
                print("setupReceive: error \(error.localizedDescription)")
            } else {
                self.setupReceive(on: connection)
            }
        }
    }

    private func stateDidChange(to state: NWConnection.State) {
        switch state {
        case .setup:
            notifyDelegateOnChange(newStatusFlag: false, connectivityStatus: "setup")
            tcpStreamAlive = true
        case .waiting:
            notifyDelegateOnChange(newStatusFlag: false, connectivityStatus: "waiting")
            tcpStreamAlive = true
        case .ready:
            notifyDelegateOnChange(newStatusFlag: true, connectivityStatus: "ready")
            tcpStreamAlive = true
        case let .failed(error):
            let errorMessage = "Error: \(error.localizedDescription)"
            notifyDelegateOnChange(newStatusFlag: false, connectivityStatus: errorMessage)
            tcpStreamAlive = false
        case .cancelled:
            notifyDelegateOnChange(newStatusFlag: false, connectivityStatus: "cancelled")
            tcpStreamAlive = false
            drawPage()
        // self.setupNWConnection()
        case .preparing:
            notifyDelegateOnChange(newStatusFlag: false, connectivityStatus: "preparing")
            tcpStreamAlive = true
        }
    }

    private func notifyDelegateOnChange(newStatusFlag: Bool, connectivityStatus: String) {
        if newStatusFlag != online {
            print("newStatusFlag: \(newStatusFlag) - connectivityStatus: // \(connectivityStatus)")
            // self.networkStatusDelegate?.networkStatusChanged(online: newStatusFlag, // connectivityStatus: connectivityStatus)
            online = newStatusFlag
        } else {
            print("connectivityStatus: \(connectivityStatus)")
        }
    }
}
