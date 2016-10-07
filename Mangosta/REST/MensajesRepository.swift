//
//  MensajesRepository.swift
//  Mangosta
//
//  Created by Sergio E. Abraham on 9/26/16.
//  Copyright © 2016 Inaka. All rights reserved.
//


class MessageRepository: CRUDRepository {
	
	typealias EntityType = Message
	let backend = NSURLSessionBackend.MongooseREST()
	let name = "messages"
	
	func sendMessage(entity: EntityType) -> Future<EntityType, JaymeError> {
		let path = self.name
		return self.backend.futureForPath(path, method: .POST, parameters: entity.dictionaryValue)
			.andThen { DataParser().dictionaryFromData($0.0) }
			.andThen { EntityParser().entityFromDictionary($0) }
	}

	func getNMessages(limit: NSNumber?, before: NSNumber?) -> Future<[EntityType], JaymeError> {
		let path = self.name
		var parameters : [String : AnyObject] = [:]
		if let limit = limit {
			 parameters["limit"] = limit
		}
		if let before = before {
			parameters["before"] = before
		}
		return self.backend.futureForPath(path, method: .GET, parameters: parameters)
			.andThen { DataParser().dictionariesFromData($0.0) }
			.andThen { EntityParser().entitiesFromDictionaries($0) }
	}
	
	func getNMessagesWithUser(withJID: String, limit: NSNumber?, before: NSNumber?) -> Future<[EntityType], JaymeError> {
		let path = self.name + "/" + withJID
		var parameters : [String : AnyObject] = [:]
		if let limit = limit {
			parameters["limit"] = limit.integerValue
		}
		if let before = before {
			parameters["before"] = before.longValue
		}
		return self.backend.futureForPath(path, method: .GET, parameters: parameters)
			.andThen { DataParser().dictionariesFromData($0.0) }
			.andThen { EntityParser().entitiesFromDictionaries($0) }
	}
	
}