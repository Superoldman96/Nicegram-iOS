// MARK: Nicegram AccountBackup
import FeatAccountBackup
//
// MARK: Nicegram PhoneEntryBanner
import FeatPhoneEntryBanner
//
// MARK: Nicegram Auth
import FeatAuth
//
// MARK: Nicegram DailyLoginLimit
import class CoreSwiftUI.DailyLoginLimitPopupPresenter
//
// MARK: Nicegram Onboarding
import FeatOnboarding
//
import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import Postbox
import TelegramPresentationData
import ProgressNavigationButtonNode
import AccountContext
import CountrySelectionUI
import PhoneNumberFormat
import DebugSettingsUI
import MessageUI

public final class AuthorizationSequencePhoneEntryController: ViewController, MFMailComposeViewControllerDelegate {
    private var controllerNode: AuthorizationSequencePhoneEntryControllerNode {
        return self.displayNode as! AuthorizationSequencePhoneEntryControllerNode
    }
    
    private var validLayout: ContainerViewLayout?
    
    private let sharedContext: SharedAccountContext
    private var account: UnauthorizedAccount?
    private let isTestingEnvironment: Bool
    private let otherAccountPhoneNumbers: ((String, AccountRecordId, Bool)?, [(String, AccountRecordId, Bool)])
    private let network: Network
    private let presentationData: PresentationData
    private let openUrl: (String) -> Void
    
    private let back: () -> Void
    
    private var currentData: (Int32, String?, String)?
        
    var codeNode: ASDisplayNode {
        return self.controllerNode.codeNode
    }
    
    var numberNode: ASDisplayNode {
        return self.controllerNode.numberNode
    }
    
    var buttonNode: ASDisplayNode {
        return self.controllerNode.buttonNode
    }
    
    public var inProgress: Bool = false {
        didSet {
            self.updateNavigationItems()
            self.controllerNode.inProgress = self.inProgress
            self.confirmationController?.inProgress = self.inProgress
        }
    }
    public var loginWithNumber: ((String, Bool) -> Void)?
    var accountUpdated: ((UnauthorizedAccount) -> Void)?
    
    weak var confirmationController: PhoneConfirmationController?
    
    private let termsDisposable = MetaDisposable()
    
    private let hapticFeedback = HapticFeedback()
    
