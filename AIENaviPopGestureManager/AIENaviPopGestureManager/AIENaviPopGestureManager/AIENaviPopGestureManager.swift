//
//  AIENaviPopGestureManager.swift
//
//  Created by brian on 2017/7/3.
//  Copyright © 2017年 brian. All rights reserved.
//

import UIKit

fileprivate typealias AIEViewControllerViewWillAppearInjectClosure = (UIViewController, Bool) -> Void

class AIENaviPopGestureManager: NSObject, UIGestureRecognizerDelegate {
    class func start() {
        UINavigationController.injectAIENaviPopGestureManagerForUINavigationController()
        UIViewController.injectAIENaviPopGestureManagerForUIViewController()
    }
}

fileprivate class AIEInteractivePopGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    weak var navigationController: UINavigationController? = nil
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let navigationController = self.navigationController else {
            return false
        }
        guard let recognizer = gestureRecognizer as? UIPanGestureRecognizer else {
            return false
        }
        ///
        if navigationController.viewControllers.count <= 1 {
            return false
        }
        ///
        if navigationController.value(forKey: "_isTransitioning") as? Bool ?? false {
            return false
        }
        ///
        let translation = recognizer.translation(in: recognizer.view)
        if translation.x <= 0 {
            return false
        }
        ///
        guard let topViewController = navigationController.viewControllers.last else {
            return false
        }
        if topViewController.aie_interactivePopGestureDisabled {
            return false
        }
        ///
        let beginningLocation = recognizer.location(in: recognizer.view)
        let triggerWidth = topViewController.aie_interactivePopGestureTriggerWidth
        if triggerWidth > 0 && beginningLocation.x > triggerWidth {
            return false
        }
        
        return true
    }
}

fileprivate var kAIEInteractivePopGestureRecognizer = "kAIEInteractivePopGestureRecognizer"
fileprivate var kAIEInteractivePopGestureRecognizerDelegate = "kAIEInteractivePopGestureRecognizerDelegate"
fileprivate var kAIENeedAIEControlNaviBarAppearance = "kAIENeedAIEControlNaviBarAppearance"
fileprivate var kAIENaviPopGestureManagerInjectedForUINavigationController = false

extension UINavigationController {
    
    var aie_interactivePopGestureRecognizer: UIPanGestureRecognizer {
        get {
            let panGestureRecognizer = objc_getAssociatedObject(self, &kAIEInteractivePopGestureRecognizer) as? UIPanGestureRecognizer
            if let panGestureRecognizer = panGestureRecognizer {
                return panGestureRecognizer
            } else {
                let newGestureRecognizer = UIPanGestureRecognizer()
                newGestureRecognizer.maximumNumberOfTouches = 1
                objc_setAssociatedObject(self, &kAIEInteractivePopGestureRecognizer, newGestureRecognizer, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                return newGestureRecognizer
            }
        }
    }
    
    var aie_needAIEControlNaviBarAppearance: Bool {
        get{
            if let value = objc_getAssociatedObject(self, &kAIENeedAIEControlNaviBarAppearance) as? Bool {
                return value
            } else {
                return true
            }
        }
        set{
            objc_setAssociatedObject(self, &kAIENeedAIEControlNaviBarAppearance, newValue, .OBJC_ASSOCIATION_ASSIGN)
        }
    }
    
    fileprivate var aie_interactivePopGestureRecognizerDelegate: AIEInteractivePopGestureDelegate {
        get {
            let popGestureDelegate = objc_getAssociatedObject(self, &kAIEInteractivePopGestureRecognizerDelegate) as? AIEInteractivePopGestureDelegate
            if let popGestureDelegate = popGestureDelegate {
                return popGestureDelegate
            } else {
                let newPopGestureDelegate = AIEInteractivePopGestureDelegate()
                newPopGestureDelegate.navigationController = self
                objc_setAssociatedObject(self, &kAIEInteractivePopGestureRecognizerDelegate, newPopGestureDelegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                return newPopGestureDelegate
            }
        }
    }
    
    fileprivate class func injectAIENaviPopGestureManagerForUINavigationController() {
        if !kAIENaviPopGestureManagerInjectedForUINavigationController {
            let originalSelector = #selector(UINavigationController.pushViewController(_:animated:))
            let swizzledSelector = #selector(UINavigationController.aie_pushViewController(_:animated:))
            
            let originalMethod = class_getInstanceMethod(self, originalSelector)
            let swizzledMethod = class_getInstanceMethod(self, swizzledSelector)
            
            let didAddMethod = class_addMethod(self, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))
            
            if didAddMethod {
                class_replaceMethod(self, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod))
            } else {
                method_exchangeImplementations(originalMethod, swizzledMethod)
            }
            kAIENaviPopGestureManagerInjectedForUINavigationController = true
        }
    }
    
