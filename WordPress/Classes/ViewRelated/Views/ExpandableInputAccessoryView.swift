//
//  ExpandableInputAccessoryView.swift
//  WordPress
//
//  Created by Nathan Glass on 8/25/19.
//  Copyright © 2019 WordPress. All rights reserved.
//

import Foundation
import UIKit

@objc class ProgrammaticExpandableInputAccessoryView: UIView, ExpandableInputAccessoryViewDelegate {
    
    let expandableInputAccessoryView = ExpandableInputAccessoryView.loadFromNib()
    private var topConstraint: NSLayoutConstraint?
    private var heightConstraint: NSLayoutConstraint?

    @objc init(parentDelegate: ExpandableInputAccessoryViewParentDelegate) {
        super.init(frame: CGRect.zero)
        prepareSubviews(parentDelegate: parentDelegate)
    }
    
    @objc func updatePlaceholder(text: String) {
        self.expandableInputAccessoryView.placeholerLabel.text = text
    }
    func didMoveTo(_ state: ExpandableInputAccessoryView.ExpandedState) {
        switch state {
        case .fullScreen:
            if topConstraint == nil {
                topConstraint = self.topAnchor.constraint(equalTo: self.window!.safeAreaLayoutGuide.topAnchor)
            }
//            heightConstraint = self.heightAnchor.constraint(equalToConstant: 300.0)
//            heightConstraint?.isActive = true
            topConstraint?.isActive = true
        case .normal:
            heightConstraint?.isActive = false
            topConstraint?.isActive = false
        }
    }
    
    @objc func replaceTextAtCaret(_ text: NSString?, withText replacement: String?) {
        expandableInputAccessoryView.replaceTextAtCaret(text, withText: replacement)
    }
    
    @objc func resignResponder() {
        expandableInputAccessoryView.textView.resignFirstResponder()
    }
    
