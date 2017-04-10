//
//  XMPPController.swift
//  Mangosta
//
//  Created by Andres Canal on 6/29/16.
//  Copyright © 2016 Inaka. All rights reserved.
//

import UIKit
import XMPPFramework
// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}


class XMPPController: NSObject {

    static let sharedInstance = XMPPController()
    
	var xmppStream: XMPPStream
	var xmppReconnect: XMPPReconnect
	var xmppRoster: XMPPRoster
	var xmppRosterStorage: XMPPRosterCoreDataStorage
	var xmppRosterCompletion: RosterCompletion?
	var xmppCapabilities: XMPPCapabilities
	var xmppCapabilitiesStorage: XMPPCapabilitiesCoreDataStorage

    var xmppPubSub: XMPPPubSub
    
	var xmppMUCStorage: XMPPMUCCoreDataStorage
	var xmppMUCStorer: XMPPMUCStorer
	var xmppMessageArchiving: XMPPMessageArchivingWithMAM
	var xmppMessageArchivingStorage: XMPPMessageArchivingCoreDataStorage
	var xmppMessageArchiveManagement: XMPPMessageArchiveManagement
	var xmppRoomLightCoreDataStorage: XMPPRoomLightCoreDataStorage
	var xmppMessageDeliveryReceipts: XMPPMessageDeliveryReceipts
	var xmppMessageCarbons: XMPPMessageCarbons

	var xmppStreamManagement: XMPPStreamManagement
	var xmppStreamManagementStorage: XMPPStreamManagementDiscStorage

	var roomsLight = [XMPPRoomLight]()
    
    // TODO: [pwe] consider dropping XEP-0352 on iOS; the XMPP socket is torn down when going into background anyway
    let xmppClientState: XMPPClientState
    
    let myMicroblogNode = "urn:xmpp:microblog:0"

    var hostPort: UInt16 = 5222
    var password: String = ""
    
    var isXmppConnected = false
		
    override init() {
        self.xmppStream = XMPPStream()
		self.xmppReconnect = XMPPReconnect()

		// Roster
		self.xmppRosterStorage = XMPPRosterCoreDataStorage.sharedInstance()
		self.xmppRoster = XMPPRoster(rosterStorage: self.xmppRosterStorage)
		self.xmppRoster.autoFetchRoster = true
        self.xmppRoster.autoAcceptKnownPresenceSubscriptionRequests = true
		
		// Capabilities
		self.xmppCapabilitiesStorage = XMPPCapabilitiesCoreDataStorage.sharedInstance()
		self.xmppCapabilities = XMPPCapabilities(capabilitiesStorage: self.xmppCapabilitiesStorage)
		self.xmppCapabilities.autoFetchHashedCapabilities = true
		self.xmppCapabilities.autoFetchNonHashedCapabilities = false
        self.xmppCapabilities.myCapabilitiesNode = myMicroblogNode + "+notify"
		
        // PubSub
        self.xmppPubSub = XMPPPubSub(serviceJID: nil, dispatchQueue: DispatchQueue.main) // FIME: use pubsub.erlang-solutions.com ??
        
		// Delivery Receips
		self.xmppMessageDeliveryReceipts = XMPPMessageDeliveryReceipts()
		self.xmppMessageDeliveryReceipts.autoSendMessageDeliveryReceipts = true
		self.xmppMessageDeliveryReceipts.autoSendMessageDeliveryRequests = true

		// Message Carbons
		self.xmppMessageCarbons = XMPPMessageCarbons()
		self.xmppMessageCarbons.autoEnableMessageCarbons = true
		self.xmppMessageCarbons.enable()

		// Stream Managment
		self.xmppStreamManagementStorage = XMPPStreamManagementDiscStorage()
		self.xmppStreamManagement = XMPPStreamManagement(storage: self.xmppStreamManagementStorage)
		self.xmppStreamManagement.autoResume = true

		self.xmppMessageArchiveManagement = XMPPMessageArchiveManagement()

		self.xmppMUCStorage = XMPPMUCCoreDataStorage()
		self.xmppMUCStorer = XMPPMUCStorer(roomStorage: self.xmppMUCStorage)
		
		self.xmppMessageArchivingStorage = XMPPMessageAndMAMArchivingCoreDataStorage.sharedInstance()
		self.xmppMessageArchiving = XMPPMessageArchivingWithMAM(messageArchivingStorage: self.xmppMessageArchivingStorage)
		self.xmppRoomLightCoreDataStorage = XMPPRoomLightCoreDataStorage()
        
        self.xmppClientState = XMPPClientState()

		// Activate xmpp modules
		self.xmppReconnect.activate(self.xmppStream)
		self.xmppRoster.activate(self.xmppStream)
		self.xmppCapabilities.activate(self.xmppStream)
        self.xmppPubSub.activate(self.xmppStream)
		self.xmppMessageDeliveryReceipts.activate(self.xmppStream)
		self.xmppMessageCarbons.activate(self.xmppStream)
		self.xmppStreamManagement.activate(self.xmppStream)
		self.xmppMUCStorer.activate(self.xmppStream)
		self.xmppMessageArchiving.activate(self.xmppStream)
		self.xmppMessageArchiveManagement.activate(self.xmppStream)
        self.xmppClientState.activate(self.xmppStream)
		

		// Stream Settings
		self.xmppStream.startTLSPolicy = XMPPStreamStartTLSPolicy.allowed

		super.init()
		
        // Add delegates
		self.xmppStream.addDelegate(self, delegateQueue: DispatchQueue.main)
        self.xmppRoster.addDelegate(self, delegateQueue: DispatchQueue.main)
		self.xmppStreamManagement.addDelegate(self, delegateQueue: DispatchQueue.main)
        self.xmppReconnect.addDelegate(self, delegateQueue: DispatchQueue.main)
        self.xmppPubSub.addDelegate(self, delegateQueue: DispatchQueue.main)
	}

