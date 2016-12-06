//
//  ChatViewController.swift
//  Mangosta
//
//  Created by Tom Ryan on 3/21/16.
//  Copyright © 2016 Inaka. All rights reserved.
//

import UIKit
import XMPPFramework
import MBProgressHUD

class ChatViewController: NoChatViewController,UIGestureRecognizerDelegate{
	@IBOutlet weak var subject: UILabel!
	@IBOutlet weak var subjectHeight: NSLayoutConstraint!
	
	weak var room: XMPPRoom?
	weak var roomLight: XMPPRoomLight?
	var userJID: XMPPJID?
	var fetchedResultsController: NSFetchedResultsController!
	weak var xmppController: XMPPController!
	var lastID = ""
	
	let MIMCommonInterface = MIMMainInterface()

	let messageLayoutCache = NSCache()

	lazy var titleView: TitleView! = {
		let view = TitleView()
		return view
	}()
	
	lazy var avatarButton: AvatarButton! = {
		let button = AvatarButton()
		return button
	}()
	
	override var title: String? {
		set {
			titleView.titleLabel.text = newValue
		}
		get {
			return titleView.titleLabel.text
		}
	}
	
	override func createPresenterBuilders() -> [ChatItemType: [ChatItemPresenterBuilderProtocol]] {
		return [
		 DateItem.itemType : [
				DateItemPresenterBuider()
			],
			MessageType.Text.rawValue : [
				MessagePresenterBuilder<TextBubbleView, TGTextMessageViewModelBuilder>(
					viewModelBuilder: TGTextMessageViewModelBuilder(),
					layoutCache: messageLayoutCache
				)
			]
		]
	}
	
	override func createChatInputViewController() -> UIViewController {
		let inputController = ChatInputViewController()
		
		inputController.onSendText = { [weak self] text in
			self?.sendText(text)
		}
		
		inputController.onChooseAttach = { [weak self] in
			self?.showAttachSheet()
		}

		return inputController
	}
	