    @objc func becomeResponder() {
        expandableInputAccessoryView.textView.becomeFirstResponder()
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    override var intrinsicContentSize: CGSize {
        return CGSize(width: self.bounds.width, height: expandableInputAccessoryView.intrinsicContentSize.height)
    }
    
    private func prepareSubviews(parentDelegate: ExpandableInputAccessoryViewParentDelegate) {
        expandableInputAccessoryView.translatesAutoresizingMaskIntoConstraints = false
        expandableInputAccessoryView.delegate = self
        expandableInputAccessoryView.parentDelegate = parentDelegate
        self.addSubview(expandableInputAccessoryView)
        self.autoresizingMask = .flexibleHeight
        NSLayoutConstraint(item: expandableInputAccessoryView, attribute: .top, relatedBy: .equal, toItem: self, attribute: .top, multiplier: 1.0, constant: 0).isActive = true
        NSLayoutConstraint(item: expandableInputAccessoryView, attribute: .leading, relatedBy: .equal, toItem: self, attribute: .leading, multiplier: 1.0, constant: 0).isActive = true
        NSLayoutConstraint(item: expandableInputAccessoryView, attribute: .trailing, relatedBy: .equal, toItem: self, attribute: .trailing, multiplier: 1.0, constant: 0).isActive = true
        NSLayoutConstraint(item: expandableInputAccessoryView, attribute: .bottom, relatedBy: .equal, toItem: self, attribute: .bottom, multiplier: 1.0, constant: 0).isActive = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

protocol ExpandableInputAccessoryViewDelegate: class {
    func didMoveTo(_ state: ExpandableInputAccessoryView.ExpandedState)
}

@objc protocol ExpandableInputAccessoryViewParentDelegate: class {
    func expandableInputAccessoryViewDidBeginEditing()
    func expandableInputAccessoryViewDidEndEditing()
    func didExpandTextView()
    func didCollapseTextView()
    func sendReply(with content: String)
    @objc optional func textView(_ textView: UITextView, didTypeWord word: String)
}

class ExpandableInputAccessoryView: UIView, NibLoadable {
    enum ExpandedState {
        case fullScreen
        case normal
    }
    
    struct TextViewConstraintStore {
        var leading: CGFloat
        var trailing: CGFloat
        var top: CGFloat
    }
    
    @IBOutlet weak var dividerViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var dividerView: UIView!
    @IBOutlet weak var headerLabel: UILabel!
    @IBOutlet weak var textViewTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var textViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var textViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var placeholerLabel: UILabel!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var expandButton: UIButton!
    @IBOutlet weak var expandButtonBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var expandButtonTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var textView: UITextView! {
        didSet {
            textView.delegate = self
        }
    }
    weak var delegate: ExpandableInputAccessoryViewDelegate?
    weak var parentDelegate: ExpandableInputAccessoryViewParentDelegate?
    var isExpanded = false
    var explicityCollapsed = false
    var wasAutomatticallyExpanded = false
    let expandedTextViewConstraints = TextViewConstraintStore(leading: 10.0, trailing: 4.0, top: 50.0)
    var collapsedTextViewConstraints = TextViewConstraintStore(leading: 45.0, trailing: 60.0, top: 6.0)
    private let sendButtonDisabledTintColor = UIColor(red: 150/255, green: 156/255, blue: 161/255, alpha: 1.0)
    private let sendButtonEnabledTintColor = UIColor(red: 213/255, green: 44/255, blue: 130/255, alpha: 1.0)
    private let expandButtonCollapsedTransform = CGAffineTransform(rotationAngle: CGFloat.pi)
    
    override func awakeFromNib() {
        super.awakeFromNib()
        prepareViews()
    }
    
    override var intrinsicContentSize: CGSize {
        let textSize = self.textView.sizeThatFits(CGSize(width: self.textView.bounds.width, height: CGFloat.greatestFiniteMagnitude))
        return CGSize(width: self.bounds.width, height: textSize.height)
    }
    
    @IBAction func expandButtonTapped(_ sender: UIButton) {
        if !isExpanded {
            expandToFullScreen()
        } else {
            collapseTextView()
        }
    }
    @IBAction func sendButtonTapped(_ sender: UIButton) {
        guard let content = textView.text, !content.isEmpty else { return }
        parentDelegate?.sendReply(with: content)
    }

    @objc func replaceTextAtCaret(_ text: NSString?, withText replacement: String?) {
        guard let replacementText = replacement,
            let textToReplace = text,
            let selectedRange = textView.selectedTextRange,
            let newPosition = textView.position(from: selectedRange.start, offset: -textToReplace.length),
            let newRange = textView.textRange(from: newPosition, to: selectedRange.start) else {
                return
        }
        
        textView.replace(newRange, withText: replacementText)
    }
    
    override var canBecomeFirstResponder: Bool { return true }
    
    fileprivate func expandToFullScreen(automatically: Bool = false) {
        isExpanded = true
        wasAutomatticallyExpanded = automatically
        delegate?.didMoveTo(.fullScreen)
        parentDelegate?.didExpandTextView()
        expandButtonBottomConstraint.isActive = false
        expandButtonTopConstraint.isActive = true
        UIView.animate(withDuration: 0.2) {
            self.textViewTrailingConstraint.constant = self.expandedTextViewConstraints.trailing
            self.textViewLeadingConstraint.constant = self.expandedTextViewConstraints.leading
            self.textViewTopConstraint.constant = self.expandedTextViewConstraints.top
            self.dividerViewTopConstraint.constant = 44.0
            self.headerLabel.alpha = 1
            self.expandButton.transform = .identity
            self.superview?.setNeedsLayout()
            self.superview?.layoutIfNeeded()
        }
    }
    fileprivate func collapseTextView() {
        isExpanded = false
        if wasAutomatticallyExpanded {
            explicityCollapsed = true
        }
        delegate?.didMoveTo(.normal)
        parentDelegate?.didCollapseTextView()
        expandButtonBottomConstraint.isActive = true
        expandButtonTopConstraint.isActive = false
        UIView.animate(withDuration: 0.2) {
            self.topAnchor.constraint(equalTo: self.window!.safeAreaLayoutGuide.topAnchor).isActive = false
            self.textViewTrailingConstraint.constant = self.collapsedTextViewConstraints.trailing
            self.textViewLeadingConstraint.constant = self.collapsedTextViewConstraints.leading
            self.textViewTopConstraint.constant = self.collapsedTextViewConstraints.top
            self.dividerViewTopConstraint.constant = 0
            self.headerLabel.alpha = 0
            self.expandButton.transform = self.expandButtonCollapsedTransform
            self.superview?.setNeedsLayout()
            self.superview?.layoutIfNeeded()
        }
    }

    private func prepareViews() {
        autoresizingMask = .flexibleHeight
        
        headerLabel.alpha = 0
        sendButton.tintColor = sendButtonDisabledTintColor
        expandButton.transform = expandButtonCollapsedTransform
        
        if let image = expandButton.image(for: .normal) {
            expandButton.setImage(image.withRenderingMode(.alwaysTemplate), for: .normal)
            expandButton.tintColor = UIColor.darkGray
        }
    }

    private func displaySendButton() {
        sendButton.isHidden = false
        UIView.animate(withDuration: 0.3) {
            self.sendButton.alpha = 1.0
        }
    }
    
    private func hideSendButton() {
        UIView.animate(withDuration: 0.3, animations: {
            self.sendButton.alpha = 0
        }) { _ in
            self.sendButton.isHidden = true
        }
    }
}

extension ExpandableInputAccessoryView: UITextViewDelegate {
    // MARK: TextView delegates
    func textViewDidBeginEditing(_ textView: UITextView) {
        parentDelegate?.expandableInputAccessoryViewDidBeginEditing()
        displaySendButton()
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        parentDelegate?.expandableInputAccessoryViewDidEndEditing()
        hideSendButton()
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let textViewText: NSString = textView.text as NSString
        let prerange = NSMakeRange(0, range.location)
        let pretext = textViewText.substring(with: prerange) + text
        let words = pretext.components(separatedBy: CharacterSet.whitespacesAndNewlines)
        let lastWord: NSString = words.last! as NSString
        
        parentDelegate?.textView?(textView, didTypeWord: lastWord as String)
        
        return true
    }
    
    func textViewDidChange(_ textView: UITextView) {
        // Re-calculate intrinsicContentSize when text changes
        placeholerLabel.isHidden = !textView.text.isEmpty
        sendButton.tintColor = textView.text.isEmpty ? sendButtonDisabledTintColor : sendButtonEnabledTintColor
        if let fontLineHeight = self.textView.font?.lineHeight {
            let numLines = Int(self.textView.contentSize.height / fontLineHeight)
            if numLines > 4 && !self.isExpanded && !explicityCollapsed {
                self.expandToFullScreen(automatically: true)
            } else {
                UIView.animate(withDuration: 0.2) {
                    self.invalidateIntrinsicContentSize()
                    self.superview?.setNeedsLayout()
                    self.superview?.layoutIfNeeded()
                }
            }
        }
    }
}
