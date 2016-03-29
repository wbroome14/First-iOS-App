//
//  ChatViewController.swift
//  BCChat
//
//  Created by Brian Wang on 3/9/16.
//  Copyright © 2016 BC. All rights reserved.
//

import UIKit
import Firebase
import SwiftyJSON
import FBSDKShareKit
import FBSDKLoginKit
import FBSDKCoreKit

class ChatViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    //===========================================================================
    //MARK: - VARIABLES
    //===========================================================================
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var messageField: UITextField!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var containerViewBottom: NSLayoutConstraint!
    var name:String = ""
    var fbid:String = ""
    var root = Firebase(url: "https://bootcampchat.firebaseio.com")
    var token: FBSDKAccessToken!
    var authData:FAuthData!
    var sortedMessages:[Message] = [] {
        didSet {
            self.sortedMessages.sortInPlace({ leftMessage, rightMessage in
                let leftDate = leftMessage.date()
                let rightDate = rightMessage.date()
                return leftDate > rightDate
            })
            reloadTable()
        }
    }
    
    //===========================================================================
    //MARK: - SETUP
    //===========================================================================
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //tableView Setup
        tableView.delegate = self
        tableView.dataSource = self
        
        //rotate the tableView upside down so that messages appear from bottom-top, not top-bottom
        tableView.transform = CGAffineTransformMakeRotation(CGFloat(-M_PI))
        
        //makes it so that row height is dynamic for each cell, which wraps around the text.
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 60
        
        //TapGesture Setup
        self.view.userInteractionEnabled = true
        let gesture = UITapGestureRecognizer(target: self, action: Selector("touchReceived:"))
        self.view.addGestureRecognizer(gesture)
        
        //Keyboard Notifications
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardDidAppear:", name: UIKeyboardWillChangeFrameNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardDidDisappear", name: UIKeyboardWillHideNotification, object: nil)
    }
   
    //every time the view loads up, load up messages
    override func viewWillAppear(animated: Bool) {
        receiveMessages()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    //===========================================================================
    //MARK: - FIREBASE
    //===========================================================================
    
    func receiveMessages() {
        //query for every message. This block gets called for each individual message
        let messageRoot = root.childByAppendingPath("messages")
        messageRoot.observeEventType(.ChildAdded, withBlock: { snapshot in
         //code in block does not get called before code after block
            var m = Message()
            m.uid = snapshot.value["uid"] as! String
            m.timeStamp = String(snapshot.value["timestamp"])
            m.message = snapshot.value["message"] as! String
            let usersRoot = self.root.childByAppendingPath("users/\(m.uid)")
            usersRoot.observeEventType(.Value, withBlock: {snapshot2 in
                if snapshot2 != nil {
                    print("snapshot2 is \(snapshot2)")
                    print("snapshot2.name is \(snapshot2.value["name"])")
                    print("comparison is \(snapshot2.value["name"] != nil)")
                    if (snapshot2.value["name"] != nil) {
                        m.name = String(snapshot2.value["name"])
                    }
                    if snapshot2.value["platform"] != nil {
                        m.platform = String(snapshot2.value["platform"])
                    }
                }
                self.sortedMessages.append(m)
            })
        })
        //after you get uid from message, query for name and platform from users/{uid from message}
        
    }

    @IBAction func sendMessage(sender: UIButton) {
        //check if message is empty
        if messageField.text == "" {
            shakeMessageFieldX()
            return
        }
        //add message
        let messageRoot = root.childByAppendingPath("messages")
        let mymessageRoot = messageRoot.childByAutoId()
        let post = [
            "uid" : authData.uid,
            "timestamp" : FirebaseServerValue.timestamp(),
            "message" : messageField.text!
        ]
        mymessageRoot.setValue(post)
        //add user
        let uidRoot = root.childByAppendingPath("users/\(authData.uid)")
        let user = [
            //get name from fb, set from last loginviewcontroller
            "name" : self.name,
            "platform" : "ios"
        ]
        uidRoot.setValue(user)
        //clear message
        messageField.text = ""
    }
    
    
    //===========================================================================
    //MARK: - KEYBOARD
    //===========================================================================
    
    //removes keyboard when touched
    func touchReceived(gesture:UITapGestureRecognizer) {
        let touch = gesture.locationInView(self.view)
        if !CGRectContainsPoint(containerView.frame, touch) {
            messageField.resignFirstResponder()
        }
    }
    
    //keyboard appearing animation
    //makes messageField and Send button visible above keyboard
    func keyboardDidAppear(notification:NSNotification) {
        if let userInfo = notification.userInfo, frame = (userInfo[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.CGRectValue {
            let height = frame().height
            UIView.animateWithDuration(0.3, animations: {
                self.containerViewBottom.constant = height
                self.view.layoutIfNeeded()
            })
            scrollToBottom()
        }
    }
    
    //keyboard disappearing animation
    //makes messageField and Send button back to the bottom of screen.
    func keyboardDidDisappear() {
        UIView.animateWithDuration(0.3, animations: {
            self.containerViewBottom.constant = 0
            self.view.layoutIfNeeded()
        })
        scrollToBottom()
    }
}

extension ChatViewController {
    
    //===========================================================================
    //MARK: - TABLE VIEW
    //===========================================================================
    
    //creates a message for how ever many messages there are. This function gets called for each index.
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        //IMPLEMENT ME
        let cell = tableView.dequeueReusableCellWithIdentifier("ChatCell", forIndexPath: indexPath) as! ChatTableViewCell
        //get message from sorted messages
        cell.backgroundColor = UIColor(red: 0.81, green: 0.71, blue: 0.23, alpha: 1)
        cell.nameLabel.textColor = UIColor.whiteColor()
        cell.messageLabel.textColor = UIColor.whiteColor()
        cell.dateLabel.textColor = UIColor.whiteColor()
        
        let index = indexPath.row
        let m = sortedMessages[index]
        
        cell.nameLabel.text = m.name
        cell.dateLabel.text = m.dateString()
        cell.messageLabel.text = m.message
        if (m.uid == authData.uid) {
            cell.backgroundColor = UIColor.blueColor()
            cell.nameLabel.textColor = UIColor.whiteColor()
            cell.messageLabel.textColor = UIColor.whiteColor()
            cell.dateLabel.textColor = UIColor.whiteColor()
        }
        
        cell.transform = CGAffineTransformMakeRotation(CGFloat(M_PI))
        return cell
        
    }
    
    //returns number of messages
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        //IMPLEMENT ME
        return sortedMessages.count
    }
    
    //animates the table every time the table is reloaded
    func reloadTable() {
        tableView.reloadData()
        scrollToBottom()
    }
    
    //===========================================================================
    //MARK: - ANIMATIONS
    //===========================================================================
    
    //shakes on an message error
    func shakeMessageFieldX() {
        let animations:[CGFloat] = [20.0, -20.0, 10.0, -10.0, 3.0, -3.0, 0.0]
        
        for i in 0..<animations.count {
            let frameOrigin = CGPointMake(self.messageField.frame.origin.x + animations[i], self.messageField.frame.origin.y)
            UIView.animateWithDuration(0.075, delay: 0.075 * Double(i), usingSpringWithDamping: 1.0, initialSpringVelocity: 0, options: [], animations: {
                self.messageField.frame.origin = frameOrigin
                self.view.layoutIfNeeded()
                }, completion: nil)
        }
    }
    
    //scrolls the table to the bottom of the messages.
    func scrollToBottom() {
        if sortedMessages.isEmpty {
            return
        }
        let indexPath = NSIndexPath(forItem: 0, inSection: 0)
        tableView.scrollToRowAtIndexPath(indexPath, atScrollPosition: .Top, animated: true)
    }
    
}

