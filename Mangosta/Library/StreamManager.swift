//
//  StateManager.swift
//  Mangosta
//
//  Created by Tom Ryan on 3/14/16.
//  Copyright © 2016 Inaka. All rights reserved.
//

import Foundation
import XMPPFramework

public class StreamManager : NSObject {
	//MARK: Private variables
	
	//MARK: Public variables
	public var streamController: StreamController?
	public static let manager = StreamManager()
	public var stream: XMPPStream!
	public var authenticationModel: AuthenticationModel?
	public var connectCompletion: VoidCompletion?
	public var onlineJIDs : Set<String>
	public var carbonsEnabled = true
	public var clientState = ClientState()
	
	//MARK: Internal Variables
	internal var isAttemptingConnection = false
	internal var queue: NSOperationQueue
	internal var connectionQueue: NSOperationQueue
	internal var roomStorage: XMPPRoomCoreDataStorage
	
	//MARK: -
	//MARK: Private functions
	private override init() {
		self.queue = NSOperationQueue()
		self.queue.maxConcurrentOperationCount = 1
		self.queue.suspended = true
		
		self.connectionQueue = NSOperationQueue()
		self.connectionQueue.maxConcurrentOperationCount = 2

		self.roomStorage = XMPPRoomCoreDataStorage.sharedInstance()

		self.onlineJIDs = []
		
		super.init()
		
	}
	
	//MARK: Internal functions
	internal func onConnectOrReconnect() {
		self.isAttemptingConnection = false
		self.queue.suspended = false
		
		self.streamController = StreamController(stream: self.stream) { completion in
			print("done")
		}
		
		self.becomeAvailable()
		
		self.connectCompletion?()

		self.connectCompletion = nil
	}
	
	internal func sendClientState(clientState: ClientState.FeatureAvailability) {
		var element: NSXMLElement
		if clientState == ClientState.FeatureAvailability.Available {
			element = NSXMLElement.indicateActiveElement()
		} else {
			element = NSXMLElement.indicateInactiveElement()
		}
		self.sendElement(element)
	}
	
	//MARK: -
	//MARK: Public functions
	public func addOperation(operation: NSOperation) {
		self.queue.addOperation(operation)
	}
	
	public func begin(authentication authentication: AuthenticationModel, completion: VoidCompletion = {}) {
		self.connectCompletion = completion
		
		if self.isAttemptingConnection { return }
		
		self.authenticationModel = authentication
		
		self.isAttemptingConnection = true
		
		let hostName = (self.authenticationModel!.serverName != nil) ? self.authenticationModel!.serverName! : "192.168.100.109"
		
		let connectOperation = StreamOperation.createAndConnectStream(hostName, userJID: self.authenticationModel!.jid, password: self.authenticationModel!.password) { stream in
			if let createdStream = stream {
				self.stream = createdStream
				self.stream.addDelegate(self, delegateQueue: dispatch_get_main_queue())
				
				self.onConnectOrReconnect()
			} else {
				self.isAttemptingConnection = false
			}
			
			
		}
		self.connectionQueue.addOperation(connectOperation)
	}
	
	public func sendElement(element: DDXMLElement, completion: VoidCompletion = {}) {
		if StreamManager.manager.stream == nil {
			StreamManager.manager.begin(authentication: self.authenticationModel!) { finished in
				StreamManager.manager.stream.sendElement(element)
				completion()
			}
		} else {
			StreamManager.manager.stream.sendElement(element)
			completion()
		}
	}
	
	public func disconnect() {
		AuthenticationModel.remove()
		self.sendPresence(false)
		self.isAttemptingConnection = false
		self.streamController!.roster.removeDelegate(self)
		self.streamController?.rosterStorage.clearAllResourcesForXMPPStream(self.stream)
		//self.rosterStorage.clearAllResourcesForXMPPStream(self.stream)
		self.streamController = nil
		
		let disconnectOperation = StreamOperation.disconnectStream(self.stream) { (stream) in
			
			self.stream = nil
		}
		self.addOperation(disconnectOperation)
		
	}
	
	public func sendPresence(available: Bool) {
		let verb = available ? "available" : "unavailable"
		let presence = XMPPPresence(type: verb)
		let priority = DDXMLElement(name: "priority", stringValue: "24")
		presence.addChild(priority)
		StreamManager.manager.sendElement(presence)
		NSNotificationCenter.defaultCenter().postNotificationName(Constants.Notifications.RosterWasUpdated, object: nil)
		StreamManager.manager.clientState.changePresence(available ? ClientState.FeatureAvailability.Available : ClientState.FeatureAvailability.Unavailable)
	}
	
	public func isOnline() -> Bool {
		return self.clientState.presence == ClientState.FeatureAvailability.Available
	}
	
	public func isAvailable() -> Bool {
		return self.clientState.clientAvailability == ClientState.FeatureAvailability.Available
	}
	
	public func toggleCarbons(enabled: Bool) {
		if enabled {
			self.streamController!.messageCarbons.enableMessageCarbons()
		} else {
			self.streamController!.messageCarbons.disableMessageCarbons()
		}
	}
	
	public func messageCarbonsEnabled() -> Bool {
		return self.streamController!.messageCarbons.messageCarbonsEnabled
	}
	
	public func becomeAvailable() {
		self.clientState.changeClientAvailability(ClientState.FeatureAvailability.Available)
		self.sendClientState(ClientState.FeatureAvailability.Available)
	}
	
	public func becomeUnavailable() {
		self.clientState.changeClientAvailability(ClientState.FeatureAvailability.Unavailable)
		self.sendClientState(ClientState.FeatureAvailability.Unavailable)
	}
	
	public func supportsCapability(capability: StreamController.CapabilityTypes) -> Bool {
		guard let controller = self.streamController else {
			return false
		}
		return controller.capabilityTypes.contains(capability)
	}
}

//MARK: -
//MARK: XMPPStreamDelegate
extension StreamManager : XMPPStreamDelegate {
	public func xmppStream(sender: XMPPStream!, didReceiveMessage message: XMPPMessage!) {
		print(message)
	}
	
	public func xmppStreamDidConnect(sender: XMPPStream!) {
		if let stream = sender {
			let authenticationOperation = StreamOperation.authenticateStream(stream, password: self.authenticationModel!.password) { (stream) -> Void in
				if let _ = stream {
					self.onConnectOrReconnect()
				}
			}
			self.connectionQueue.addOperation(authenticationOperation)
		}
	}
	
	public func xmppStreamDidDisconnect(sender: XMPPStream!, withError error: NSError!) {
		self.queue.suspended = true
	}
	
	//MARK: Presence
	public func xmppStream(sender: XMPPStream!, didReceivePresence presence: XMPPPresence!) {
		//if let p = presence, let user = p.from().user where user != self.authenticationModel?.jid.user {
		if let p = presence, let user = p.from().user {
			if p.type() == "available" {
				self.onlineJIDs.insert(user)
			} else {
				self.onlineJIDs.remove(user)
			}
		}
	}
	
	public func xmppStream(sender: XMPPStream!, didReceiveIQ iq: XMPPIQ!) -> Bool {
		print(iq)
		
		return true
	}
	
	public func xmppStream(sender: XMPPStream!, didSendCustomElement element: DDXMLElement!) {
		print("sent custom element: \(element)")
	}
	
	public func xmppStream(sender: XMPPStream!, didReceiveError error: DDXMLElement!) {
		print(error)
	}
}


