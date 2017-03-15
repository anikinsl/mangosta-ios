//
//  AuthenticationModel.swift
//  Mangosta
//
//  Created by Tom Ryan on 3/14/16.
//  Copyright © 2016 Inaka. All rights reserved.
//

import Foundation
import XMPPFramework

public struct AuthenticationModel {
	public let jid: XMPPJID
	public let password: String
	public var serverName: String?
	
	public func save() {
		var dict = [String:String]()
		dict["jid"] = self.jid.bare()
		dict["password"] = self.password
		if let server = self.serverName {
			dict["serverName"] = server
		}
		
		UserDefaults.standard.set(dict, forKey: Constants.Preferences.Authentication)
		UserDefaults.standard.synchronize()
	}
	
	public init(jidString: String, password: String) {
		let myJid = XMPPJID.withString(jidString)
		self.jid = myJid!
		self.password = password
	}
	
	public init(jid: XMPPJID, password: String) {
		self.jid = jid
		self.password = password
	}
	
	public init(jidString: String, serverName: String, password: String) {
		self.jid = XMPPJID.withString(jidString)
		self.serverName = serverName
		self.password = password
	}
	
	static public func load() -> AuthenticationModel? {
		if let authDict = UserDefaults.standard.object(forKey: Constants.Preferences.Authentication) as? [String:String] {
			let authJidString = authDict["jid"]!
			let pass = authDict["password"]!
			
			if let server = authDict["serverName"] {
				return AuthenticationModel(jidString: authJidString, serverName: server, password: pass)
			}
			
			return AuthenticationModel(jid: XMPPJID.withString(authJidString), password: pass)
		}
		return nil
	}
	
	static public func remove() {
		UserDefaults.standard.removeObject(forKey: Constants.Preferences.Authentication)
		UserDefaults.standard.synchronize()
	}
}

