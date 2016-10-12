//
//  RestMain.swift
//  Mangosta
//
//  Created by Sergio E. Abraham on 9/26/16.
//  Copyright © 2016 Inaka. All rights reserved.
//

import Foundation
import XMPPFramework

class MIMMainInterface: MIMCommunicable {
	
	func getMessages(limit: Int?, before: CLong?) {
		MessageRepository().getNMessages(nil, before: nil).start() {
			result in
			switch result {
			case .Success(let messageList):
				print("DEBUG MessageList \(messageList)")
				break
			case .Failure(let error):
				print("Error: \(error)")
				break
			}
		}
	}
	
	func sendMessage(xmppMessage: XMPPMessage) {
		let message = Message(id: NSUUID().UUIDString, to: xmppMessage.to().bare(), body: xmppMessage.body())
		MessageRepository().sendMessage(message).start() { result in
			switch result {
			case .Success(let messageSent):
				print("DEBUG Message sent \(messageSent))")
				break
			case .Failure(let error):
				print("Error: \(error)")
				break
			}
		}
	}
	
	func getMessagesWithUser(user: XMPPJID, limit: Int?, before: CLong?) -> [Message] {
		var returnist : [Message] = []
		
		MessageRepository().getNMessagesWithUser(user.bare(), limit: limit, before: before).start() {
			result in
			switch result {
			case .Success(let messageList):
				returnist = messageList
				print ("DEBUG message list \(messageList)")
				break
			case .Failure(let error):
				print("Error: \(error)")
				break
			}
		}
		
		return returnist
	}
	
	func getRooms() -> [Room] {
		var roomList: [Room] = []
		RoomRepository().findAll().start() {
			result in
			switch result {
			case .Success(let rooms):
				print ("DEBUG room list \(rooms)")
				roomList = rooms
				break
			case .Failure(let error):
				print("Error: \(error)")
				break
			}
		}
		return roomList
	}
	
	func getRoomArchivedMessages(room: XMPPRoom, limit: Int?, before: CLong?) -> [Message] {
		var messages: [Message] = []
		let dictionary  : [String:AnyObject] = ["id": room.roomJID.bare(), "subject":room.roomSubject, "name": ""]
		let thisRoom = try? Room(dictionary: dictionary)
		RoomRepository().getMessagesFromRoom(thisRoom!.id, limit: limit, before: before).start() {
			result in
			switch result {
			case .Success(let archivedList):
				print ("DEBUG archive message list \(archivedList)")
				messages = archivedList
				break
			case .Failure(let error):
				print("Error: \(error)")
				break
			}
		}
		return messages
	}
	
	func createRoomWithSubject(room: XMPPRoom, users: [XMPPJID]?){
		let dictionary : [String:AnyObject] = ["id": room.roomJID.bare(), "subject":room.roomSubject, "name": ""]
		let roomToCreate = try? Room(dictionary: dictionary) // FIXME: what is room name here?
		RoomRepository().create(roomToCreate!).start() {
			result in
			switch result {
			case .Success(let roomCreated):
				// TODO: save id
				print("DEBUG roomCreated: \(roomCreated)")
				break
			case .Failure(let error):
				print("Error: \(error)")
				break
			}
		}
	}
	
	func getRoomDetails(room: XMPPRoom) -> Room {
		var detailsDictionary : Room = try! Room(dictionary: [:])
		RoomRepository().findByID(room.roomJID.bare()).start() {
			result in
			switch result {
			case .Success(let details):
				detailsDictionary = details
				break
			case .Failure(let error):
				print("Error: \(error)")
				break
			}
		}
		return detailsDictionary
	}
	
	func inviteUserToRoom(jid: XMPPJID!, withMessage invitationMessage: String!, room: XMPPRoom) {
		let dictionary : [String:AnyObject] = ["id": room.roomJID.bare(), "subject":room.roomSubject, "name": ""]
		let room = try? Room(dictionary: dictionary)
		RoomRepository().addUserToRoom(room!, userJID: jid.bare()).start() {
			result in
			switch result {
			case .Success(let userInvited):
				print("DEBUG userInvited: \(userInvited)")
				break
			case .Failure(let error):
				print("Error: \(error)")
				break
			}
		}
	}
	
	func deleteUserFromRoom(room: XMPPRoom, user: XMPPJID) {
		let dictionary : [String:AnyObject] = ["id": room.roomJID.bare(), "subject":room.roomSubject, "name": ""]
		let thisRoom = try? Room(dictionary: dictionary)
		RoomRepository().deleteUserFromRoom(thisRoom!, userJID: user.bare()).start() {
			result in
			switch result {
			case .Success(let userDeleted):
				print("DEBUG userDeleted: \(userDeleted)")
				break
			case .Failure(let error):
				print("Error: \(error)")
				break
			}
		}
	}
	
	func sendMessageToRoom(room: XMPPRoom, message: XMPPMessage) {
		let dictionary : [String:AnyObject] = ["id": room.roomJID.bare(), "subject":room.roomSubject, "name": ""]
		let thisRoom = try? Room(dictionary: dictionary)
		RoomRepository().sendMessageToRoom(thisRoom!, messageBody: message.body()).start() {
			result in
			switch result {
			case .Success(let messageSent):
				print("DEBUG: messageSent: \(messageSent)")
				break
			case .Failure(let error):
				print("Error: \(error)")
				break
			}
		}
	}
	
}