    open func aie_pushViewController(_ viewController: UIViewController, animated: Bool) {
        if !(interactivePopGestureRecognizer?.view?.gestureRecognizers?.contains(aie_interactivePopGestureRecognizer) ?? false) {
            interactivePopGestureRecognizer?.view?.addGestureRecognizer(aie_interactivePopGestureRecognizer)
            
            let originalTargetStructs = interactivePopGestureRecognizer?.value(forKey: "targets") as? NSArray
            let originalTargetStruct = originalTargetStructs?.firstObject
            let originalTarget = (originalTargetStruct as AnyObject).value(forKey: "target")
            let originalAction = NSSelectorFromString("handleNavigationTransition:")
            aie_interactivePopGestureRecognizer.delegate = aie_interactivePopGestureRecognizerDelegate
            if let originalTarget = originalTarget {
                if !(originalTarget as AnyObject).isMember(of: NSNull.classForCoder()) {
                    aie_interactivePopGestureRecognizer.addTarget(originalTarget, action: originalAction)
                    interactivePopGestureRecognizer?.isEnabled = false
                }
            }
        }
        
        if aie_needAIEControlNaviBarAppearance {
            aie_takeOverNaviBarAppearance(appearingViewController: viewController)
        }
        
        if !(viewControllers.contains(viewController)) {
            aie_pushViewController(viewController, animated: animated)
        }
    }
    
    private func aie_takeOverNaviBarAppearance(appearingViewController: UIViewController) {
        if !aie_needAIEControlNaviBarAppearance {
            return
        }
        
        let injectClosure: AIEViewControllerViewWillAppearInjectClosure = { [weak self] (viewController, animated) in
            if let navi = self {
                navi.setNavigationBarHidden(viewController.aie_prefersNaviBarHidded, animated: animated)
            }
        }
        
        appearingViewController.aie_viewWillAppearInjectClosure = injectClosure
        
        if let disappearingViewController = viewControllers.last {
            if disappearingViewController.aie_viewWillAppearInjectClosure == nil {
                disappearingViewController.aie_viewWillAppearInjectClosure = injectClosure
            }
        }
        
    }
    
}

fileprivate var kAIEInteractivePopGestureDisabled = "kAIEInteractivePopGestureDisabled"
fileprivate var kAIEPrefersNaviBarHidded = "kAIEPrefersNaviBarHidded"
fileprivate var kAIEInteractivePopGestureTriggerWidth = "kAIEInteractivePopGestureTriggerWidth"
fileprivate var kAIEViewControllerViewWillAppearInjectClosure = "kAIEViewControllerViewWillAppearInjectClosure"
fileprivate var kAIENaviPopGestureManagerInjectedForUIViewController = false

extension UIViewController {
    
    fileprivate class func injectAIENaviPopGestureManagerForUIViewController() {
        if !kAIENaviPopGestureManagerInjectedForUIViewController {
            let originalSelector = #selector(UIViewController.viewWillAppear(_:))
            let swizzledSelector = #selector(UIViewController.aie_viewWillAppear(_:))
            
            let originalMethod = class_getInstanceMethod(self, originalSelector)
            let swizzledMethod = class_getInstanceMethod(self, swizzledSelector)
            
            let didAddMethod = class_addMethod(self, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))
            
            if didAddMethod {
                class_replaceMethod(self, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod))
            } else {
                method_exchangeImplementations(originalMethod, swizzledMethod)
            }
            kAIENaviPopGestureManagerInjectedForUIViewController = true
        }
    }
    
    open func aie_viewWillAppear(_ animated: Bool) {
        aie_viewWillAppear(animated)
        if let injectClosure = aie_viewWillAppearInjectClosure {
            injectClosure(self, animated)
        }
    }
    
    fileprivate var aie_viewWillAppearInjectClosure: AIEViewControllerViewWillAppearInjectClosure? {
        get{
            return objc_getAssociatedObject(self, &kAIEViewControllerViewWillAppearInjectClosure) as? AIEViewControllerViewWillAppearInjectClosure
        }
        set{
            objc_setAssociatedObject(self, &kAIEViewControllerViewWillAppearInjectClosure, newValue, .OBJC_ASSOCIATION_COPY_NONATOMIC)
        }
    }
    var aie_interactivePopGestureDisabled: Bool {
        get{
            return objc_getAssociatedObject(self, &kAIEInteractivePopGestureDisabled) as? Bool ?? false
        }
        set{
            objc_setAssociatedObject(self, &kAIEInteractivePopGestureDisabled, newValue, .OBJC_ASSOCIATION_ASSIGN)
        }
    }
    var aie_prefersNaviBarHidded: Bool {
        get{
            return objc_getAssociatedObject(self, &kAIEPrefersNaviBarHidded) as? Bool ?? false
        }
        set{
            objc_setAssociatedObject(self, &kAIEPrefersNaviBarHidded, newValue, .OBJC_ASSOCIATION_ASSIGN)
        }
    }
    var aie_interactivePopGestureTriggerWidth: CGFloat {
        get{
            return objc_getAssociatedObject(self, &kAIEInteractivePopGestureTriggerWidth) as? CGFloat ?? 0
        }
        set{
            objc_setAssociatedObject(self, &kAIEInteractivePopGestureTriggerWidth, max(0, newValue), .OBJC_ASSOCIATION_ASSIGN)
        }
    }
}
