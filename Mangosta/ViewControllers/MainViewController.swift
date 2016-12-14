//
//  ViewController.swift
//  Mangosta
//
//  Created by Tom Ryan on 3/11/16.
//  Copyright © 2016 Inaka. All rights reserved.
//

import UIKit
import XMPPFramework
import MBProgressHUD

class MainViewController: UIViewController {
	@IBOutlet internal var tableView: UITableView!
	var fetchedResultsController: NSFetchedResultsController?
	var activated = true
	weak var xmppController: XMPPController!
	
	#if MangostaREST // TODO: probably better way.
	weak var mongooseRESTController : MongooseAPI!
	#endif
	
	var xmppMUCLight: XMPPMUCLight!
	
	override func viewDidLoad() {
		super.viewDidLoad()

		let addButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Add, target: self, action: #selector(selectChat(_:)))
		let editButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Edit, target: self, action: #selector(editTable(_:)))
		self.navigationItem.rightBarButtonItems = [editButton, addButton]

		
		let logOut = UIBarButtonItem(title: "Log Out", style: UIBarButtonItemStyle.Done, target: self, action: #selector(logOut(_:)))
		self.navigationItem.leftBarButtonItem = logOut
		
		if AuthenticationModel.load() == nil {
			presentLogInView()
		} else {
			configureAndStartXMPP()
		}
		
	}
	
	override func viewWillAppear(animated: Bool) {
		self.xmppMUCLight = XMPPMUCLight()
		self.xmppMUCLight.addDelegate(self, delegateQueue: dispatch_get_main_queue())
		self.xmppMUCLight.activate(self.xmppController.xmppStream)
		
		self.xmppMUCLight.discoverRoomsForServiceNamed("muclight.erlang-solutions.com")

	}
	
	func presentLogInView() {
		let storyboard = UIStoryboard(name: "LogIn", bundle: nil)
		let loginController = storyboard.instantiateViewControllerWithIdentifier("LoginViewController") as! LoginViewController
		loginController.loginDelegate = self
		self.navigationController?.presentViewController(loginController, animated: true, completion: nil)
	}
	
	func configureAndStartXMPP() {

		let authModel = AuthenticationModel.load()!

		self.xmppController = XMPPController(hostName: authModel.serverName!,
		                                     userJID: authModel.jid,
		                                     password: authModel.password)
		
		let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
		appDelegate.xmppController = self.xmppController
		
		xmppController.connect()
		self.setupFetchedResultsController()
		
		#if MangostaREST
			self.mongooseRESTController = MongooseAPI()
			appDelegate.mongooseRESTController = self.mongooseRESTController
		#endif
	}
	
	// TODO: this is for implementing later in the UI: XEP-0352: Client State Indication
	@IBAction func activateDeactivate(sender: UIButton) {
		if activated {
			self.xmppController.xmppStream.sendElement(XMPPElement.indicateInactiveElement())
			self.activated = false
			sender.setTitle("activate", forState: UIControlState.Normal)
		} else {
			self.xmppController.xmppStream.sendElement(XMPPElement.indicateActiveElement())
			self.activated = true
			sender .setTitle("deactivate", forState: UIControlState.Normal)
		}
	}
	
	func logOut(sender: UIBarButtonItem) {
		AuthenticationModel.remove()
		self.presentLogInView()
		self.xmppController.disconnect()
		let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
		appDelegate.xmppController = nil
		self.xmppController = nil
		#if MangostaREST
			appDelegate.mongooseRESTController = nil
			self.mongooseRESTController = nil
		#endif
		
	}
	
	func selectChat(sender: UIBarButtonItem) {
		let alertController = UIAlertController(title: nil, message: "New Chat", preferredStyle: .ActionSheet)
		
		
		let roomChatAction = UIAlertAction(title: "New Room Chat", style: .Default) { (action) in
			let storyboard = UIStoryboard(name: "MUCLight", bundle: nil)
				let roomViewController = storyboard.instantiateViewControllerWithIdentifier("MUCLightCreateRoomPresenterViewController") as! MUCLightCreateRoomPresenterViewController
			self.presentViewController(roomViewController, animated: true, completion: nil)
		}
		alertController.addAction(roomChatAction)
		
		let privateChatAction = UIAlertAction(title: "New Private Chat", style: .Default) { (action) in
			self.createNewFriendChat(sender)
		}
		alertController.addAction(privateChatAction)
		
		let cancelAction = UIAlertAction(title: "Cancel", style: .Destructive) { (action) in
			
		}
		alertController.addAction(cancelAction)
		
		self.presentViewController(alertController, animated: true) {
			
		}
	}
	func createNewFriendChat(sender: UIBarButtonItem) {
		let alertController = UIAlertController.textFieldAlertController("New Conversation", message: "Enter the JID of the user or group name") { (jidString) in
			guard let userJIDString = jidString, userJID = XMPPJID.jidWithString(userJIDString) else { return }
			self.xmppController.xmppRoster.addUser(userJID, withNickname: nil)
		}
		self.presentViewController(alertController, animated: true, completion: nil)
	}
	func editTable(sender: UIBarButtonItem) {
		
	}
	
	internal func setupFetchedResultsController() {

		let rosterContext = self.xmppController.xmppRosterStorage.mainThreadManagedObjectContext
		
		let entity = NSEntityDescription.entityForName("XMPPUserCoreDataStorageObject", inManagedObjectContext: rosterContext)
		let sd1 = NSSortDescriptor(key: "sectionNum", ascending: true)
		let sd2 = NSSortDescriptor(key: "displayName", ascending: true)

		let fetchRequest = NSFetchRequest()
		fetchRequest.entity = entity
		fetchRequest.sortDescriptors = [sd1, sd2]
		self.fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: rosterContext, sectionNameKeyPath: "sectionNum", cacheName: nil)
		self.fetchedResultsController?.delegate = self

		try! self.fetchedResultsController?.performFetch()
		self.tableView.reloadData()
	}
}

