//
//  AppDelegate.swift
//  UPImage
//
//  Created by Pro.chen on 16/7/10.
//  Copyright © 2016年 chenxt. All rights reserved.
//

import Cocoa
import MASPreferences
import TMCache
import Carbon

func checkImageFile(pboard: NSPasteboard) -> Bool {
	
	let files: NSArray = pboard.propertyListForType(NSFilenamesPboardType) as! NSArray
	let image = NSImage(contentsOfFile: files.firstObject as! String)
	guard let _ = image else {
		return false
	}
	return true
}

var autoUp: Bool {
	get {
		if let autoUp = NSUserDefaults.standardUserDefaults().valueForKey("autoUp") {
			return autoUp as! Bool
		}
		return false
	}
	set {
		NSUserDefaults.standardUserDefaults().setValue(newValue, forKey: "autoUp")
	}
}

var appDelegate: NSObject?

var statusItem: NSStatusItem!

var imagesCacheArr: [[String: AnyObject]] = Array()

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
	
	let pasteboardObserver = PasteboardObserver()
	
	@IBOutlet weak var MarkdownItem: NSMenuItem!
	@IBOutlet weak var window: NSWindow!
	
	@IBOutlet weak var statusMenu: NSMenu!
	@IBOutlet weak var cacheImageMenu: NSMenu!
	
	@IBOutlet weak var autoUpItem: NSMenuItem!
	@IBOutlet weak var uploadMenuItem: NSMenuItem!
	
	@IBOutlet weak var cacheImageMenuItem: NSMenuItem!
	lazy var preferencesWindowController: NSWindowController = {
		
		let imageViewController = ImagePreferencesViewController()
		let generalViewController = GeneralViewController()
		let controllers = [generalViewController, imageViewController]
		let wc = MASPreferencesWindowController(viewControllers: controllers, title: "设置")
		imageViewController.window = wc.window
		return wc
	}()
	
	func applicationDidFinishLaunching(aNotification: NSNotification) {
		
		registerHotKeys()
		
		// 重置Token
		
		if linkType == 0 {
			MarkdownItem.state = 1
		} else {
			MarkdownItem.state = 0
		}
		
		pasteboardObserver.addSubscriber(self)
		
		if autoUp {
			
			pasteboardObserver.startObserving()
			autoUpItem.state = 1
			
		}
		
		NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(notification), name: "MarkdownState", object: nil)
		
		window.center()
		appDelegate = self
		statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(NSSquareStatusItemLength)
		let statusBarButton = DragDestinationView(frame: (statusItem.button?.bounds)!)
		statusItem.button?.superview?.addSubview(statusBarButton, positioned: .Below, relativeTo: statusItem.button)
		let iconImage = NSImage(named: "StatusIcon")
		iconImage?.template = true
		statusItem.button?.image = iconImage
		statusItem.button?.action = #selector(showMenu)
		statusItem.button?.target = self
		
	}
	
	func notification(notification: NSNotification) {
		
		if notification.object?.intValue == 0 {
			MarkdownItem.state = 1
		}
		else {
			MarkdownItem.state = 0
		}
		
	}
	
	func applicationWillTerminate(aNotification: NSNotification) {
		// Insert code here to tear down your application
	}
	
	func showMenu() {
		
		let pboard = NSPasteboard.generalPasteboard()
		let files: NSArray? = pboard.propertyListForType(NSFilenamesPboardType) as? NSArray
		
		if let files = files {
			let i = NSImage(contentsOfFile: files.firstObject as! String)
			i?.scalingImage()
			uploadMenuItem.image = i
			
		} else {
			let i = NSImage(pasteboard: pboard)
			i?.scalingImage()
			uploadMenuItem.image = i
			
		}
		
		let object = TMCache.sharedCache().objectForKey("imageCache")
		if let obj = object as? [[String: AnyObject]] {
			imagesCacheArr = obj
			
		}
		cacheImageMenuItem.submenu = makeCacheImageMenu(imagesCacheArr)
		
		statusItem.popUpStatusItemMenu(statusMenu)
	}
	
	@IBAction func statusMenuClicked(sender: NSMenuItem) {
		switch sender.tag {
			// 上传
		case 1:
			let pboard = NSPasteboard.generalPasteboard()
			QiniuUpload(pboard)
			// 设置
		case 2:
			preferencesWindowController.showWindow(nil)
			preferencesWindowController.window?.center()
			NSApp.activateIgnoringOtherApps(true)
		case 3:
			// 退出
			NSApp.terminate(nil)
			
		case 4:
			NSWorkspace.sharedWorkspace().openURL(NSURL(string: "http://lzqup.com")!)
		case 5:
			break
			
		case 6:
			
			if sender.state == 0 {
				sender.state = 1
				pasteboardObserver.startObserving()
				autoUp = true
			}
			else {
				sender.state = 0
				pasteboardObserver.stopObserving()
				autoUp = false
			}
			
		case 7:
			if sender.state == 0 {
				sender.state = 1
				linkType = 0
				guard let imagesCache = imagesCacheArr.first else {
					return
				}
				NSPasteboard.generalPasteboard().clearContents()
				var picUrl = imagesCache["url"] as! String
				let fileName = NSString(string: picUrl).lastPathComponent
				picUrl = "![" + fileName + "](" + picUrl + ")"
				NSPasteboard.generalPasteboard().setString(picUrl, forType: NSStringPboardType)
				
			}
			else {
				sender.state = 0
				linkType = 1
				guard let imagesCache = imagesCacheArr.first else {
					return
				}
				NSPasteboard.generalPasteboard().clearContents()
				let picUrl = imagesCache["url"] as! String
				NSPasteboard.generalPasteboard().setString(picUrl, forType: NSStringPboardType)
				
			}
			
		default:
			break
		}
		
	}
	
	@IBAction func btnClick(sender: NSButton) {
		switch sender.tag {
		case 1:
			NSWorkspace.sharedWorkspace().openURL(NSURL(string: "http://blog.lzqup.com/tools/2016/07/10/Tools-UPImage.html")!)
			self.window.close()
		case 2:
			self.window.close()
			
		default:
			break
		}
	}
	
	func makeCacheImageMenu(imagesArr: [[String: AnyObject]]) -> NSMenu {
		let menu = NSMenu()
		if imagesArr.count == 0 {
			let item = NSMenuItem(title: "没有历史", action: nil, keyEquivalent: "")
			menu.addItem(item)
		} else {
			for index in 0..<imagesArr.count {
				let item = NSMenuItem(title: "", action: #selector(cacheImageClick(_:)), keyEquivalent: "")
				item.tag = index
				let i = imagesArr[index]["image"] as? NSImage
				i?.scalingImage()
				item.image = i
				menu.insertItem(item, atIndex: 0)
			}
		}
		
		return menu
	}
	
	func cacheImageClick(sender: NSMenuItem) {
		
		NSPasteboard.generalPasteboard().clearContents()
		
		var picUrl = imagesCacheArr[sender.tag]["url"] as! String
		
		let fileName = NSString(string: picUrl).lastPathComponent
		
		if linkType == 0 {
			picUrl = "![" + fileName + "](" + picUrl + ")"
		}
		
		NSPasteboard.generalPasteboard().setString(picUrl, forType: NSStringPboardType)
		NotificationMessage("图片链接获取成功", isSuccess: true)
		
	}
	
}

