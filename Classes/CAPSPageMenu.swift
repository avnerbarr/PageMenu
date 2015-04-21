//  CAPSPageMenu.swift
//
//  Niklas Fahl
//
//  Copyright (c) 2014 The Board of Trustees of The University of Alabama All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
//
//  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
//
//  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
//
//  Neither the name of the University nor the names of the contributors may be used to endorse or promote products derived from this software without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
//  PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
//  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
//  NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import UIKit

@objc public protocol CAPSPageMenuDelegate {
    // MARK: - Delegate functions
    
    optional func willMoveToPage(controller: UIViewController, index: Int)
    optional func didMoveToPage(controller: UIViewController, index: Int)
}

protocol Math {
    func half()->Double
    func half()->CGFloat
}

extension Double : Math {
    func half() -> Double {
        return self/2.0
    }
    func half() -> CGFloat {
        return CGFloat(self)/2.0
    }
}

extension CGFloat : Math {
    func half() -> Double {
        return Double(self)/2.0
    }
    func half() -> CGFloat {
        return self/2.0
    }
}

class MenuItemView: UIView {
    // MARK: - Menu item view
    
    var titleLabel : UILabel?
    var menuItemSeparator : UIView?

    func setUpMenuItemView(menuItemWidth: CGFloat, menuScrollViewHeight: CGFloat, indicatorHeight: CGFloat, separatorPercentageHeight: CGFloat, separatorWidth: CGFloat, separatorRoundEdges: Bool, menuItemSeparatorColor: UIColor) {
        titleLabel = UILabel(frame: CGRectMake(0.0, 0.0, menuItemWidth, menuScrollViewHeight - indicatorHeight))
        titleLabel?.numberOfLines = 2
        titleLabel?.adjustsFontSizeToFitWidth = true
        titleLabel?.minimumScaleFactor = 0.5;
        menuItemSeparator = UIView(frame: CGRectMake(menuItemWidth - separatorWidth.half(), floor(menuScrollViewHeight * ((1.0 - separatorPercentageHeight) / 2.0)), separatorWidth, floor(menuScrollViewHeight * separatorPercentageHeight)))
        menuItemSeparator!.backgroundColor = menuItemSeparatorColor
        
        if separatorRoundEdges {
            menuItemSeparator!.layer.cornerRadius = menuItemSeparator!.frame.width / 2
        }
        
        menuItemSeparator!.hidden = true
        self.addSubview(menuItemSeparator!)
        
        self.addSubview(titleLabel!)
    }
    
    func setTitleText(text: NSString) {
        if titleLabel != nil {
            titleLabel!.text = text as String
            titleLabel!.numberOfLines = 0
            titleLabel!.sizeToFit()
        }
    }
}

// MARK: - CAPSPageMenuOptions
public struct CAPSPageMenuOptions {
    enum BarPosition {
        case Top
        case Bottom
    }
    var selectionIndicatorHeight : CGFloat = 3.0
    var menuItemSeparatorWidth : CGFloat = 0.5
    lazy var scrollMenuBackgroundColor : UIColor = UIColor.blackColor()
    lazy var viewBackgroundColor : UIColor = UIColor.whiteColor()
    lazy var bottomMenuHairlineColor : UIColor = UIColor.whiteColor()
    lazy var selectionIndicatorColor : UIColor = UIColor(red: 0, green: 122/255.0, blue: 1, alpha: 1)
    lazy var menuItemSeparatorColor : UIColor = UIColor.lightGrayColor()
    var menuMargin : CGFloat = 15.0
    var menuHeight : CGFloat = 55.0 {
        didSet {
            hideTopMenuBar = menuHeight == 0
        }
    }
    lazy var selectedMenuItemLabelColor : UIColor = UIColor(red: 0, green: 122/255.0, blue: 1, alpha: 1)
    lazy var unselectedMenuItemLabelColor : UIColor = UIColor(red: 69/255.0, green: 69/255.0, blue: 76/255.0, alpha: 1)
    var useMenuLikeSegmentedControl : Bool = false
    var menuItemSeparatorRoundEdges : Bool = false
    lazy var menuItemFont : UIFont = UIFont.systemFontOfSize(15.0)
    var menuItemSeparatorPercentageHeight : CGFloat = 0.2
    var menuItemWidth : CGFloat = 111.0
    var enableHorizontalBounce : Bool = false
    var addBottomMenuHairline : Bool = true
    var menuItemWidthBasedOnTitleTextWidth : Bool = false
    var scrollAnimationDurationOnMenuItemTap : NSTimeInterval = 0.5
    var centerMenuItems : Bool = false
    var hideTopMenuBar : Bool = false {
        didSet {
            if (hideTopMenuBar) {
                menuHeight = 0.0
            }
        }
    }
    var barPosition = BarPosition.Top
}