    func setStreamCredentials(_ hostName: String?, userJID: XMPPJID, hostPort: UInt16 = 5222, password: String) {
        if let host = hostName, hostName?.characters.count > 0 {
            self.xmppStream.hostName = host
        }
        self.xmppStream.myJID = userJID
        self.xmppStream.hostPort = hostPort
        self.password = password
    }
    
	func connect() -> Bool {
        
		if !self.xmppStream.isDisconnected() {
			return true
		}
		
        guard let authModel =  AuthenticationModel.load() else {
            return false
        }

        self.setStreamCredentials(authModel.serverName, userJID: authModel.jid, password: authModel.password)
        
        do {
           try self.xmppStream.connect(withTimeout: XMPPStreamTimeoutNone)
        }
        catch {
            return false
        }
        return true
	}

	func disconnect() {
    
		self.goOffLine()
		self.xmppStream.disconnectAfterSending()
	}

    deinit {
        self.tearDownStream()
    }
    
	func tearDownStream() {
        self.xmppStream.removeDelegate(self)
        self.xmppRoster.removeDelegate(self)
        self.xmppPubSub.removeDelegate(self)
        
		self.roomsLight.forEach { (roomLight) in
			roomLight.deactivate()
		}
        
		self.xmppReconnect.deactivate()
		self.xmppRoster.deactivate()
		self.xmppCapabilities.deactivate()
        
        self.xmppPubSub.deactivate()
		self.xmppMessageDeliveryReceipts.deactivate()
		self.xmppMessageCarbons.deactivate()
		self.xmppStreamManagement.deactivate()
		self.xmppMUCStorer.deactivate()
		self.xmppMessageArchiving.deactivate()
		self.xmppMessageArchiveManagement.deactivate()
        self.xmppClientState.deactivate()
        
        self.disconnect()
        
        self.xmppStream.myJID = nil
        self.xmppStream.hostName = nil
        self.password = ""
	}
}

extension XMPPController: XMPPStreamDelegate {

	func xmppStreamDidConnect(_ stream: XMPPStream!) {
        self.isXmppConnected = true
		
        let user = stream.myJID.bare() as String
		print("Stream: Connected as user: \(user).")
		try! stream.authenticate(withPassword: self.password)
	}

	func xmppStreamDidAuthenticate(_ sender: XMPPStream!) {
		self.xmppStreamManagement.enable(withResumption: true, maxTimeout: 1000)
		print("Stream: Authenticated")
		self.goOnline()
        
	}
	
	func xmppStream(_ sender: XMPPStream!, didNotAuthenticate error: DDXMLElement!) {
		print("Stream: Fail to Authenticate")
	}
	
    func xmppStreamWasTold(toDisconnect sender: XMPPStream!) {
        print("Stream was told to disconnect.")
    }
    
	func xmppStreamDidDisconnect(_ sender: XMPPStream!, withError error: Error!) {
		print("Stream: Disconnected")
        if !self.isXmppConnected {
            print("Unable to connect to server. Check xmppStream.hostName")
          //  self.xmppReconnect.manualStart()
        }
        self.isXmppConnected = false
	}
    
    func xmppStreamDidChangeMyJID(_ xmppStream: XMPPStream!) {
        print("Stream: new JID: \((xmppStream.myJID.bare() as String))")
    }
	
	func goOnline() {
		let presence = XMPPPresence()
		self.xmppStream.send(presence)
        
        xmppClientState.isActive = true
        
        self.createMyPubSubNode()
	}
	
	func goOffLine() {
		let presence = XMPPPresence(type: "unavailable")
		self.xmppStream.send(presence)
        
        xmppClientState.isActive = false
        
	}
    
    func createMyPubSubNode() {
        xmppPubSub.createNode(myMicroblogNode)
    }
}

extension XMPPController: XMPPStreamManagementDelegate {

	func xmppStreamManagement(_ sender: XMPPStreamManagement!, wasEnabled enabled: DDXMLElement!) {
		print("Stream Management: enabled")
	}

	func xmppStreamManagement(_ sender: XMPPStreamManagement!, wasNotEnabled failed: DDXMLElement!) {
		print("Stream Management: not enabled")
	}
	
}

extension XMPPController: XMPPRosterDelegate {
	func xmppStream(_ sender: XMPPStream!, didReceive presence: XMPPPresence!) {
        print("Received presence type \(presence.type()) from \(presence.fromStr())")
    }
	
	func xmppRoster(_ sender: XMPPRoster!, didReceivePresenceSubscriptionRequest presence: XMPPPresence!) {
		print("Roster: Received presence request from user: \((presence.from().bare() as String))")
	}
}

extension XMPPController: XMPPPubSubDelegate {
    func xmppPubSub(_ sender: XMPPPubSub!, didCreateNode node: String!, withResult iq: XMPPIQ!) {
        self.configureNode(node)
        print("PubSub: Did create node")
    }
    func xmppPubSub(_ sender: XMPPPubSub!, didNotCreateNode node: String!, withError iq: XMPPIQ!) {
        self.configureNode(node)
        print("PubSub: Did not create node: \(iq.stringValue)")
    }
    func configureNode(_ node: String) {
        self.xmppPubSub.configureNode(node, withOptions: ["access_model":"presence"])
    }
}

extension XMPPController {
    func managedObjectContext_roster() -> NSManagedObjectContext {
        return self.xmppRosterStorage.mainThreadManagedObjectContext
    }
    
    func managedObjectContext_Capabilities() -> NSManagedObjectContext {
        return self.xmppCapabilitiesStorage.mainThreadManagedObjectContext
    }
    
}
