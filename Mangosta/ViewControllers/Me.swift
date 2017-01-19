//
//  Me.swift
//  Mangosta
//
//  Created by Sergio Abraham on 12/30/16.
//  Copyright © 2016 Inaka. All rights reserved.
//

import Foundation

class Me: UITableViewController, LoginControllerDelegate {
	weak var xmppController: XMPPController!
	
	@IBOutlet weak var accountJID: UILabel!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		let appDelegate = UIApplication.sharedApplication().delegate as? AppDelegate
		self.xmppController = appDelegate?.xmppController
		// TODO: when implementing vCard XEP-0054 add the FN field here
		self.accountJID.text = self.xmppController?.xmppStream.myJID.bare()
	}
	@IBAction func signOut(sender: AnyObject) {
		self.xmppController?.disconnect()
		self.presentLogInView()
		let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
		appDelegate.xmppController = nil
		self.xmppController = nil
	}
	
	func presentLogInView() {
		let storyboard = UIStoryboard(name: "LogIn", bundle: nil)
		let loginController = storyboard.instantiateViewControllerWithIdentifier("LoginViewController") as! LoginViewController
		loginController.loginDelegate = self
		
		self.navigationController?.presentViewController(loginController, animated: true, completion: nil
		)
	}
	func didPressLogInButton() {
		let authModel = AuthenticationModel.load()!
		
		self.xmppController = XMPPController(hostName: authModel.serverName!,
		                                     userJID: authModel.jid,
		                                     password: authModel.password)
		
		let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
		appDelegate.xmppController = self.xmppController
		
		xmppController.connect()
		// TODO: fix self.setupDataSources()
		
		self.navigationController?.popViewControllerAnimated(true)
	}
}