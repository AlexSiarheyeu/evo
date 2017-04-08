import UIKit
import WebKit
import Down
import Crashlytics
import SafariServices

class ProposalDetailViewController: BaseViewController {
    
    // MARK: - IBOutlet connections
    @IBOutlet private weak var detailView: UIView!
    
    // MARK: - Private properties
    private var downView: DownView? = nil
    fileprivate var appDelegate: AppDelegate?
    
    // MARK: - Public properties
    var proposal: Proposal? = nil
    
    // MARK: - Life cycle
    override func viewDidLoad() {
        super.viewDidLoad()

        self.appDelegate = UIApplication.shared.delegate as? AppDelegate
        
        self.rotate = true
        self.title = proposal?.description
        
        self.downView = try? DownView(frame: self.detailView.bounds, markdownString: "")
        self.downView?.navigationDelegate = self
        
        if let downView = self.downView {
            self.detailView.addSubview(downView)
            downView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                downView.topAnchor.constraint(equalTo: self.detailView.topAnchor),
                downView.bottomAnchor.constraint(equalTo: self.detailView.bottomAnchor),
                downView.leadingAnchor.constraint(equalTo: self.detailView.leadingAnchor),
                downView.trailingAnchor.constraint(equalTo: self.detailView.trailingAnchor)
            ])
        }
        
        self.getProposalDetail()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Networking
    fileprivate func getProposalDetail() {
        guard let proposal = self.proposal else {
            return
        }
        
        EvolutionService.detail(proposal: proposal) { [unowned self] error, data in
            guard error == nil, let data = data else {
                if let error = error {
                    Crashlytics.sharedInstance().recordError(error)
                }

                return
            }
            
            Answers.logContentView(withName: "Proposal Detail",
                                   contentType: "Load Detail from server",
                                   contentId: self.proposal?.link,
                                   customAttributes: nil)
            
            DispatchQueue.main.async {
                try? self.downView?.update(markdownString: data) {
                    print("Finished")
                }
            }
        }
    }
    
    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.destination is ProposalDetailViewController,
            let destination = segue.destination as? ProposalDetailViewController,
            sender != nil, let item = sender as? Proposal  {

            destination.proposal = item
        }   
        else if segue.destination is ProfileViewController,
            let destination = segue.destination as? ProfileViewController,
            sender != nil, sender is Person, let person = sender as? Person {
            
            destination.profile = person
        }
    }
}

extension ProposalDetailViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        if navigationAction.navigationType == .linkActivated {
            guard let url = navigationAction.request.url, let proposal = self.proposal else {
                decisionHandler(.allow)
                return
            }
            
            let lastPathComponent = url.lastPathComponent
            
            // Extract proposal info from selected anchor
            if url.path.hasSuffix(".md") {
                let list = lastPathComponent.components(separatedBy: "-")
                
                if let first = list.first, list.count > 0 {
                    
                    // Only load if the proposal touched isn't the same presented
                    if let id = Int(first), id != proposal.id {
                        let proposal = Proposal(id: id, link: lastPathComponent)
                        
                        Config.Segues.proposalDetail.performSegue(in: self, with: proposal)
                    }
                }
                    
                // In case of url lastPathComponent has .md suffix and it isn't a proposal
                else {
                    let safariViewController = SFSafariViewController(url: url, entersReaderIfAvailable: false)
                    self.present(safariViewController, animated: true)
                }
            }
            
            // Check if the link is an author/review manager, if yes, send user to profile screen
            else if let host = url.host, host.contains("github.com"),
                let person = self.appDelegate?.people.get(username: lastPathComponent) {

                Config.Segues.profile.performSegue(in: self, with: person)
            }
                
            // The last step is check only if the url "appears" to be correct, before try to send it to safari
            else if let scheme = url.scheme, ["http", "https"].contains(scheme.lowercased()) {
                let safariViewController = SFSafariViewController(url: url, entersReaderIfAvailable: false)
                self.present(safariViewController, animated: true)
            }
            
            decisionHandler(.cancel)
            return
        }
        
        decisionHandler(.allow)
    }
}