extension MainViewController: UITableViewDataSource, UITableViewDelegate {
	func numberOfSectionsInTableView(tableView: UITableView) -> Int {
		if let sections = self.fetchedResultsController?.sections {
			// FIXME: sections from datasource
			return 2
			//return sections.count
		}
		return 0
	}
	func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		let sections = self.fetchedResultsController?.sections
		if section < sections!.count {
			let sectionInfo = sections![section]
			return sectionInfo.numberOfObjects
		}
		else if section == 1 {
			return self.xmppController.roomsLight.count
		}
		return 0
	}
	
	func tableView( tableView : UITableView,  titleForHeaderInSection section: Int) -> String? {
		switch(section) {
		case 1: return "Group chats"
		case 0:return "Private chats"
			
		default :return "Private chats"
			
		}
	}

	func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCellWithIdentifier("Cell") as UITableViewCell!
		
		if indexPath.section == 0 {
		if let user = self.fetchedResultsController?.objectAtIndexPath(indexPath) as? XMPPUserCoreDataStorageObject {
			if let firstResource = user.resources.first {
				if let pres = firstResource.valueForKey("presence") {
					if pres.type == "available" {
						cell.textLabel?.textColor = UIColor.blueColor()
					} else {
						cell.textLabel?.textColor = UIColor.darkGrayColor()
					}
					
				}
			} else {
				cell.textLabel?.textColor = UIColor.darkGrayColor()
			}
			
			cell.textLabel?.text = user.jidStr
		} else {
			cell.textLabel?.text = "nope"
		}
		}
		else if indexPath.section == 1 {
			let room = self.xmppController.roomsLight[indexPath.row]
			cell.textLabel?.text = room.roomname()
		}
		
		return cell
	}
	
	func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
		let user = self.fetchedResultsController?.objectAtIndexPath(indexPath) as! XMPPUserCoreDataStorageObject
		let storyboard = UIStoryboard(name: "Chat", bundle: nil)

		let chatController = storyboard.instantiateViewControllerWithIdentifier("ChatViewController") as! ChatViewController
		chatController.xmppController = self.xmppController
		chatController.userJID = user.jid
		
		self.navigationController?.pushViewController(chatController, animated: true)
		
	}
	
	func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
		return true
	}
	
	func tableView(tableView: UITableView, moveRowAtIndexPath sourceIndexPath: NSIndexPath, toIndexPath destinationIndexPath: NSIndexPath) {
		// TODO: use safe optionals
		let item = self.fetchedResultsController?.objectAtIndexPath(sourceIndexPath)
		var items = self.fetchedResultsController?.fetchedObjects
		items?.removeAtIndex(sourceIndexPath.row)
		items?.insert(item!, atIndex: destinationIndexPath.row)
	}
	
	func tableView(tableView: UITableView, shouldIndentWhileEditingRowAtIndexPath indexPath: NSIndexPath) -> Bool {
		return true
	}

	func tableView(tableView: UITableView, editingStyleForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCellEditingStyle {
		return .None
	}
}

extension MainViewController: NSFetchedResultsControllerDelegate {
	func controllerDidChangeContent(controller: NSFetchedResultsController) {
		self.tableView.reloadData()
	}
}

extension MainViewController: LoginControllerDelegate {
	func didLogIn() {
		self.configureAndStartXMPP() // and MongooseREST API
	}
}

extension MainViewController: XMPPMUCLightDelegate {
	
	func xmppMUCLight(sender: XMPPMUCLight, didDiscoverRooms rooms: [DDXMLElement], forServiceNamed serviceName: String) {
		let storage = self.xmppController.xmppRoomLightCoreDataStorage
		
		self.xmppController.roomsLight.forEach { (room) in
			room.deactivate()
			room.removeDelegate(self)
		}
		
		self.xmppController.roomsLight = rooms.map { (rawElement) -> XMPPRoomLight in
			let rawJid = rawElement.attributeStringValueForName("jid")
			let rawName = rawElement.attributeStringValueForName("name")
			let jid = XMPPJID.jidWithString(rawJid)
			
			let r = XMPPCustomRoomLight(roomLightStorage: storage, jid: jid, roomname: rawName, dispatchQueue: dispatch_get_main_queue())
			r.activate(self.xmppController.xmppStream)
			
			return r
		}
		self.tableView.reloadData()
	}
	
	func xmppMUCLight(sender: XMPPMUCLight, changedAffiliation affiliation: String, roomJID: XMPPJID) {
		self.xmppMUCLight.discoverRoomsForServiceNamed("muclight.erlang-solutions.com")
	}
}

// FIXME: create room
//extension MainViewController: XMPPRoomLightDelegate {
//	
//	func xmppRoomLight(sender: XMPPRoomLight, didCreateRoomLight iq: XMPPIQ) {
//		sender.addUsers(self.newRoomUsers)
//		
//		self.xmppMUCLight.discoverRoomsForServiceNamed("muclight.erlang-solutions.com")
//		self.tableView.reloadData()
//	}
//}

