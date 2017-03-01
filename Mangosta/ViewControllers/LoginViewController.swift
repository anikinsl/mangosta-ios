//
//  LoginViewController.swift
//  Mangosta
//
//  Created by Tom Ryan on 3/21/16.
//  Copyright © 2016 Inaka. All rights reserved.
//

import UIKit
import XMPPFramework
import MBProgressHUD

class LoginViewController: UIViewController {
	@IBOutlet private var jidField: UITextField!
	@IBOutlet private var passwordField: UITextField!
	@IBOutlet private var serverNameField: UITextField!
    @IBOutlet weak var errorLabel: UILabel!
    
	var loginDelegate: LoginControllerDelegate?
    weak var xmppController: XMPPController!
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
	@IBAction func logIn(sender: AnyObject?) {
		if let serverText = self.serverNameField.text {
			let auth = AuthenticationModel(jidString: self.jidField.text!, serverName: serverText, password: self.passwordField.text!)
			auth.save()
		} else {
			let auth = AuthenticationModel(jidString: self.jidField.text!, password: self.passwordField.text!)
			auth.save()
		}
        

        self.configureAndStartXMPP()

	}
    
    func configureAndStartXMPP() {
        
        let authModel = AuthenticationModel.load()!
        
        self.xmppController = XMPPController(hostName: authModel.serverName!,
                                             userJID: authModel.jid,
                                             password: authModel.password)
        
        self.xmppController.xmppStream.addDelegate(self, delegateQueue: dispatch_get_main_queue())
        
        // TODO: revert to UIActivityIndicatorView.
        let hud = MBProgressHUD.showHUDAddedTo(self.view, animated: true)
        hud.labelText = "Please wait"
        
        self.xmppController.connect()
        
    }
    
    func showError(errorString: String?) {
        if let errorText = errorString {
            self.errorLabel.text = "Error: \(errorText)"
        }
        else {
            self.errorLabel.text = nil
        }
    }

    // TODO: Deactivated until Landscape rotation is supported.
    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.Portrait
    }
}

protocol LoginControllerDelegate {
	func didPressLogInButton()
}

extension LoginViewController: XMPPStreamDelegate {
    func xmppStream(sender: XMPPStream!, didNotAuthenticate error: DDXMLElement!) {
        self.showError(error.children?.first?.name)
        MBProgressHUD.hideHUDForView(self.view, animated: true)
    }
    func xmppStreamDidAuthenticate(sender: XMPPStream!) {
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        appDelegate.window?.rootViewController = nil
        
        let tabBarRootController = UIStoryboard(name: "Main", bundle: NSBundle.mainBundle())
        self.dismissViewControllerAnimated(true, completion: {
            appDelegate.window?.rootViewController = tabBarRootController.instantiateInitialViewController()
            appDelegate.window!.makeKeyAndVisible()
        })
        
    }
    func xmppStreamDidDisconnect(sender: XMPPStream!, withError error: NSError!) {
        self.showError(error.localizedDescription)
        MBProgressHUD.hideHUDForView(self.view, animated: true)
    }
}
