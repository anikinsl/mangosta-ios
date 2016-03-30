//
//  ViewController.swift
//  Mangosta
//
//  Created by Tom Ryan on 3/11/16.
//  Copyright © 2016 Inaka. All rights reserved.
//

import UIKit
import XMPPFramework

class MainViewController: UIViewController {
	@IBOutlet internal var tableView: UITableView!
	var fetchedResultsController: NSFetchedResultsController?
	
	override func viewDidLoad() {
		super.viewDidLoad()
		self.title = "Roster"
		
		self.startup()
		
	}
	
	internal func setupFetchedResultsController() {
		if self.fetchedResultsController != nil {
			self.fetchedResultsController = nil
		}
		if let context = StreamManager.manager.rosterStorage.mainThreadManagedObjectContext {
			let entity = NSEntityDescription.entityForName("XMPPUserCoreDataStorageObject", inManagedObjectContext: context)
			let sd1 = NSSortDescriptor(key: "sectionNum", ascending: true)
			let sd2 = NSSortDescriptor(key: "displayName", ascending: true)
			
			let fetchRequest = NSFetchRequest()
			fetchRequest.entity = entity
			fetchRequest.sortDescriptors = [sd1, sd2]
			self.fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: "sectionNum", cacheName: nil)
			self.fetchedResultsController?.delegate = self
			
			try! self.fetchedResultsController?.performFetch()
			
			let objects = self.fetchedResultsController?.fetchedObjects
			print(objects)
		}
		
	}
	
	internal func logout(sender: AnyObject?) {
		StreamManager.manager.disconnect()
		
		self.startup()
		
		
	}
	
	internal func showSettings(sender: AnyObject?) {
		let settingsController = self.storyboard?.instantiateViewControllerWithIdentifier("SettingsViewController")
		let navController = UINavigationController(rootViewController: settingsController!)
		
		self.navigationController?.presentViewController(navController, animated: true, completion: nil)
	}
	
	internal func login(sender: AnyObject?) {
		let loginController = self.storyboard?.instantiateViewControllerWithIdentifier("LoginViewController") as! LoginViewController
		loginController.loginDelegate = self
		self.navigationController?.presentViewController(loginController, animated: true, completion: nil)
	}

	private func startup() {
		var logButton: UIBarButtonItem = UIBarButtonItem()
		
		if let auth = AuthenticationModel.load() {
			StreamManager.manager.begin() { finished in
				if let rooms = StreamManager.manager.fetchedResultsController.fetchedObjects {
					print(rooms)
				}
			}
			logButton = UIBarButtonItem(title: "Log Out", style: UIBarButtonItemStyle.Done, target: self, action: #selector(logout(_:)))
		} else {
			logButton = UIBarButtonItem(title: "Log In", style: UIBarButtonItemStyle.Done, target: self, action: #selector(login(_:)))
		}
		self.navigationItem.leftBarButtonItem = logButton
		
		let settingsButton = UIBarButtonItem(title: "Settings", style: UIBarButtonItemStyle.Done, target: self, action: #selector(showSettings(_:)))
		self.navigationItem.rightBarButtonItem = settingsButton
		
		self.setupFetchedResultsController()
	}
}

extension MainViewController: UITableViewDataSource, UITableViewDelegate {
	func numberOfSectionsInTableView(tableView: UITableView) -> Int {
		if let sections = self.fetchedResultsController?.sections {
			return sections.count
		}
		return 0
	}
	func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		let sections = self.fetchedResultsController?.sections
		if section < sections!.count {
			let sectionInfo = sections![section]
			return sectionInfo.numberOfObjects
		}
		return 0
	}
	func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCellWithIdentifier("Cell") as UITableViewCell!
		
		let user = self.fetchedResultsController?.objectAtIndexPath(indexPath) as! XMPPUserCoreDataStorageObject
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
		return cell
	}
	
	func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
		let user = self.fetchedResultsController?.objectAtIndexPath(indexPath) as! XMPPUserCoreDataStorageObject
		
		let chatController = self.storyboard?.instantiateViewControllerWithIdentifier("ChatViewController") as! ChatViewController!
		chatController.userJID = user.jid
		
		self.navigationController?.pushViewController(chatController, animated: true)
		
	}
}

extension MainViewController: NSFetchedResultsControllerDelegate {
	func controllerDidChangeContent(controller: NSFetchedResultsController) {
		self.tableView.reloadData()
	}
}

extension MainViewController: LoginControllerDelegate {
	func didLogIn() {
		self.startup()
	}
}

