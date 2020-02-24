//
//  FirstViewController.swift
//  Tabbed Viewer
//
//  Created by Jordan Stiles on 2/14/20.
//  Copyright © 2020 Jordan Stiles. All rights reserved.
//

import UIKit

class FirstViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var userInput1: UITextField!
    @IBOutlet weak var userInput2: UITextField!
    @IBOutlet weak var userInput3: UITextField!
    @IBOutlet weak var userInput4: UITextField!
    @IBOutlet weak var userInput5: UITextField!
    
    var surnameTextField: UITextField!
    
    override func viewDidLoad() {
    }
}

//extension FirstViewController: UITextFieldDelegate {
//    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
//        return true
//    }
    
//}