	override func didMoveToParentViewController(parent: UIViewController?) {
		super.didMoveToParentViewController(parent)
		
		if parent != nil && self.navigationItem.titleView == nil {
			
		}
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		self.chatItemsDecorator = TGChatItemsDecorator()
		self.chatDataSource = ChatDataSourceInterface()
		
		var rightBarButtonItems: [UIBarButtonItem] = []

		wallpaperView.image = UIImage(named: "chat_background")!
		
		self.xmppController.xmppMessageArchiveManagement.addDelegate(self, delegateQueue: dispatch_get_main_queue())
		
		if let roomSubject = (userJID?.user ?? self.room?.roomSubject ?? self.roomLight?.roomname()) {
			self.title = "\(roomSubject)"
		}

		// Set up TittleBar
		let tapGesture = UITapGestureRecognizer(target: self, action: #selector(showChangeSubject(_:)))
		self.titleView.userInteractionEnabled = true
		tapGesture.delegate = self
		self.titleView.tapGestureRecognizer = tapGesture
		let button = UIButton.init(type: .Custom)
		button.bounds = self.titleView.frame
		button.addTarget(self, action: #selector(showChangeSubject(_:)), forControlEvents: UIControlEvents.TouchUpOutside)
		self.titleView.addSubview(button)

		
		if self.userJID != nil {
			self.fetchedResultsController = self.createFetchedResultsController()
		} else {
			if let rLight = self.roomLight {
				rLight.addDelegate(self, delegateQueue: dispatch_get_main_queue())
				rLight.getConfiguration()
			}else {
				self.room?.addDelegate(self, delegateQueue: dispatch_get_main_queue())
				self.subjectHeight.constant = 0	
			}

			rightBarButtonItems.append(UIBarButtonItem(title: "Invite", style: UIBarButtonItemStyle.Done, target: self, action: #selector(invite(_:))))
			self.fetchedResultsController = self.createFetchedResultsControllerForGroup()
		}

		self.navigationItem.rightBarButtonItems = rightBarButtonItems
	}
	
	override func viewWillAppear(animated: Bool) {
		// FIXME TapGestureRecognizer
		// Set up TittleBar
		let tapGesture = UITapGestureRecognizer(target: self, action: #selector(showChangeSubject(_:)))
		self.titleView.userInteractionEnabled = true
		tapGesture.delegate = self
		self.titleView.tapGestureRecognizer = tapGesture
		self.titleView.addGestureRecognizer(tapGesture)
		let button = UIButton.init(type: .Custom)
		button.bounds = self.titleView.frame
		button.addTarget(self, action: #selector(showChangeSubject(_:)), forControlEvents: UIControlEvents.TouchUpOutside)
		self.titleView.addSubview(button)
	}
	override func canBecomeFirstResponder() -> Bool {
		return true
	}
	
	
	internal func showChangeSubject(sender: AnyObject?) {
		let alertController = UIAlertController.textFieldAlertController("Subject", message: nil) { (subjectText) in
			if let text = subjectText {
				self.roomLight?.changeRoomSubject(text)
			}
		}
		self.presentViewController(alertController, animated: true, completion: nil)
	}
	
	private func createFetchedResultsControllerForGroup() -> NSFetchedResultsController {
		let groupContext: NSManagedObjectContext!
		let entity: NSEntityDescription?
		
		if self.room != nil {
			groupContext = self.xmppController.xmppMUCStorage.mainThreadManagedObjectContext
			entity = NSEntityDescription.entityForName("XMPPRoomMessageCoreDataStorageObject", inManagedObjectContext: groupContext)
		} else {
			groupContext = self.xmppController.xmppRoomLightCoreDataStorage.mainThreadManagedObjectContext
			entity = NSEntityDescription.entityForName("XMPPRoomLightMessageCoreDataStorageObject", inManagedObjectContext: groupContext)
		}

		let roomJID = (self.room?.roomJID.bare() ?? self.roomLight?.roomJID.bare())!

		let predicate = NSPredicate(format: "roomJIDStr = %@", roomJID)
		let sortDescriptor = NSSortDescriptor(key: "localTimestamp", ascending: true)

		let request = NSFetchRequest()
		request.entity = entity
		request.predicate = predicate
		request.sortDescriptors = [sortDescriptor]

		let controller = NSFetchedResultsController(fetchRequest: request, managedObjectContext: groupContext, sectionNameKeyPath: nil, cacheName: nil)
		controller.delegate = self
		try! controller.performFetch()
		
		return controller
	}
	
	private func createFetchedResultsController() -> NSFetchedResultsController {
		guard let messageContext = self.xmppController.xmppMessageArchivingStorage.mainThreadManagedObjectContext else {
			return NSFetchedResultsController()
		}
		
		let entity = NSEntityDescription.entityForName("XMPPMessageArchiving_Message_CoreDataObject", inManagedObjectContext: messageContext)
		let predicate = NSPredicate(format: "bareJidStr = %@", self.userJID!.bare())
		let sortDescriptor = NSSortDescriptor(key: "timestamp", ascending: false)
		
		let request = NSFetchRequest()
		request.entity = entity
		request.predicate = predicate
		request.sortDescriptors = [sortDescriptor]
		
		let controller = NSFetchedResultsController(fetchRequest: request, managedObjectContext: messageContext, sectionNameKeyPath: nil, cacheName: nil)
		controller.delegate = self
		try! controller.performFetch()
		
		return controller
	}
	
	internal func invite(sender: AnyObject?) {
		let alertController = UIAlertController.textFieldAlertController("Add member", message: "Enter the JID") { (jidString) in
			guard let userJIDString = jidString, userJID = XMPPJID.jidWithString(userJIDString) else { return }

			if self.roomLight != nil {
				self.roomLight!.addUsers([userJID])
			} else {
				self.room!.inviteUser(userJID, withMessage: self.room!.roomSubject)
			}
		}
		self.presentViewController(alertController, animated: true, completion: nil)
	}
	
	@IBAction func showMUCDetails(sender: AnyObject) {

		if self.roomLight != nil {
			self.roomLight!.fetchMembersList()
		} else {
			self.room!.queryRoomItems()
		}
	}

	func showMembersViewController(members: [(String, String)]) {
		let storyboard = UIStoryboard(name: "Members", bundle: nil)

		let membersNavController = storyboard.instantiateViewControllerWithIdentifier("members") as! UINavigationController
		let membersController = membersNavController.viewControllers.first! as! MembersViewController
		membersController.members = members
		self.navigationController?.presentViewController(membersNavController, animated: true, completion: nil)
	}

	@IBAction func fetchFormFields(sender: AnyObject) {
		self.xmppController.xmppMessageArchiveManagement.retrieveFormFields()
	}

	@IBAction func fetchHistory(sender: AnyObject) {
		let jid = self.userJID ?? self.room?.roomJID ?? self.roomLight?.roomJID
		let fields = [XMPPMessageArchiveManagement.fieldWithVar("with", type: nil, andValue: jid!.bare())]
		let resultSet = XMPPResultSet(max: 5, after: self.lastID)
		#if MangostaREST
			// TODO: add before and after
			MIMCommonInterface.getMessagesWithUser(jid!, limit: nil, before: nil)
		#endif
		self.xmppController.xmppMessageArchiveManagement.retrieveMessageArchiveWithFields(fields, withResultSet: resultSet)
	}

	deinit {
		self.room?.removeDelegate(self)
		self.roomLight?.removeDelegate(self)
	}
	
	func sendMessageToServer(lastMessage: NoChatMessage?) {
		
		let receiverJID = self.userJID ?? self.room?.roomJID ?? self.roomLight?.roomJID
		let type = self.userJID != nil ? "chat" : "groupchat"
		let msg = XMPPMessage(type: type, to: receiverJID, elementID: NSUUID().UUIDString)
		
		msg.addBody(lastMessage?.content)
		if type == "chat" {
			self.MIMCommonInterface.sendMessage(msg)
		}
		else {
			// TODO:
			// self.MIMCommonInterface.sendMessageToRoom(self.room!, message: msg)
			self.xmppController.xmppStream.sendElement(msg)
		}
	}
}

// MARK: ChatDataSourceDelegateProtocol

extension ChatViewController: XMPPRoomLightDelegate {
	
	func xmppRoomLight(sender: XMPPRoomLight, didFetchMembersList items: [DDXMLElement]) {
		let members = items.map { (child) -> (String, String) in
			return (child.attributeForName("affiliation").stringValue(), child.stringValue())
		}
		self.showMembersViewController(members)
	}

	func xmppRoomLight(sender: XMPPRoomLight, configurationChanged message: XMPPMessage) {
		self.subject.text = sender.subject()
	}

	func xmppRoomLight(sender: XMPPRoomLight, didGetConfiguration iqResult: XMPPIQ) {
		self.subject.text = sender.subject()
	}
}

extension ChatViewController: XMPPRoomExtraActionsDelegate {
	func xmppRoom(sender: XMPPRoom!, didQueryRoomItems iqResult: XMPPIQ!) {
		let members = iqResult.elementForName("query").children().map { (child) -> (String, String) in
			let ch = child as! DDXMLElement
			return (ch.attributeForName("jid").stringValue(), ch.attributeForName("name").stringValue())
		}
		self.showMembersViewController(members)
	}
}

extension ChatViewController: NSFetchedResultsControllerDelegate {
	// MARK: NSFetchedResultsControllerDelegate
	func controller(controller: NSFetchedResultsController,
	                didChangeObject anObject: AnyObject,
	                                atIndexPath indexPath: NSIndexPath?,
	                                            forChangeType type: NSFetchedResultsChangeType,
	                                                          newIndexPath: NSIndexPath?) {
		// FIXME use the self.tableView.reloadData()
		if let mamMessage = anObject as? XMPPMessageArchiving_Message_CoreDataObject {
			if mamMessage.body != nil && !mamMessage.isOutgoing {
				let message = createTextMessage(text: mamMessage.body, senderId: mamMessage.bareJidStr, isIncoming: true)
				(self.chatDataSource as! ChatDataSourceInterface).addMessages([message])
			}
		}
	}
}

extension ChatViewController: XMPPMessageArchiveManagementDelegate {
	
	func xmppMessageArchiveManagement(xmppMessageArchiveManagement: XMPPMessageArchiveManagement!, didFinishReceivingMessagesWithSet resultSet: XMPPResultSet!) {
		if let lastID = resultSet.elementForName("last")?.stringValue() {
			self.lastID = lastID
		}
	}

	func xmppMessageArchiveManagement(xmppMessageArchiveManagement: XMPPMessageArchiveManagement!, didReceiveFormFields iq: XMPPIQ!) {
		let fields = iq.childElement().elementForName("x").elementsForName("field").map { (field) -> String in
			let f = field as! NSXMLElement
			return "\(f.attributeForName("var").stringValue()!) \(f.attributeForName("type").stringValue()!)"
		}.joinWithSeparator("\n")
		
		let alertController = UIAlertController(title: "Forms", message: fields, preferredStyle: UIAlertControllerStyle.Alert)
		alertController.addAction(UIAlertAction(title: "OK", style: .Cancel, handler: nil))
		self.presentViewController(alertController, animated: true, completion: nil)
	}
}

extension ChatViewController {
	
	func createTextMessage(text text: String, senderId: String, isIncoming: Bool) -> NoChatMessage {
		let message = createMessage(senderId, isIncoming: isIncoming, msgType: MessageType.Text.rawValue)
		message.content = text
		return message
	}


	func sendText(text: String) {
		  let message = createTextMessage(text: text, senderId: "outgoing", isIncoming: false)
		
		// TODO: implement queing offline messages.
		(self.chatDataSource as! ChatDataSourceInterface).addMessages([message])
		
		self.sendMessageToServer(message)
	}
	
	func showAttachSheet() {
		let sheet = UIAlertController(title: "Choose attachment", message: "", preferredStyle: .ActionSheet)
		
		sheet.addAction(UIAlertAction(title: "Camera", style: .Default, handler: { _ in
		}))
		
		sheet.addAction(UIAlertAction(title: "Photos", style: .Default, handler: { _ in
		}))
		
		sheet.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
		
		presentViewController(sheet, animated: true, completion: nil)
	}

	func createMessage(senderId: String, isIncoming: Bool, msgType: String) -> NoChatMessage {
		let message = NoChatMessage(
			msgId: NSUUID().UUIDString,
			msgType: msgType,
			senderId: senderId,
			isIncoming: isIncoming,
			date: NSDate(),
			deliveryStatus: .Delivering,
			attachments: [],
			content: ""
		)
		
		return message
	}
	

}