public class CAPSPageMenu: UIViewController, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    
    // MARK: - Properties
    
    private let menuScrollView = UIScrollView()
    private let controllerScrollView = UIScrollView()
    private(set) var controllerArray : [UIViewController] = []
    private var menuItems : [MenuItemView] = []
    private var menuItemWidths : [CGFloat] = []
    private var pageMenuOptions = CAPSPageMenuOptions()
    private var totalMenuItemWidthIfDifferentWidths : CGFloat = 0.0
    private var startingMenuMargin : CGFloat = 0.0
    private var selectionIndicatorView : UIView = UIView()
    private(set) var currentPageIndex : Int = 0
    private var lastPageIndex : Int = 0
    private var currentOrientationIsPortrait : Bool = true
    private var pageIndexForOrientationChange : Int = 0
    private var didLayoutSubviewsAfterRotation : Bool = false
    private var didScrollAlready : Bool = false
    private var lastControllerScrollViewContentOffset : CGFloat = 0.0
    private var lastScrollDirection : CAPSPageMenuScrollDirection = .Other
    private var startingPageForScroll : Int = 0
    private var didTapMenuItemToScroll : Bool = false
    private var pagesAddedDictionary : [Int : Int] = [:]
    
    public weak var delegate : CAPSPageMenuDelegate?
    
    private var tapTimer : NSTimer?
    
    enum CAPSPageMenuScrollDirection : Int {
        case Left
        case Right
        case Other
    }
    
   // MARK: - View life cycle
    
    /**
    Initialize PageMenu with view controllers
    
    :param: viewControllers List of view controllers that must be subclasses of UIViewController
    :param: frame Frame for page menu view
    :param: initOptions customization options user might want to set
    */
    
    public init(viewControllers : [UIViewController],frame: CGRect,initOptions : CAPSPageMenuOptions) {
        super.init(nibName: nil, bundle: nil)
        controllerArray = viewControllers
        self.view.frame = frame
        self.pageMenuOptions = initOptions
        setUpUserInterface()
        if menuScrollView.subviews.count == 0 {
            configureUserInterface()
        }
        
    }
    required public init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    // MARK: - UI Setup
    
    func setUpUserInterface() {
        let viewsDictionary = ["menuScrollView":menuScrollView, "controllerScrollView":controllerScrollView]
        
        // Set up controller scroll view
        controllerScrollView.pagingEnabled = true
        controllerScrollView.setTranslatesAutoresizingMaskIntoConstraints(false)
        controllerScrollView.alwaysBounceHorizontal = pageMenuOptions.enableHorizontalBounce
        controllerScrollView.bounces = pageMenuOptions.enableHorizontalBounce
        
        controllerScrollView.frame = CGRectMake(0.0, pageMenuOptions.menuHeight, self.view.frame.width, self.view.frame.height - pageMenuOptions.menuHeight)
        self.view.addSubview(controllerScrollView)
        
        let controllerScrollView_constraint_H:Array = NSLayoutConstraint.constraintsWithVisualFormat("H:|[controllerScrollView]|", options: NSLayoutFormatOptions(0), metrics: nil, views: viewsDictionary)
        let controllerScrollView_constraint_V:Array = NSLayoutConstraint.constraintsWithVisualFormat("V:|[controllerScrollView]|", options: NSLayoutFormatOptions(0), metrics: nil, views: viewsDictionary)
        
        self.view.addConstraints(controllerScrollView_constraint_H)
        self.view.addConstraints(controllerScrollView_constraint_V)
        
        // Set up menu scroll view
        menuScrollView.setTranslatesAutoresizingMaskIntoConstraints(false)
        
        menuScrollView.frame = CGRectMake(0.0, 0.0, self.view.frame.width, pageMenuOptions.menuHeight)
        
        self.view.addSubview(menuScrollView)

        let menuScrollView_constraint_H:Array = NSLayoutConstraint.constraintsWithVisualFormat("H:|[menuScrollView]|", options: NSLayoutFormatOptions(0), metrics: nil, views: viewsDictionary)
        let menuScrollView_constraint_V:Array = NSLayoutConstraint.constraintsWithVisualFormat("V:[menuScrollView(\(pageMenuOptions.menuHeight))]", options: NSLayoutFormatOptions(0), metrics: nil, views: viewsDictionary)
        
        self.view.addConstraints(menuScrollView_constraint_H)
        self.view.addConstraints(menuScrollView_constraint_V)
        
        // Add hairline to menu scroll view
        if pageMenuOptions.addBottomMenuHairline {
            var menuBottomHairline : UIView = UIView()
            
            menuBottomHairline.setTranslatesAutoresizingMaskIntoConstraints(false)
            
            self.view.addSubview(menuBottomHairline)
            
            let menuBottomHairline_constraint_H:Array = NSLayoutConstraint.constraintsWithVisualFormat("H:|[menuBottomHairline]|", options: NSLayoutFormatOptions(0), metrics: nil, views: ["menuBottomHairline":menuBottomHairline])
            let menuBottomHairline_constraint_V:Array = NSLayoutConstraint.constraintsWithVisualFormat("V:|-\(pageMenuOptions.menuHeight)-[menuBottomHairline(0.5)]", options: NSLayoutFormatOptions(0), metrics: nil, views: ["menuBottomHairline":menuBottomHairline])
            
            self.view.addConstraints(menuBottomHairline_constraint_H)
            self.view.addConstraints(menuBottomHairline_constraint_V)
            
            menuBottomHairline.backgroundColor = pageMenuOptions.bottomMenuHairlineColor
        }
        
        // Disable scroll bars
        menuScrollView.showsHorizontalScrollIndicator = false
        menuScrollView.showsVerticalScrollIndicator = false
        controllerScrollView.showsHorizontalScrollIndicator = false
        controllerScrollView.showsVerticalScrollIndicator = false
        
        // Set background color behind scroll views and for menu scroll view
        self.view.backgroundColor = pageMenuOptions.viewBackgroundColor
        menuScrollView.backgroundColor = pageMenuOptions.scrollMenuBackgroundColor
    }
    
    func configureUserInterface() {
        // Add tap gesture recognizer to controller scroll view to recognize menu item selection
        let menuItemTapGestureRecognizer = UITapGestureRecognizer(target: self, action: Selector("handleMenuItemTap:"))
        menuItemTapGestureRecognizer.numberOfTapsRequired = 1
        menuItemTapGestureRecognizer.numberOfTouchesRequired = 1
        menuItemTapGestureRecognizer.delegate = self
        menuScrollView.addGestureRecognizer(menuItemTapGestureRecognizer)
        
        // Set delegate for controller scroll view
        controllerScrollView.delegate = self
        
        // When the user taps the status bar, the scroll view beneath the touch which is closest to the status bar will be scrolled to top,
        // but only if its `scrollsToTop` property is YES, its delegate does not return NO from `shouldScrollViewScrollToTop`, and it is not already at the top.
        // If more than one scroll view is found, none will be scrolled.
        // Disable scrollsToTop for menu and controller scroll views so that iOS finds scroll views within our pages on status bar tap gesture.
        menuScrollView.scrollsToTop = false;
        controllerScrollView.scrollsToTop = false;
        
        // Configure menu scroll view
        if pageMenuOptions.useMenuLikeSegmentedControl {
            menuScrollView.scrollEnabled = false
            menuScrollView.contentSize = CGSizeMake(self.view.frame.width, pageMenuOptions.menuHeight)
            pageMenuOptions.menuMargin = 0.0
        } else {
            menuScrollView.contentSize = CGSizeMake((pageMenuOptions.menuItemWidth + pageMenuOptions.menuMargin) * CGFloat(controllerArray.count) + pageMenuOptions.menuMargin, pageMenuOptions.menuHeight)
        }
        
        // Configure controller scroll view content size
        controllerScrollView.contentSize = CGSizeMake(self.view.frame.width * CGFloat(controllerArray.count), 0.0)
        
        var index : CGFloat = 0.0
        
        for controller in controllerArray {
            if controller.isKindOfClass(UIViewController) {
                if index == 0.0 {
                    // Add first two controllers to scrollview and as child view controller
                    (controller as UIViewController).viewWillAppear(true)
                    addPageAtIndex(0)
                    (controller as UIViewController).viewDidAppear(true)
                }
                
                // Set up menu item for menu scroll view
                var menuItemFrame : CGRect = CGRect()
                
                if pageMenuOptions.useMenuLikeSegmentedControl {
                    menuItemFrame = CGRectMake(self.view.frame.width / CGFloat(controllerArray.count) * CGFloat(index), 0.0, CGFloat(self.view.frame.width) / CGFloat(controllerArray.count), pageMenuOptions.menuHeight)
                } else if pageMenuOptions.menuItemWidthBasedOnTitleTextWidth {
                    var controllerTitle = controller.title
                    
                    var titleText : String = controllerTitle != nil ? controllerTitle! : "Menu \(Int(index) + 1)"
                    
                    var itemWidthRect : CGRect = (titleText as NSString).boundingRectWithSize(CGSizeMake(1000, 1000), options: NSStringDrawingOptions.UsesLineFragmentOrigin, attributes: [NSFontAttributeName:pageMenuOptions.menuItemFont], context: nil)
                    
                    pageMenuOptions.menuItemWidth = itemWidthRect.width
                    
                    menuItemFrame = CGRectMake(totalMenuItemWidthIfDifferentWidths + pageMenuOptions.menuMargin + (pageMenuOptions.menuMargin * index), 0.0, pageMenuOptions.menuItemWidth, pageMenuOptions.menuHeight)
                    
                    totalMenuItemWidthIfDifferentWidths += itemWidthRect.width
                    menuItemWidths.append(itemWidthRect.width)
                } else {
                    if pageMenuOptions.centerMenuItems && index == 0.0  {
                        startingMenuMargin = ((self.view.frame.width - ((CGFloat(controllerArray.count) * pageMenuOptions.menuItemWidth) + (CGFloat(controllerArray.count - 1) * pageMenuOptions.menuMargin))) / 2.0) -  pageMenuOptions.menuMargin
                        
                        if startingMenuMargin < 0.0 {
                            startingMenuMargin = 0.0
                        }
                        
                        menuItemFrame = CGRectMake(startingMenuMargin + pageMenuOptions.menuMargin, 0.0, pageMenuOptions.menuItemWidth, pageMenuOptions.menuHeight)
                    } else {
                        menuItemFrame = CGRectMake(pageMenuOptions.menuItemWidth * index + pageMenuOptions.menuMargin * (index + 1) + startingMenuMargin, 0.0, pageMenuOptions.menuItemWidth, pageMenuOptions.menuHeight)
                    }
                }
                
                var menuItemView : MenuItemView = MenuItemView(frame: menuItemFrame)
                if pageMenuOptions.useMenuLikeSegmentedControl {
                    menuItemView.setUpMenuItemView(CGFloat(self.view.frame.width) / CGFloat(controllerArray.count), menuScrollViewHeight: pageMenuOptions.menuHeight, indicatorHeight: pageMenuOptions.selectionIndicatorHeight, separatorPercentageHeight: pageMenuOptions.menuItemSeparatorPercentageHeight, separatorWidth: pageMenuOptions.menuItemSeparatorWidth, separatorRoundEdges: pageMenuOptions.menuItemSeparatorRoundEdges, menuItemSeparatorColor: pageMenuOptions.menuItemSeparatorColor)
                } else {
                    menuItemView.setUpMenuItemView(pageMenuOptions.menuItemWidth, menuScrollViewHeight: pageMenuOptions.menuHeight, indicatorHeight: pageMenuOptions.selectionIndicatorHeight, separatorPercentageHeight: pageMenuOptions.menuItemSeparatorPercentageHeight, separatorWidth: pageMenuOptions.menuItemSeparatorWidth, separatorRoundEdges: pageMenuOptions.menuItemSeparatorRoundEdges, menuItemSeparatorColor: pageMenuOptions.menuItemSeparatorColor)
                }
                
                // Configure menu item label font if font is set by user
                menuItemView.titleLabel!.font = pageMenuOptions.menuItemFont
                
                menuItemView.titleLabel!.textAlignment = NSTextAlignment.Center
                menuItemView.titleLabel!.textColor = pageMenuOptions.unselectedMenuItemLabelColor
                
                // Set title depending on if controller has a title set
                if controller.title != nil {
                    menuItemView.titleLabel!.text = controller.title!
                } else {
                    menuItemView.titleLabel!.text = "Menu \(Int(index) + 1)"
                }
                
                // Add separator between menu items when using as segmented control
                if pageMenuOptions.useMenuLikeSegmentedControl {
                    if Int(index) < controllerArray.count - 1 {
                        menuItemView.menuItemSeparator!.hidden = false
                    }
                }
                
                // Add menu item view to menu scroll view
                menuScrollView.addSubview(menuItemView)
                menuItems.append(menuItemView)
                
                index++
            }
        }
        
        // Set new content size for menu scroll view if needed
        if pageMenuOptions.menuItemWidthBasedOnTitleTextWidth {
            menuScrollView.contentSize = CGSizeMake((totalMenuItemWidthIfDifferentWidths + pageMenuOptions.menuMargin) + CGFloat(controllerArray.count) * pageMenuOptions.menuMargin, pageMenuOptions.menuHeight)
        }
        
        // Set selected color for title label of selected menu item
        if menuItems.count > 0 {
            if menuItems[currentPageIndex].titleLabel != nil {
                menuItems[currentPageIndex].titleLabel!.textColor = pageMenuOptions.selectedMenuItemLabelColor
            }
        }
        
        // Configure selection indicator view
        var selectionIndicatorFrame : CGRect = CGRect()
        
        if pageMenuOptions.useMenuLikeSegmentedControl {
            selectionIndicatorFrame = CGRectMake(0.0, pageMenuOptions.menuHeight - pageMenuOptions.selectionIndicatorHeight, self.view.frame.width / CGFloat(controllerArray.count), pageMenuOptions.selectionIndicatorHeight)
        } else if pageMenuOptions.menuItemWidthBasedOnTitleTextWidth {
            selectionIndicatorFrame = CGRectMake(pageMenuOptions.menuMargin, pageMenuOptions.menuHeight - pageMenuOptions.selectionIndicatorHeight, menuItemWidths[0], pageMenuOptions.selectionIndicatorHeight)
        } else {
            if pageMenuOptions.centerMenuItems  {
                selectionIndicatorFrame = CGRectMake(startingMenuMargin + pageMenuOptions.menuMargin, pageMenuOptions.menuHeight - pageMenuOptions.selectionIndicatorHeight, pageMenuOptions.menuItemWidth, pageMenuOptions.selectionIndicatorHeight)
            } else {
                selectionIndicatorFrame = CGRectMake(pageMenuOptions.menuMargin, pageMenuOptions.menuHeight - pageMenuOptions.selectionIndicatorHeight, pageMenuOptions.menuItemWidth, pageMenuOptions.selectionIndicatorHeight)
            }
        }
        
        selectionIndicatorView = UIView(frame: selectionIndicatorFrame)
        selectionIndicatorView.backgroundColor = pageMenuOptions.selectionIndicatorColor
        menuScrollView.addSubview(selectionIndicatorView)
    }
    
    
    // MARK: - Scroll view delegate
    
    public func scrollViewDidScroll(scrollView: UIScrollView) {
        if !didLayoutSubviewsAfterRotation {
            if scrollView.isEqual(controllerScrollView) {
                if scrollView.contentOffset.x >= 0.0 && scrollView.contentOffset.x <= (CGFloat(controllerArray.count - 1) * self.view.frame.width) {
                    if (currentOrientationIsPortrait && self.interfaceOrientation.isPortrait) || (!currentOrientationIsPortrait && self.interfaceOrientation.isLandscape) {
                        // Check if scroll direction changed
                        if !didTapMenuItemToScroll {
                            if didScrollAlready {
                                var newScrollDirection : CAPSPageMenuScrollDirection = .Other
                                
                                if (CGFloat(startingPageForScroll) * scrollView.frame.width > scrollView.contentOffset.x) {
                                    newScrollDirection = .Right
                                } else if (CGFloat(startingPageForScroll) * scrollView.frame.width < scrollView.contentOffset.x) {
                                    newScrollDirection = .Left
                                }
                                
                                if newScrollDirection != .Other {
                                    if lastScrollDirection != newScrollDirection {
                                        var index : Int = newScrollDirection == .Left ? currentPageIndex + 1 : currentPageIndex - 1
                                        
                                        if index >= 0 && index < controllerArray.count {
                                            // Check dictionary if page was already added
                                            if pagesAddedDictionary[index] != index {
                                                addPageAtIndex(index)
                                                pagesAddedDictionary[index] = index
                                            }
                                        }
                                    }
                                }
                                
                                lastScrollDirection = newScrollDirection
                            }
                            
                            if !didScrollAlready {
                                if (lastControllerScrollViewContentOffset > scrollView.contentOffset.x) {
                                    if currentPageIndex != controllerArray.count - 1 {
                                        // Add page to the left of current page
                                        var index : Int = currentPageIndex - 1
                                        
                                        if pagesAddedDictionary[index] != index && index < controllerArray.count && index >= 0 {
                                            addPageAtIndex(index)
                                            pagesAddedDictionary[index] = index
                                        }
                                        
                                        lastScrollDirection = .Right
                                    }
                                } else if (lastControllerScrollViewContentOffset < scrollView.contentOffset.x) {
                                    if currentPageIndex != 0 {
                                        // Add page to the right of current page
                                        var index : Int = currentPageIndex + 1
                                        
                                        if pagesAddedDictionary[index] != index && index < controllerArray.count && index >= 0 {
                                            addPageAtIndex(index)
                                            pagesAddedDictionary[index] = index
                                        }
                                        
                                        lastScrollDirection = .Left
                                    }
                                }
                                
                                didScrollAlready = true
                            }
                            
                            lastControllerScrollViewContentOffset = scrollView.contentOffset.x
                        }
                        
                        var ratio : CGFloat = 1.0
                        
                        
                        // Calculate ratio between scroll views
                        ratio = (menuScrollView.contentSize.width - self.view.frame.width) / (controllerScrollView.contentSize.width - self.view.frame.width)
                        
                        if menuScrollView.contentSize.width > self.view.frame.width {
                            var offset : CGPoint = menuScrollView.contentOffset
                            offset.x = controllerScrollView.contentOffset.x * ratio
                            menuScrollView.setContentOffset(offset, animated: false)
                        }
                        
                        // Calculate current page
                        var width : CGFloat = controllerScrollView.frame.size.width;
                        var page : Int = Int((controllerScrollView.contentOffset.x + (0.5 * width)) / width)
                        
                        // Update page if changed
                        if page != currentPageIndex {
                            lastPageIndex = currentPageIndex
                            currentPageIndex = page
                            
                            if pagesAddedDictionary[page] != page && page < controllerArray.count && page >= 0 {
                                addPageAtIndex(page)
                                pagesAddedDictionary[page] = page
                            }
                            
                            if !didTapMenuItemToScroll {
                                // Add last page to pages dictionary to make sure it gets removed after scrolling
                                if pagesAddedDictionary[lastPageIndex] != lastPageIndex {
                                    pagesAddedDictionary[lastPageIndex] = lastPageIndex
                                }
                                
                                // Make sure only up to 3 page views are in memory when fast scrolling, otherwise there should only be one in memory
                                var indexLeftTwo : Int = page - 2
                                if pagesAddedDictionary[indexLeftTwo] == indexLeftTwo {
                                    pagesAddedDictionary.removeValueForKey(indexLeftTwo)
                                    removePageAtIndex(indexLeftTwo)
                                }
                                var indexRightTwo : Int = page + 2
                                if pagesAddedDictionary[indexRightTwo] == indexRightTwo {
                                    pagesAddedDictionary.removeValueForKey(indexRightTwo)
                                    removePageAtIndex(indexRightTwo)
                                }
                            }
                        }
                        
                        // Move selection indicator view when swiping
                        moveSelectionIndicator(page)
                    }
                } else {
                    var ratio : CGFloat = 1.0
                    
                    ratio = (menuScrollView.contentSize.width - self.view.frame.width) / (controllerScrollView.contentSize.width - self.view.frame.width)
                    
                    if menuScrollView.contentSize.width > self.view.frame.width {
                        var offset : CGPoint = menuScrollView.contentOffset
                        offset.x = controllerScrollView.contentOffset.x * ratio
                        menuScrollView.setContentOffset(offset, animated: false)
                    }
                }
            }
        } else {
            didLayoutSubviewsAfterRotation = false
            
            // Move selection indicator view when swiping
            moveSelectionIndicator(currentPageIndex)
        }
    }
    
    public func scrollViewDidEndDecelerating(scrollView: UIScrollView) {
        if scrollView.isEqual(controllerScrollView) {
            // Call didMoveToPage delegate function
            var currentController = controllerArray[currentPageIndex]
            delegate?.didMoveToPage?(currentController, index: currentPageIndex)
            
            // Remove all but current page after decelerating
            for key in pagesAddedDictionary.keys {
                if key != currentPageIndex {
                    removePageAtIndex(key)
                }
            }
            
            didScrollAlready = false
            startingPageForScroll = currentPageIndex
            
            
            // Empty out pages in dictionary
            pagesAddedDictionary.removeAll(keepCapacity: false)
        }
    }
    
    func scrollViewDidEndTapScrollingAnimation() {
        // Call didMoveToPage delegate function
        var currentController : UIViewController = controllerArray[currentPageIndex]
        delegate?.didMoveToPage?(currentController, index: currentPageIndex)
        
        // Remove all but current page after decelerating
        for key in pagesAddedDictionary.keys {
            if key != currentPageIndex {
                removePageAtIndex(key)
            }
        }
        
        startingPageForScroll = currentPageIndex
        didTapMenuItemToScroll = false
        
        // Empty out pages in dictionary
        pagesAddedDictionary.removeAll(keepCapacity: false)
    }
    
    
    // MARK: - Handle Selection Indicator
    func moveSelectionIndicator(pageIndex: Int) {
        if pageIndex >= 0 && pageIndex < controllerArray.count {
            UIView.animateWithDuration(0.15, animations: { () -> Void in
                var selectionIndicatorWidth : CGFloat = self.selectionIndicatorView.frame.width
                var selectionIndicatorX : CGFloat = 0.0
                
                if self.pageMenuOptions.useMenuLikeSegmentedControl {
                    selectionIndicatorX = CGFloat(pageIndex) * (self.view.frame.width / CGFloat(self.controllerArray.count))
                    selectionIndicatorWidth = self.view.frame.width / CGFloat(self.controllerArray.count)
                } else if self.pageMenuOptions.menuItemWidthBasedOnTitleTextWidth {
                    selectionIndicatorWidth = self.menuItemWidths[pageIndex]
                    selectionIndicatorX += self.pageMenuOptions.menuMargin
                    
                    if pageIndex > 0 {
                        for i in 0...(pageIndex - 1) {
                            selectionIndicatorX += (self.pageMenuOptions.menuMargin + self.menuItemWidths[i])
                        }
                    }
                } else {
                    if self.pageMenuOptions.centerMenuItems && pageIndex == 0 {
                        selectionIndicatorX = self.startingMenuMargin + self.pageMenuOptions.menuMargin
                    } else {
                        selectionIndicatorX = self.pageMenuOptions.menuItemWidth * CGFloat(pageIndex) + self.pageMenuOptions.menuMargin * CGFloat(pageIndex + 1) + self.startingMenuMargin
                    }
                }
                
                self.selectionIndicatorView.frame = CGRectMake(selectionIndicatorX, self.selectionIndicatorView.frame.origin.y, selectionIndicatorWidth, self.selectionIndicatorView.frame.height)
                
                // Switch newly selected menu item title label to selected color and old one to unselected color
                if self.menuItems.count > 0 {
                    if self.menuItems[self.lastPageIndex].titleLabel != nil && self.menuItems[self.currentPageIndex].titleLabel != nil {
                        self.menuItems[self.lastPageIndex].titleLabel!.textColor = self.pageMenuOptions.unselectedMenuItemLabelColor
                        self.menuItems[self.currentPageIndex].titleLabel!.textColor = self.pageMenuOptions.selectedMenuItemLabelColor
                    }
                }
            })
        }
    }
    
    
    // MARK: - Tap gesture recognizer selector
    
    func handleMenuItemTap(gestureRecognizer : UITapGestureRecognizer) {
        var tappedPoint : CGPoint = gestureRecognizer.locationInView(menuScrollView)
        
        if tappedPoint.y < menuScrollView.frame.height {
            
            // Calculate tapped page
            var itemIndex : Int = 0
            
            if pageMenuOptions.useMenuLikeSegmentedControl {
                itemIndex = Int(tappedPoint.x / (self.view.frame.width / CGFloat(controllerArray.count)))
            } else if pageMenuOptions.menuItemWidthBasedOnTitleTextWidth {
                // Base case being first item
                var menuItemLeftBound : CGFloat = 0.0
                var menuItemRightBound : CGFloat = menuItemWidths[0] + pageMenuOptions.menuMargin + (pageMenuOptions.menuMargin / 2)
                
                if !(tappedPoint.x >= menuItemLeftBound && tappedPoint.x <= menuItemRightBound) {
                    for i in 1...controllerArray.count - 1 {
                        menuItemLeftBound = menuItemRightBound + 1.0
                        menuItemRightBound = menuItemLeftBound + menuItemWidths[i] + pageMenuOptions.menuMargin
                        
                        if tappedPoint.x >= menuItemLeftBound && tappedPoint.x <= menuItemRightBound {
                            itemIndex = i
                            break
                        }
                    }
                }
            } else {
                var rawItemIndex : CGFloat = ((tappedPoint.x - startingMenuMargin) - pageMenuOptions.menuMargin / 2) / (pageMenuOptions.menuMargin + pageMenuOptions.menuItemWidth)
                
                // Prevent moving to first item when tapping left to first item
                if rawItemIndex < 0 {
                    itemIndex = -1
                } else {
                    itemIndex = Int(rawItemIndex)
                }
            }
            
            if itemIndex >= 0 && itemIndex < controllerArray.count {
                // Update page if changed
                if itemIndex != currentPageIndex {
                    startingPageForScroll = itemIndex
                    lastPageIndex = currentPageIndex
                    currentPageIndex = itemIndex
                    didTapMenuItemToScroll = true
                    
                    // Add pages in between current and tapped page if necessary
                    var smallerIndex : Int = lastPageIndex < currentPageIndex ? lastPageIndex : currentPageIndex
                    var largerIndex : Int = lastPageIndex > currentPageIndex ? lastPageIndex : currentPageIndex
                    
                    if smallerIndex + 1 != largerIndex {
                        for index in (smallerIndex + 1)...(largerIndex - 1) {
                            if pagesAddedDictionary[index] != index {
                                addPageAtIndex(index)
                                pagesAddedDictionary[index] = index
                            }
                        }
                    }
                    
                    addPageAtIndex(itemIndex)
                    
                    // Add page from which tap is initiated so it can be removed after tap is done
                    pagesAddedDictionary[lastPageIndex] = lastPageIndex
                }
                
                // Move controller scroll view when tapping menu item
                var duration : Double = Double(pageMenuOptions.scrollAnimationDurationOnMenuItemTap)
                
                UIView.animateWithDuration(duration, animations: { () -> Void in
                    var xOffset : CGFloat = CGFloat(itemIndex) * self.controllerScrollView.frame.width
                    self.controllerScrollView.setContentOffset(CGPoint(x: xOffset, y: self.controllerScrollView.contentOffset.y), animated: false)
                })
                
                if tapTimer != nil {
                    tapTimer!.invalidate()
                }
                
                var timerInterval : NSTimeInterval = Double(pageMenuOptions.scrollAnimationDurationOnMenuItemTap)
                tapTimer = NSTimer.scheduledTimerWithTimeInterval(timerInterval, target: self, selector: "scrollViewDidEndTapScrollingAnimation", userInfo: nil, repeats: false)
            }
        }
    }
    
    
    // MARK: - Remove/Add Page
    func addPageAtIndex(index : Int) {
        // Call didMoveToPage delegate function
        var currentController = controllerArray[index]
        delegate?.willMoveToPage?(currentController, index: index)
        
        var newVC = controllerArray[index]
        
        newVC.willMoveToParentViewController(self)
        
        newVC.view.frame = CGRectMake(self.view.frame.width * CGFloat(index), pageMenuOptions.menuHeight, self.view.frame.width, self.view.frame.height - pageMenuOptions.menuHeight)
        
        self.addChildViewController(newVC)
        self.controllerScrollView.addSubview(newVC.view)
        newVC.didMoveToParentViewController(self)
    }
    
    func removePageAtIndex(index : Int) {
        var oldVC = controllerArray[index]
        
        oldVC.willMoveToParentViewController(nil)
        
        oldVC.view.removeFromSuperview()
        oldVC.removeFromParentViewController()
        
        oldVC.didMoveToParentViewController(nil)
    }
    
    
    // MARK: - Orientation Change
    
    override public func viewDidLayoutSubviews() {
        // Configure controller scroll view content size
        controllerScrollView.contentSize = CGSizeMake(self.view.frame.width * CGFloat(controllerArray.count), self.view.frame.height - pageMenuOptions.menuHeight)

        var oldCurrentOrientationIsPortrait : Bool = currentOrientationIsPortrait
        currentOrientationIsPortrait = self.interfaceOrientation.isPortrait
        
        if (oldCurrentOrientationIsPortrait && UIDevice.currentDevice().orientation.isLandscape) || (!oldCurrentOrientationIsPortrait && UIDevice.currentDevice().orientation.isPortrait) {
            didLayoutSubviewsAfterRotation = true
            
            //Resize menu items if using as segmented control
            if pageMenuOptions.useMenuLikeSegmentedControl {
                menuScrollView.contentSize = CGSizeMake(self.view.frame.width, pageMenuOptions.menuHeight)
                
                // Resize selectionIndicator bar
                var selectionIndicatorX : CGFloat = CGFloat(currentPageIndex) * (self.view.frame.width / CGFloat(self.controllerArray.count))
                var selectionIndicatorWidth : CGFloat = self.view.frame.width / CGFloat(self.controllerArray.count)
                selectionIndicatorView.frame =  CGRectMake(selectionIndicatorX, self.selectionIndicatorView.frame.origin.y, selectionIndicatorWidth, self.selectionIndicatorView.frame.height)
                
                // Resize menu items
                var index : Int = 0
                
                for item : MenuItemView in menuItems as [MenuItemView] {
                    item.frame = CGRectMake(self.view.frame.width / CGFloat(controllerArray.count) * CGFloat(index), 0.0, self.view.frame.width / CGFloat(controllerArray.count), pageMenuOptions.menuHeight)
                    item.titleLabel!.frame = CGRectMake(0.0, 0.0, self.view.frame.width / CGFloat(controllerArray.count), pageMenuOptions.menuHeight)
                    item.menuItemSeparator!.frame = CGRectMake(item.frame.width - (pageMenuOptions.menuItemSeparatorWidth / 2), item.menuItemSeparator!.frame.origin.y, item.menuItemSeparator!.frame.width, item.menuItemSeparator!.frame.height)
                    
                    index++
                }
            } else if pageMenuOptions.centerMenuItems {
                startingMenuMargin = ((self.view.frame.width - ((CGFloat(controllerArray.count) * pageMenuOptions.menuItemWidth) + (CGFloat(controllerArray.count - 1) * pageMenuOptions.menuMargin))) / 2.0) -  pageMenuOptions.menuMargin
                
                if startingMenuMargin < 0.0 {
                    startingMenuMargin = 0.0
                }
                
                var selectionIndicatorX : CGFloat = self.pageMenuOptions.menuItemWidth * CGFloat(currentPageIndex) + self.pageMenuOptions.menuMargin * CGFloat(currentPageIndex + 1) + self.startingMenuMargin
                selectionIndicatorView.frame =  CGRectMake(selectionIndicatorX, self.selectionIndicatorView.frame.origin.y, self.selectionIndicatorView.frame.width, self.selectionIndicatorView.frame.height)
                
                // Recalculate frame for menu items if centered
                var index : Int = 0
                
                for item : MenuItemView in menuItems as [MenuItemView] {
                    if index == 0 {
                        item.frame = CGRectMake(startingMenuMargin + pageMenuOptions.menuMargin, 0.0, pageMenuOptions.menuItemWidth, pageMenuOptions.menuHeight)
                    } else {
                        item.frame = CGRectMake(pageMenuOptions.menuItemWidth * CGFloat(index) + pageMenuOptions.menuMargin * CGFloat(index + 1) + startingMenuMargin, 0.0, pageMenuOptions.menuItemWidth, pageMenuOptions.menuHeight)
                    }
                    
                    index++
                }
            }
            
            for view : UIView in controllerScrollView.subviews as! [UIView] {
                view.frame = CGRectMake(self.view.frame.width * CGFloat(currentPageIndex), pageMenuOptions.menuHeight, controllerScrollView.frame.width, self.view.frame.height - pageMenuOptions.menuHeight)
            }
            
            var xOffset : CGFloat = CGFloat(self.currentPageIndex) * controllerScrollView.frame.width
            controllerScrollView.setContentOffset(CGPoint(x: xOffset, y: controllerScrollView.contentOffset.y), animated: false)
            
            var ratio : CGFloat = (menuScrollView.contentSize.width - self.view.frame.width) / (controllerScrollView.contentSize.width - self.view.frame.width)
            
            if menuScrollView.contentSize.width > self.view.frame.width {
                var offset : CGPoint = menuScrollView.contentOffset
                offset.x = controllerScrollView.contentOffset.x * ratio
                menuScrollView.setContentOffset(offset, animated: false)
            }
        }
        
        // Hsoi 2015-02-05 - Running on iOS 7.1 complained: "'NSInternalInconsistencyException', reason: 'Auto Layout 
        // still required after sending -viewDidLayoutSubviews to the view controller. ViewController's implementation 
        // needs to send -layoutSubviews to the view to invoke auto layout.'"
        //
        // http://stackoverflow.com/questions/15490140/auto-layout-error
        //
        // Given the SO answer and caveats presented there, we'll call layoutIfNeeded() instead.
        self.view.layoutIfNeeded()
    }
    
    
    // MARK: - Move to page index
    
    /**
    Move to page at index
    
    :param: index Index of the page to move to
    */
    public func moveToPage(index: Int) {
        if index >= 0 && index < controllerArray.count {
            // Update page if changed
            if index != currentPageIndex {
                startingPageForScroll = index
                lastPageIndex = currentPageIndex
                currentPageIndex = index
                didTapMenuItemToScroll = true
                
                // Add pages in between current and tapped page if necessary
                var smallerIndex : Int = lastPageIndex < currentPageIndex ? lastPageIndex : currentPageIndex
                var largerIndex : Int = lastPageIndex > currentPageIndex ? lastPageIndex : currentPageIndex
                
                if smallerIndex + 1 != largerIndex {
                    for i in (smallerIndex + 1)...(largerIndex - 1) {
                        if pagesAddedDictionary[i] != i {
                            addPageAtIndex(i)
                            pagesAddedDictionary[i] = i
                        }
                    }
                }
                
                addPageAtIndex(index)
                
                // Add page from which tap is initiated so it can be removed after tap is done
                pagesAddedDictionary[lastPageIndex] = lastPageIndex
            }
            
            // Move controller scroll view when tapping menu item
            var duration : Double = Double(pageMenuOptions.scrollAnimationDurationOnMenuItemTap)
            
            UIView.animateWithDuration(duration, animations: { () -> Void in
                var xOffset : CGFloat = CGFloat(index) * self.controllerScrollView.frame.width
                self.controllerScrollView.setContentOffset(CGPoint(x: xOffset, y: self.controllerScrollView.contentOffset.y), animated: false)
            })
        }
    }
}