extension AppDelegate: NSUserNotificationCenterDelegate, PasteboardObserverSubscriber {
	// 强行通知
	func userNotificationCenter(center: NSUserNotificationCenter, shouldPresentNotification notification: NSUserNotification) -> Bool {
		return true
	}
	
	override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String: AnyObject]?, context: UnsafeMutablePointer<Void>) {
		
		print(change)
		
	}
	
	func pasteboardChanged(pasteboard: NSPasteboard) {
		QiniuUpload(pasteboard)
		
	}
	
	func registerHotKeys() {
		
		var gMyHotKeyRef: EventHotKeyRef = nil
		var gMyHotKeyIDU = EventHotKeyID()
		var gMyHotKeyIDM = EventHotKeyID()
		var eventType = EventTypeSpec()
		
		eventType.eventClass = OSType(kEventClassKeyboard)
		eventType.eventKind = OSType(kEventHotKeyPressed)
		gMyHotKeyIDU.signature = OSType(32)
		gMyHotKeyIDU.id = UInt32(kVK_ANSI_U);
		gMyHotKeyIDM.signature = OSType(46);
		gMyHotKeyIDM.id = UInt32(kVK_ANSI_M);
		
		RegisterEventHotKey(UInt32(kVK_ANSI_U), UInt32(cmdKey), gMyHotKeyIDU, GetApplicationEventTarget(), 0, &gMyHotKeyRef)
		
		RegisterEventHotKey(UInt32(kVK_ANSI_M), UInt32(controlKey), gMyHotKeyIDM, GetApplicationEventTarget(), 0, &gMyHotKeyRef)
		
		// Install handler.
		InstallEventHandler(GetApplicationEventTarget(), { (nextHanlder, theEvent, userData) -> OSStatus in
			var hkCom = EventHotKeyID()
			GetEventParameter(theEvent, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, sizeof(EventHotKeyID), nil, &hkCom)
			switch hkCom.id {
			case UInt32(kVK_ANSI_U):
				let pboard = NSPasteboard.generalPasteboard()
				QiniuUpload(pboard)
			case UInt32(kVK_ANSI_M):
				if linkType == 0 {
					linkType = 1
					NSNotificationCenter.defaultCenter().postNotificationName("MarkdownState", object: 1)
					guard let imagesCache = imagesCacheArr.last else {
						return 33
					}
					NSPasteboard.generalPasteboard().clearContents()
					let picUrl = imagesCache["url"] as! String
					NSPasteboard.generalPasteboard().setString(picUrl, forType: NSStringPboardType)
					
				}
				else {
					linkType = 0
					NSNotificationCenter.defaultCenter().postNotificationName("MarkdownState", object: 0)
					guard let imagesCache = imagesCacheArr.last else {
						return 33
					}
					NSPasteboard.generalPasteboard().clearContents()
					var picUrl = imagesCache["url"] as! String
					let fileName = NSString(string: picUrl).lastPathComponent
					picUrl = "![" + fileName + "](" + picUrl + ")"
					NSPasteboard.generalPasteboard().setString(picUrl, forType: NSStringPboardType)
				}
			default:
				break
			}
			
			return 33
			/// Check that hkCom in indeed your hotkey ID and handle it.
			}, 1, &eventType, nil, nil)
		
	}
	
}