    public init(sharedContext: SharedAccountContext, account: UnauthorizedAccount?, countriesConfiguration: CountriesConfiguration? = nil, isTestingEnvironment: Bool, otherAccountPhoneNumbers: ((String, AccountRecordId, Bool)?, [(String, AccountRecordId, Bool)]), network: Network, presentationData: PresentationData, openUrl: @escaping (String) -> Void, back: @escaping () -> Void) {
        self.sharedContext = sharedContext
        self.account = account
        self.isTestingEnvironment = isTestingEnvironment
        self.otherAccountPhoneNumbers = otherAccountPhoneNumbers
        self.network = network
        self.presentationData = presentationData
        self.openUrl = openUrl
        self.back = back
                
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: AuthorizationSequenceController.navigationBarTheme(presentationData.theme), strings: NavigationBarStrings(presentationStrings: presentationData.strings)))
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        
        self.hasActiveInput = true
        
        self.statusBar.statusBarStyle = presentationData.theme.intro.statusBarStyle.style
        self.attemptNavigation = { _ in
            return false
        }
        self.navigationBar?.backPressed = {
            back()
        }
        
        if !otherAccountPhoneNumbers.1.isEmpty {
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed))
        }
        
        if let countriesConfiguration {
            AuthorizationSequenceCountrySelectionController.setupCountryCodes(countries: countriesConfiguration.countries, codesByPrefix: countriesConfiguration.countriesByPrefix)
        }
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.termsDisposable.dispose()
    }
    
    @objc private func cancelPressed() {
        self.back()
    }
    
    func updateNavigationItems() {
        guard let layout = self.validLayout, layout.size.width < 360.0 else {
            return
        }
                
        if self.inProgress {
            let item = UIBarButtonItem(customDisplayNode: ProgressNavigationButtonNode(color: self.presentationData.theme.rootController.navigationBar.accentTextColor))
            self.navigationItem.rightBarButtonItem = item
        } else {
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Next, style: .done, target: self, action: #selector(self.nextPressed))
        }
    }
    
    public func updateData(countryCode: Int32, countryName: String?, number: String) {
        self.currentData = (countryCode, countryName, number)
        if self.isNodeLoaded {
            self.controllerNode.codeAndNumber = (countryCode, countryName, number)
        }
    }
    
    private var shouldAnimateIn = false
    private var transitionInArguments: (buttonFrame: CGRect, buttonTitle: String, animationSnapshot: UIView, textSnapshot: UIView)?
    
    func animateWithSplashController(_ controller: AuthorizationSequenceSplashController) {
        self.shouldAnimateIn = true
        
        if let animationSnapshot = controller.animationSnapshot, let textSnapshot = controller.textSnaphot {
            self.transitionInArguments = (controller.buttonFrame, controller.buttonTitle, animationSnapshot, textSnapshot)
        }
    }
    
    override public func loadDisplayNode() {
        self.displayNode = AuthorizationSequencePhoneEntryControllerNode(sharedContext: self.sharedContext, account: self.account, strings: self.presentationData.strings, theme: self.presentationData.theme, debugAction: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.view.endEditing(true)
            self?.present(debugController(sharedContext: strongSelf.sharedContext, context: nil, modal: true), in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            // MARK: Nicegram DB Changes
        }, hasOtherAccounts: self.otherAccountPhoneNumbers.0 != nil || self.otherAccountPhoneNumbers.1.contains(where: { !$0.0.isEmpty }))
        self.controllerNode.accountUpdated = { [weak self] account in
            guard let strongSelf = self else {
                return
            }
            strongSelf.account = account
            strongSelf.accountUpdated?(account)
        }
        
        if let (code, name, number) = self.currentData {
            self.controllerNode.codeAndNumber = (code, name, number)
        }
        self.displayNodeDidLoad()
        
        self.controllerNode.view.disableAutomaticKeyboardHandling = [.forward, .backward]
        
        self.controllerNode.selectCountryCode = { [weak self] in
            if let strongSelf = self {
                let controller = AuthorizationSequenceCountrySelectionController(strings: strongSelf.presentationData.strings, theme: strongSelf.presentationData.theme)
                controller.completeWithCountryCode = { code, name in
                    if let strongSelf = self, let currentData = strongSelf.currentData {
                        strongSelf.updateData(countryCode: Int32(code), countryName: name, number: currentData.2)
                        strongSelf.controllerNode.activateInput()
                    }
                }
                controller.dismissed = { 
                    self?.controllerNode.activateInput()
                }
                strongSelf.push(controller)
            }
        }
        self.controllerNode.checkPhone = { [weak self] in
            self?.nextPressed()
        }
        
        if let account = self.account {
            loadServerCountryCodes(accountManager: sharedContext.accountManager, engine: TelegramEngineUnauthorized(account: account), completion: { [weak self] in
                if let strongSelf = self {
                    strongSelf.controllerNode.updateCountryCode()
                }
            })
        } else {
            self.controllerNode.updateCountryCode()
        }
        
        // MARK: Nicegram PhoneEntryBanner
        if #available(iOS 15.0, *) {
            setupPhoneEntryBanner(
                view: self.controllerNode.ngBannerNode.view,
                controller: self
            )
        }
        //
        
        // MARK: Nicegram Onboarding
        if #available(iOS 15.0, *) {
            let proceedNode = self.controllerNode.proceedNode
            setupPhoneEntryGuideButton(
                config: PhoneEntryGuideButtonConfig(
                    buttonBackgroundColor: proceedNode.theme.disabledBackgroundColor ?? .clear,
                    buttonForegroundColor: .label,
                    buttonHeight: proceedNode.buttonHeight,
                    buttonCornerRadius: proceedNode.buttonCornerRadius,
                    separatorColor: self.presentationData.theme.list.itemPlainSeparatorColor
                ),
               view: self.controllerNode.ngGuideButtonNode.view,
               controller: self
           )
        }
        //
    }
    
    public func updateCountryCode() {
        self.controllerNode.updateCountryCode()
    }
    
    private var animatingIn = false
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if self.shouldAnimateIn {
            self.animatingIn = true
            if let (buttonFrame, buttonTitle, animationSnapshot, textSnapshot) = self.transitionInArguments {
                self.controllerNode.willAnimateIn(buttonFrame: buttonFrame, buttonTitle: buttonTitle, animationSnapshot: animationSnapshot, textSnapshot: textSnapshot)
            }
            Queue.mainQueue().justDispatch {
                self.controllerNode.activateInput()
            }
        } else {
            self.controllerNode.activateInput()
        }
    }
    
    // MARK: Nicegram DailyLoginLimit
    private var sawDailyLoginLimitPopup = false
    //
    
    // MARK: Nicegram AccountBackup
    private var sawImportAccounts = false
    //
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.animatingIn {
            self.controllerNode.activateInput()
        }
        
        // MARK: Nicegram AccountBackup
        if #available(iOS 15.0, *),
           !self.sawImportAccounts,
           self.otherAccountPhoneNumbers.1.isEmpty {
            self.sawImportAccounts = true
            ImportAccountsPresenter().presentImportFromBackupOnAddingAccount()
        }
        //
        
        // MARK: Nicegram AppReviewLogin
        if AppReviewLogin.isActive {
            self.loginWithNumber?(AppReviewLogin.phone, self.controllerNode.syncContacts)
        }
        //
        
        // MARK: Nicegram DailyLoginLimit
        if #available(iOS 15.0, *) {
            if self.otherAccountPhoneNumbers.1.count >= 3, !self.sawDailyLoginLimitPopup {
                self.sawDailyLoginLimitPopup = true
                Task {
                    try? await Task.sleep(seconds: 0.5)
                    DailyLoginLimitPopupPresenter().present()
                }
            }
        }
        //
    }
    
    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if let confirmationController = self.confirmationController {
            confirmationController.transitionOut()
        }
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        let hadLayout = self.validLayout != nil
        self.validLayout = layout
        
        if !hadLayout {
            self.updateNavigationItems()
        }
    
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
        
        if self.shouldAnimateIn, let inputHeight = layout.inputHeight, inputHeight > 0.0 {
            if let (buttonFrame, buttonTitle, animationSnapshot, textSnapshot) = self.transitionInArguments {
                self.shouldAnimateIn = false
                self.controllerNode.animateIn(buttonFrame: buttonFrame, buttonTitle: buttonTitle, animationSnapshot: animationSnapshot, textSnapshot: textSnapshot)
            }
        }
    }
    
    public func dismissConfirmation() {
        self.confirmationController?.dismissAnimated()
        self.confirmationController = nil
    }
    
    @objc func nextPressed() {
        guard self.confirmationController == nil else {
            return
        }
        let (_, _, number) = self.controllerNode.codeAndNumber
        if !number.isEmpty {
            let logInNumber = cleanPhoneNumber(self.controllerNode.currentNumber, removePlus: true)
            var existing: (String, AccountRecordId)?
            for (number, id, isTestingEnvironment) in self.otherAccountPhoneNumbers.1 {
                if isTestingEnvironment == self.isTestingEnvironment && cleanPhoneNumber(number, removePlus: true) == logInNumber {
                    existing = (number, id)
                }
            }
            
            if let (_, id) = existing {
                var actions: [TextAlertAction] = []
                if let (current, _, _) = self.otherAccountPhoneNumbers.0, logInNumber != cleanPhoneNumber(current, removePlus: true) {
                    actions.append(TextAlertAction(type: .genericAction, title: self.presentationData.strings.Login_PhoneNumberAlreadyAuthorizedSwitch, action: { [weak self] in
                        self?.sharedContext.switchToAccount(id: id, fromSettingsController: nil, withChatListController: nil)
                        self?.back()
                    }))
                }
                actions.append(TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_OK, action: {}))
                self.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: self.presentationData), title: nil, text: self.presentationData.strings.Login_PhoneNumberAlreadyAuthorized, actions: actions), in: .window(.root))
            } else {
                // MARK: Nicegram AppReviewLogin
                let tryLoginWithNumber: () -> Void = { [weak self] in
                    guard let self = self else { return }

                    let isAppReviewLogin = AppReviewLogin.phone.contains(logInNumber)
                    AppReviewLogin.sendCodeDate = isAppReviewLogin ? Date() : nil
                    if isAppReviewLogin {
                        Task { await AuthTgHelper.loginToTestAccount() }
                    }

                    let logInNumber: String
                    if (self.isTestingEnvironment){
                        logInNumber = number
                    } else {
                        logInNumber = self.controllerNode.currentNumber
                    }
                    self.loginWithNumber?(logInNumber, self.controllerNode.syncContacts)
                }
                //
                if let validLayout = self.validLayout, validLayout.size.width > 320.0 {
                    let (code, formattedNumber) = self.controllerNode.formattedCodeAndNumber

                    let confirmationController = PhoneConfirmationController(theme: self.presentationData.theme, strings: self.presentationData.strings, code: code, number: formattedNumber, sourceController: self)
                    // MARK: Nicegram AppReviewLogin, call tryLoginWithNumber instead of strongSelf.loginWithNumber
                    confirmationController.proceed = {
                        tryLoginWithNumber()
                    }
                    (self.navigationController as? NavigationController)?.presentOverlay(controller: confirmationController, inGlobal: true, blockInteraction: true)
                    self.confirmationController = confirmationController
                } else {
                    var actions: [TextAlertAction] = []
                    actions.append(TextAlertAction(type: .genericAction, title: self.presentationData.strings.Login_Edit, action: {}))
                    // MARK: Nicegram AppReviewLogin, call tryLoginWithNumber instead of strongSelf.loginWithNumber
                    actions.append(TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Login_Yes, action: {
                        tryLoginWithNumber()
                    }))
                    self.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: self.presentationData), title: logInNumber, text: self.presentationData.strings.Login_PhoneNumberConfirmation, actions: actions), in: .window(.root))
                }
            }
        } else {
            self.hapticFeedback.error()
            self.controllerNode.animateError()
        }
    }
    
    public func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
    }
}
