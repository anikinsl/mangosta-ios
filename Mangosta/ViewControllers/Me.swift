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
		// TODO: when implementing vCard XEP-0054 add the FN field here
		self.accountJID.text = self.xmppController?.xmppStream.myJID.bare()
	}
	@IBAction func signOut(sender: AnyObject) {
		AuthenticationModel.remove()
		self.presentLogInView()
		self.xmppController?.goOffLine()
		self.xmppController?.disconnect()
		let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
		appDelegate.xmppController = nil
		self.xmppController = nil
		#if MangostaREST
			appDelegate.mongooseRESTController = nil
			self.mongooseRESTController = nil
		#endif
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
		
		#if MangostaREST
			self.mongooseRESTController = MongooseAPI()
			appDelegate.mongooseRESTController = self.mongooseRESTController
		#endif

		
		self.navigationController?.popViewControllerAnimated(true)
	}
}