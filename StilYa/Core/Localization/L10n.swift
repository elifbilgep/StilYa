//
//  L10n.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 15.02.2026.
//

import Foundation

enum L10n {
    private static func loc(_ key: String) -> String {
        LocalizationManager.shared.localized(key)
    }

    private static func loc(_ key: String, _ args: CVarArg...) -> String {
        if args.isEmpty {
            return LocalizationManager.shared.localized(key)
        }
        return LocalizationManager.shared.localized(key, args)
    }

    // MARK: - Splash
    static var splashSubtitle: String { loc("splash.subtitle") }

    // MARK: - Common
    static var commonSave: String { loc("common.save") }
    static var commonCancel: String { loc("common.cancel") }
    static var commonClose: String { loc("common.close") }
    static var commonContinue: String { loc("common.continue") }
    static var commonOk: String { loc("common.ok") }
    static var commonBack: String { loc("common.back") }
    static var commonSkip: String { loc("common.skip") }
    static var commonDelete: String { loc("common.delete") }
    static var commonEdit: String { loc("common.edit") }
    static var commonChange: String { loc("common.change") }
    static var commonShare: String { loc("common.share") }
    static var commonError: String { loc("common.error") }
    static var commonRetry: String { loc("common.retry") }
    static var commonLoading: String { loc("common.loading") }
    static var commonOr: String { loc("common.or") }
    static var commonSaved: String { loc("common.saved") }
    static var commonAdded: String { loc("common.added") }
    static var commonCopied: String { loc("common.copied") }
    static var commonSettings: String { loc("common.settings") }
    static var commonPro: String { loc("common.pro") }
    static var commonMaintenanceMessage: String { loc("common.maintenance") }

    // MARK: - Home
    static var homeTitle: String { loc("home.title") }
    static func homeTitleWithName(_ name: String) -> String { loc("home.titleWithName", name) }
    static var homeSubtitle: String { loc("home.subtitle") }
    static var homeTrySingle: String { loc("home.trySingle") }
    static var homeTrySingleSubtitle: String { loc("home.trySingleSubtitle") }
    static var homeCreateCombo: String { loc("home.createCombo") }
    static var homeCreateComboSubtitle: String { loc("home.createComboSubtitle") }
    static var homeTodaysTip: String { loc("home.todaysTip") }
    static var homeDressUp: String { loc("home.dressUp") }
    static var homeDressUpSubtitle: String { loc("home.dressUpSubtitle") }
    static var homeStyleTip: String { loc("home.styleTip") }
    static var homeRecentLooks: String { loc("home.recentLooks") }
    static var homeSavedImagesPlaceholder: String { loc("home.savedImagesPlaceholder") }
    static var homeCreditsLoadFailed: String { loc("home.creditsLoadFailed") }
    static var homeCartLoadFailed: String { loc("home.cartLoadFailed") }
    static var homeDebugCreditsAdded: String { loc("home.debugCreditsAdded") }
    static func homeDebugCreditsFailed(_ error: String) -> String { loc("home.debugCreditsFailed", error) }
    static var homeBuyCredits: String { loc("home.buyCredits") }
    static var homeBuyCreditsSubtitle: String { loc("home.buyCreditsSubtitle") }
    static var homeInviteFriend: String { loc("home.inviteFriend") }
    static func homeInviteShareCode(_ credits: Int) -> String { loc("home.inviteShareCode", credits) }
    static func homeBuyButton(_ price: String) -> String { loc("home.buyButton", price) }
    static var homeSelectPackage: String { loc("home.selectPackage") }
    static var homeOrBuyCredits: String { loc("home.orBuyCredits") }
    static var homeRecommended: String { loc("home.recommended") }
    static var homeCreditsNeverExpire: String { loc("home.creditsNeverExpire") }
    static var homeComingSoon: String { loc("home.comingSoon") }
    static var homeCopy: String { loc("home.copy") }
    static var homePopular: String { loc("home.popular") }
    static var homeBestValue: String { loc("home.bestValue") }
    static var homeMegaPack: String { loc("home.megaPack") }
    static var homeCredit: String { loc("home.credit") }
    static func homePerCredit(_ price: String) -> String { loc("home.perCredit", price) }
    static func homeSavingsPercent(_ percent: Int) -> String { loc("home.savingsPercent", percent) }
    static func homeCreditsPurchased(_ credits: Int) -> String { loc("home.creditsPurchased", credits) }
    static var homeLookSaveFailed: String { loc("home.lookSaveFailed") }
    static func homeFirstPurchaseBonus(_ credits: Int) -> String { loc("home.firstPurchaseBonus", credits) }

    // MARK: - Settings
    static var settingsTitle: String { loc("settings.title") }
    static var settingsGender: String { loc("settings.gender") }
    static var settingsGenderFemale: String { loc("settings.genderFemale") }
    static var settingsGenderMale: String { loc("settings.genderMale") }
    static var settingsGenderUpdated: String { loc("settings.genderUpdated") }
    static var settingsGeneral: String { loc("settings.general") }
    static var settingsAccount: String { loc("settings.account") }
    static var settingsSupport: String { loc("settings.support") }
    static var settingsLegal: String { loc("settings.legal") }

    // MARK: - Profile
    static var profileTitle: String { loc("profile.title") }
    static var profileInviteFriend: String { loc("profile.inviteFriend") }
    static var profileSettings: String { loc("profile.settings") }
    static var profileClosetColor: String { loc("profile.closetColor") }
    static var profileClosetColorTitle: String { loc("profile.closetColorTitle") }
    static var profileFeedback: String { loc("profile.feedback") }
    static var profileHelp: String { loc("profile.help") }
    static var profileSignOut: String { loc("profile.signOut") }
    static var profileSignOutTitle: String { loc("profile.signOutTitle") }
    static var profileSignOutConfirm: String { loc("profile.signOutConfirm") }
    static var profileSignOutFailed: String { loc("profile.signOutFailed") }
    static var profileUser: String { loc("profile.user") }
    static var profileLoadingUser: String { loc("profile.loadingUser") }
    static var profileReference: String { loc("profile.reference") }
    static var profileProMember: String { loc("profile.proMember") }
    static var profileFreeMember: String { loc("profile.freeMember") }
    static var profileRemainingCredits: String { loc("profile.remainingCredits") }
    static var profileProCredits: String { loc("profile.proCredits") }
    static var profileBuyCredits: String { loc("profile.buyCredits") }
    static var profilePurchasedCredits: String { loc("profile.purchasedCredits") }
    static var profileRenewalDate: String { loc("profile.renewalDate") }
    static var profileCreditInfoTitle: String { loc("profile.creditInfoTitle") }
    static func profileCreditInfoFree(_ credits: Int) -> String { loc("profile.creditInfoFree", credits) }
    static var profileCreditInfoPurchased: String { loc("profile.creditInfoPurchased") }
    static var profileCreditInfoPro: String { loc("profile.creditInfoPro") }
    static var profileWeeklyLimit: String { loc("profile.weeklyLimit") }
    static var profileMemberSince: String { loc("profile.memberSince") }
    static var profileUserId: String { loc("profile.userId") }
    static var profileTrials: String { loc("profile.trials") }
    static var profileFavorites: String { loc("profile.favorites") }
    static var profileCredits: String { loc("profile.credits") }
    static var profileInviteTitle: String { loc("profile.inviteTitle") }
    static func profileInviteDescription(_ credits: Int) -> String { loc("profile.inviteDescription", credits) }
    static var profileYourCode: String { loc("profile.yourCode") }
    static var profileCodeCopied: String { loc("profile.codeCopied") }
    static var profileInvitedCount: String { loc("profile.invitedCount") }
    static var profileShareCode: String { loc("profile.shareCode") }
    static var profileCodeError: String { loc("profile.codeError") }
    static var profileFeedbackTitle: String { loc("profile.feedbackTitle") }
    static var profileFeedbackDescription: String { loc("profile.feedbackDescription") }
    static var profileFeedbackTypeBug: String { loc("profile.feedbackTypeBug") }
    static var profileFeedbackTypeFeature: String { loc("profile.feedbackTypeFeature") }
    static var profileFeedbackTypeMessage: String { loc("profile.feedbackTypeMessage") }
    static var profileFeedbackSelectType: String { loc("profile.feedbackSelectType") }
    static var profileFeedbackPlaceholderBug: String { loc("profile.feedbackPlaceholderBug") }
    static var profileFeedbackPlaceholderFeature: String { loc("profile.feedbackPlaceholderFeature") }
    static var profileFeedbackPlaceholderMessage: String { loc("profile.feedbackPlaceholderMessage") }
    static var profileSend: String { loc("profile.send") }
    static var profileFeedbackThanks: String { loc("profile.feedbackThanks") }
    static var profileFeedbackSuccess: String { loc("profile.feedbackSuccess") }
    static var profileFeedbackEmail: String { loc("profile.feedbackEmail") }
    static var profileFeedbackEmailPlaceholder: String { loc("profile.feedbackEmailPlaceholder") }
    static var profileFeedbackDeviceInfo: String { loc("profile.feedbackDeviceInfo") }
    static var profileEditName: String { loc("profile.editName") }
    static var profileEditNameDescription: String { loc("profile.editNameDescription") }
    static var profileName: String { loc("profile.name") }
    static var profileFullName: String { loc("profile.fullName") }
    static var profileNameUpdated: String { loc("profile.nameUpdated") }
    static var profileNameUpdateFailed: String { loc("profile.nameUpdateFailed") }
    static var profileLanguageTitle: String { loc("profile.languageTitle") }
    static var profileLanguageInfo: String { loc("profile.languageInfo") }
    static var profileManageSubscription: String { loc("profile.manageSubscription") }

    // Account Deletion
    static var profileDeleteAccount: String { loc("profile.deleteAccount") }
    static var profileDeleteAccountTitle: String { loc("profile.deleteAccountTitle") }
    static var profileDeleteAccountMessage: String { loc("profile.deleteAccountMessage") }
    static var profileDeleteAccountConfirm: String { loc("profile.deleteAccountConfirm") }
    static var profileDeleteAccountSuccess: String { loc("profile.deleteAccountSuccess") }
    static var profileDeleteAccountFailed: String { loc("profile.deleteAccountFailed") }
    static var profileDeleteAccountRelogin: String { loc("profile.deleteAccountRelogin") }
    static var profileDeleteAccountDeleting: String { loc("profile.deleteAccountDeleting") }

    // Legal
    static var profilePrivacyPolicy: String { loc("profile.privacyPolicy") }
    static var profileTermsOfUse: String { loc("profile.termsOfUse") }

    // Data Protection
    static var profileDataProtection: String { loc("profile.dataProtection") }
    static var profileDataProtectionTitle: String { loc("profile.dataProtection.title") }
    static var profileDataProtectionEncryption: String { loc("profile.dataProtection.encryption") }
    static var profileDataProtectionEncryptionDesc: String { loc("profile.dataProtection.encryptionDesc") }
    static var profileDataProtectionNoThirdParty: String { loc("profile.dataProtection.noThirdParty") }
    static var profileDataProtectionNoThirdPartyDesc: String { loc("profile.dataProtection.noThirdPartyDesc") }
    static var profileDataProtectionSecureStorage: String { loc("profile.dataProtection.secureStorage") }
    static var profileDataProtectionSecureStorageDesc: String { loc("profile.dataProtection.secureStorageDesc") }
    static var profileDataProtectionDeleteAnytime: String { loc("profile.dataProtection.deleteAnytime") }
    static var profileDataProtectionDeleteAnytimeDesc: String { loc("profile.dataProtection.deleteAnytimeDesc") }

    // MARK: - Onboarding
    static var onboardingUploadError: String { loc("onboarding.uploadError") }
    static func onboardingStep(_ step: Int) -> String { loc("onboarding.step", step) }
    static var onboardingWelcomeStilya: String { loc("onboarding.welcome.stilya") }
    static var onboardingWelcomeUploadPhoto: String { loc("onboarding.welcome.uploadPhoto") }
    static var onboardingWelcomeUploadPhotoDesc: String { loc("onboarding.welcome.uploadPhotoDesc") }
    static var onboardingWelcomeSelectAndTry: String { loc("onboarding.welcome.selectAndTry") }
    static var onboardingWelcomeSelectAndTryDesc: String { loc("onboarding.welcome.selectAndTryDesc") }
    static var onboardingWelcomeSaveIfLiked: String { loc("onboarding.welcome.saveIfLiked") }
    static var onboardingWelcomeSaveIfLikedDesc: String { loc("onboarding.welcome.saveIfLikedDesc") }
    static var onboardingWelcomeDigitalCloset: String { loc("onboarding.welcome.digitalCloset") }
    static var onboardingWelcomeDigitalClosetDesc: String { loc("onboarding.welcome.digitalClosetDesc") }
    static var onboardingWelcomeEmailContinue: String { loc("onboarding.welcome.emailContinue") }
    static var onboardingWelcomeGuestContinue: String { loc("onboarding.welcome.guestContinue") }
    static var onboardingUploadTitle: String { loc("onboarding.upload.title") }
    static var onboardingUploadSubtitle: String { loc("onboarding.upload.subtitle") }
    static var onboardingUploadExampleImage: String { loc("onboarding.upload.exampleImage") }
    static var onboardingUploadTip1: String { loc("onboarding.upload.tip1") }
    static var onboardingUploadTip2: String { loc("onboarding.upload.tip2") }
    static var onboardingUploadTip3: String { loc("onboarding.upload.tip3") }
    static var onboardingUploadTip4: String { loc("onboarding.upload.tip4") }
    static var onboardingUploadTip5: String { loc("onboarding.upload.tip5") }
    static var onboardingUploadAddMoreBanner: String { loc("onboarding.upload.addMoreBanner") }
    static var onboardingUploadRequired: String { loc("onboarding.upload.required") }
    static var onboardingUploadOptional: String { loc("onboarding.upload.optional") }
    static var onboardingUploadHeight: String { loc("onboarding.upload.height") }
    static var onboardingUploadHeightShort: String { loc("onboarding.upload.heightShort") }
    static var onboardingUploadHeightMedium: String { loc("onboarding.upload.heightMedium") }
    static var onboardingUploadHeightTall: String { loc("onboarding.upload.heightTall") }
    static var onboardingUploadBodyType: String { loc("onboarding.upload.bodyType") }
    static var onboardingUploadBodyXsS: String { loc("onboarding.upload.bodyXsS") }
    static var onboardingUploadBodyM: String { loc("onboarding.upload.bodyM") }
    static var onboardingUploadBodyL: String { loc("onboarding.upload.bodyL") }
    static var onboardingUploadBodyXlXxl: String { loc("onboarding.upload.bodyXlXxl") }
    static var onboardingBodyDetailsTitle: String { loc("onboarding.bodyDetails.title") }
    static var onboardingBodyDetailsSubtitle: String { loc("onboarding.bodyDetails.subtitle") }
    static var onboardingBodyDetailsExampleLabel: String { loc("onboarding.bodyDetails.exampleLabel") }
    static var onboardingBodyDetailsExampleHint: String { loc("onboarding.bodyDetails.exampleHint") }
    static var onboardingBodyDetailsHeightTitle: String { loc("onboarding.bodyDetails.heightTitle") }
    static var onboardingBodyDetailsHeightHint: String { loc("onboarding.bodyDetails.heightHint") }
    static var onboardingBodyDetailsHeightNotSet: String { loc("onboarding.bodyDetails.heightNotSet") }
    static var onboardingBodyDetailsBodyTypeTitle: String { loc("onboarding.bodyDetails.bodyTypeTitle") }
    static var onboardingBodyDetailsBodyTypeSlim: String { loc("onboarding.bodyDetails.bodyTypeSlim") }
    static var onboardingBodyDetailsBodyTypeAverage: String { loc("onboarding.bodyDetails.bodyTypeAverage") }
    static var onboardingBodyDetailsBodyTypeAthletic: String { loc("onboarding.bodyDetails.bodyTypeAthletic") }
    static var onboardingBodyDetailsBodyTypeCurvy: String { loc("onboarding.bodyDetails.bodyTypeCurvy") }
    static var onboardingBodyDetailsBodyTypePlus: String { loc("onboarding.bodyDetails.bodyTypePlus") }
    static var onboardingUploadBodyPhoto: String { loc("onboarding.upload.bodyPhoto") }
    static var onboardingUploadBodyPhotoDesc: String { loc("onboarding.upload.bodyPhotoDesc") }
    static var onboardingUploadBodyPhotoAdd: String { loc("onboarding.upload.bodyPhotoAdd") }
    static var onboardingBodyTipEncrypted: String { loc("onboarding.body.tipEncrypted") }
    static var onboardingBodyTipPrivate: String { loc("onboarding.body.tipPrivate") }
    static var onboardingBodyTipAIOnly: String { loc("onboarding.body.tipAIOnly") }
    static var onboardingBodyTipDelete: String { loc("onboarding.body.tipDelete") }
    static var onboardingUploadChangePhoto: String { loc("onboarding.upload.changePhoto") }
    static var onboardingUploadSelectFromGallery: String { loc("onboarding.upload.selectFromGallery") }
    static var onboardingUploadTakePhoto: String { loc("onboarding.upload.takePhoto") }
    static var onboardingUploadCameraPermission: String { loc("onboarding.upload.cameraPermission") }
    static var onboardingUploadCameraPermissionDesc: String { loc("onboarding.upload.cameraPermissionDesc") }
    static var onboardingProcessingTitle: String { loc("onboarding.processing.title") }
    static var onboardingProcessingSubtitle: String { loc("onboarding.processing.subtitle") }
    static var onboardingProcessingPreparing: String { loc("onboarding.processing.preparing") }
    static var onboardingProcessingEncrypting: String { loc("onboarding.processing.encrypting") }
    static var onboardingProcessingUploading: String { loc("onboarding.processing.uploading") }
    static var onboardingProcessingCompleting: String { loc("onboarding.processing.completing") }
    static var onboardingProcessingEncryptingInfo: String { loc("onboarding.processing.encryptingInfo") }
    static var onboardingProcessingUploadingInfo: String { loc("onboarding.processing.uploadingInfo") }
    static var onboardingProcessingPrivateInfo: String { loc("onboarding.processing.privateInfo") }
    static var onboardingSuccessReady: String { loc("onboarding.success.ready") }
    static func onboardingSuccessWelcomeUser(_ name: String) -> String { loc("onboarding.success.welcomeUser", name) }
    static var onboardingSuccessStartTrying: String { loc("onboarding.success.startTrying") }
    static var onboardingSuccessReadyButton: String { loc("onboarding.success.readyButton") }
    static var onboardingSuccessStartExploring: String { loc("onboarding.success.startExploring") }

    // MARK: - TryOn
    static var tryonSelectType: String { loc("tryon.selectType") }
    static var tryonWhichGarment: String { loc("tryon.whichGarment") }
    static var tryonExamplePhotos: String { loc("tryon.examplePhotos") }
    static var tryonBestResultTip: String { loc("tryon.bestResultTip") }
    static var tryonFlatOrModelTip: String { loc("tryon.flatOrModelTip") }
    static var tryonPolaroidFlat: String { loc("tryon.polaroidFlat") }
    static var tryonPolaroidOnModel: String { loc("tryon.polaroidOnModel") }
    static var tryonTopDesc: String { loc("tryon.topDesc") }
    static var tryonBottomDesc: String { loc("tryon.bottomDesc") }
    static var tryonJacketDesc: String { loc("tryon.jacketDesc") }
    static var tryonDressDesc: String { loc("tryon.dressDesc") }
    static func tryonGarmentPhoto(_ type: String) -> String { loc("tryon.garmentPhoto", type) }
    static var tryonGarmentUploadSubtitle: String { loc("tryon.garmentUploadSubtitle") }
    static var tryonGarmentClear: String { loc("tryon.garmentClear") }
    static var tryonGarmentOnModel: String { loc("tryon.garmentOnModel") }
    static var tryonGoodLighting: String { loc("tryon.goodLighting") }
    static var tryonInnerClothingWarning: String { loc("tryon.innerClothingWarning") }
    static var tryonGarmentTipsTitle: String { loc("tryon.garmentTipsTitle") }
    static var tryonGarmentTipNoFace: String { loc("tryon.garmentTipNoFace") }
    static var tryonGarmentTipOnlyGarment: String { loc("tryon.garmentTipOnlyGarment") }
    static var tryonGarmentTipNoInner: String { loc("tryon.garmentTipNoInner") }
    static var tryonGarmentTipCleanBg: String { loc("tryon.garmentTipCleanBg") }
    static var tryonGarmentTipNoFaceBold: String { loc("tryon.garmentTipNoFaceBold") }
    static var tryonGarmentTipNoFaceDesc: String { loc("tryon.garmentTipNoFaceDesc") }
    static var tryonGarmentTipOnlyGarmentBold: String { loc("tryon.garmentTipOnlyGarmentBold") }
    static var tryonGarmentTipOnlyGarmentDesc: String { loc("tryon.garmentTipOnlyGarmentDesc") }
    static var tryonGarmentTipNoInnerBold: String { loc("tryon.garmentTipNoInnerBold") }
    static var tryonGarmentTipNoInnerDesc: String { loc("tryon.garmentTipNoInnerDesc") }
    static var tryonGarmentTipCleanBgBold: String { loc("tryon.garmentTipCleanBgBold") }
    static var tryonGarmentTipCleanBgDesc: String { loc("tryon.garmentTipCleanBgDesc") }
    static var tryonTry: String { loc("tryon.try") }
    static var tryonAddPhoto: String { loc("tryon.addPhoto") }
    static var tryonCameraOrGallery: String { loc("tryon.cameraOrGallery") }
    static var tryonResult: String { loc("tryon.result") }
    static var tryonSavedToGallery: String { loc("tryon.savedToGallery") }
    static var tryonSaveToGallery: String { loc("tryon.saveToGallery") }
    static var tryonTriedProduct: String { loc("tryon.triedProduct") }
    static var tryonAddToCart: String { loc("tryon.addToCart") }
    static var tryonSaveLook: String { loc("tryon.saveLook") }
    static var tryonSavedLook: String { loc("tryon.savedLook") }
    static var tryonModelNotFound: String { loc("tryon.modelNotFound") }
    static var tryonModelLoadFailed: String { loc("tryon.modelLoadFailed") }
    static var tryonInsufficientCredits: String { loc("tryon.insufficientCredits") }
    static var tryonSaveFailed: String { loc("tryon.saveFailed") }
    static var tryonGalleryPermission: String { loc("tryon.galleryPermission") }
    static var tryonGallerySaveFailed: String { loc("tryon.gallerySaveFailed") }
    static var tryonGallerySaved: String { loc("tryon.gallerySaved") }
    static var tryonUserNotFound: String { loc("tryon.userNotFound") }
    static var tryonResultNotFound: String { loc("tryon.resultNotFound") }
    static var tryonCartAddFailed: String { loc("tryon.cartAddFailed") }

    static var tryonProcessingAnalyzingPhotos: String { loc("tryon.processing.analyzingPhotos") }
    static var tryonProcessingMatchingGarment: String { loc("tryon.processing.matchingGarment") }
    static var tryonProcessingApplyingStyle: String { loc("tryon.processing.applyingStyle") }
    static var tryonProcessingGeneratingImage: String { loc("tryon.processing.generatingImage") }
    static var tryonProcessingFinalTouches: String { loc("tryon.processing.finalTouches") }
    static var tryonProcessingReady: String { loc("tryon.processing.ready") }
    static var tryonProcessingAnalyzingDesc: String { loc("tryon.processing.analyzingDesc") }
    static var tryonProcessingMatchingDesc: String { loc("tryon.processing.matchingDesc") }
    static var tryonProcessingStyleDesc: String { loc("tryon.processing.styleDesc") }
    static var tryonProcessingGeneratingDesc: String { loc("tryon.processing.generatingDesc") }
    static var tryonProcessingFinalDesc: String { loc("tryon.processing.finalDesc") }
    static var tryonProcessingReadyDesc: String { loc("tryon.processing.readyDesc") }

    static var tryonTipsPlainColors: String { loc("tryon.tips.plainColors") }
    static var tryonTipsAccessoryCompletes: String { loc("tryon.tips.accessoryCompletes") }
    static var tryonTipsRightSize: String { loc("tryon.tips.rightSize") }
    static var tryonTipsContrastColors: String { loc("tryon.tips.contrastColors") }
    static var tryonTipsLessIsMore: String { loc("tryon.tips.lessIsMore") }

    // MARK: - Weather Tips
    static var weatherTipHot: String { loc("weather.tip.hot") }
    static var weatherTipWarm: String { loc("weather.tip.warm") }
    static var weatherTipCool: String { loc("weather.tip.cool") }
    static var weatherTipCold: String { loc("weather.tip.cold") }
    static var weatherTipRainy: String { loc("weather.tip.rainy") }
    static var weatherTipSnowy: String { loc("weather.tip.snowy") }
    static var weatherLocationDeniedHint: String { loc("weather.location.deniedHint") }
    static var weatherLocationAlertTitle: String { loc("weather.location.alertTitle") }
    static var weatherLocationAlertMessage: String { loc("weather.location.alertMessage") }
    static var weatherLocationAlertSettings: String { loc("weather.location.alertSettings") }
    static var weatherLocationAlertCancel: String { loc("weather.location.alertCancel") }

    // MARK: - Ads
    static var adsWatchForCredit: String { loc("ads.watchForCredit") }
    static var adsRewardSuccess: String { loc("ads.rewardSuccess") }
    static var adsDailyLimitReached: String { loc("ads.dailyLimitReached") }
    static var adsAdNotReady: String { loc("ads.adNotReady") }
    static var adsUpgradeToPro: String { loc("ads.upgradeToPro") }
    static var proNoAdsFeature: String { loc("pro.noAdsFeature") }
    static var proNoAdsFeatureDesc: String { loc("pro.noAdsFeatureDesc") }
    static var proAIModelPhoto: String { loc("pro.aiModelPhoto") }
    static var proAIModelPhotoDesc: String { loc("pro.aiModelPhotoDesc") }
    static var proRemoveAdsBanner: String { loc("pro.removeAdsBanner") }
    static var proRemoveAdsBannerDesc: String { loc("pro.removeAdsBannerDesc") }
    static var proUnlimitedTries: String { loc("pro.unlimitedTries") }
    static var proUnlimitedTriesDesc: String { loc("pro.unlimitedTriesDesc") }

    static var tryonCropTopGuide: String { loc("tryon.crop.topGuide") }
    static var tryonCropBottomGuide: String { loc("tryon.crop.bottomGuide") }
    static var tryonCropDressGuide: String { loc("tryon.crop.dressGuide") }
    static var tryonCropJacketGuide: String { loc("tryon.crop.jacketGuide") }
    static var tryonCropShoesGuide: String { loc("tryon.crop.shoesGuide") }
    static var tryonCropResizeHint: String { loc("tryon.crop.resizeHint") }
    static var tryonCropDefaultGuide: String { loc("tryon.crop.defaultGuide") }
    static var tryonCropCrop: String { loc("tryon.crop.crop") }
    static var tryonCropReset: String { loc("tryon.crop.reset") }
    static var tryonCropApply: String { loc("tryon.crop.apply") }
    static var tryonCropBetterOnModel: String { loc("tryon.crop.betterOnModel") }

    static var tryonCartProductLink: String { loc("tryon.cart.productLink") }
    static var tryonCartProductLinkPlaceholder: String { loc("tryon.cart.productLinkPlaceholder") }
    static var tryonCartBrandOptional: String { loc("tryon.cart.brandOptional") }
    static var tryonCartBrandPlaceholder: String { loc("tryon.cart.brandPlaceholder") }
    static var tryonCartPriceOptional: String { loc("tryon.cart.priceOptional") }
    static var tryonCartPricePlaceholder: String { loc("tryon.cart.pricePlaceholder") }
    static var tryonCartAddToCartButton: String { loc("tryon.cart.addToCartButton") }
    static var tryonCartProductInfo: String { loc("tryon.cart.productInfo") }
    static var tryonCartInvalidLink: String { loc("tryon.cart.invalidLink") }

    // MARK: - Combo
    static var comboTitle: String { loc("combo.title") }
    static var comboWarning: String { loc("combo.warning") }
    static var comboSelectAtLeastOne: String { loc("combo.selectAtLeastOne") }
    static var comboGarments: String { loc("combo.garments") }
    static var comboAccessories: String { loc("combo.accessories") }
    static func comboAccessoryCount(_ current: Int, _ max: Int) -> String { loc("combo.accessoryCount", current, max) }
    static var comboOptional: String { loc("combo.optional") }
    static func comboMaxAccessories(_ max: Int) -> String { loc("combo.maxAccessories", max) }
    static var comboSelected: String { loc("combo.selected") }
    static func comboCreateButton(_ items: Int) -> String { loc("combo.createButton", items) }
    static var comboCreateButtonSimple: String { loc("combo.createButtonSimple") }
    static var comboDressConflict: String { loc("combo.dressConflict") }
    static var comboResult: String { loc("combo.result") }
    static var comboDetails: String { loc("combo.details") }
    static func comboAddedToCart(_ name: String) -> String { loc("combo.addedToCart", name) }

    static var comboProcessingPreparing: String { loc("combo.processing.preparing") }
    static var comboProcessingPreparingDesc: String { loc("combo.processing.preparingDesc") }
    static var comboProcessingAnalyzing: String { loc("combo.processing.analyzing") }
    static func comboProcessingAnalyzingDesc(_ name: String) -> String { loc("combo.processing.analyzingDesc", name) }
    static func comboProcessingApplyingGarment(_ name: String) -> String { loc("combo.processing.applyingGarment", name) }
    static func comboProcessingGarmentDesc(_ index: Int, _ total: Int) -> String { loc("combo.processing.garmentDesc", index, total) }
    static var comboProcessingFinalizing: String { loc("combo.processing.finalizing") }
    static var comboProcessingFinalizingDesc: String { loc("combo.processing.finalizingDesc") }
    static var comboProcessingReady: String { loc("combo.processing.ready") }
    static var comboProcessingReadyDesc: String { loc("combo.processing.readyDesc") }
    static var comboSaveFailed: String { loc("combo.saveFailed") }
    static var comboCartAddFailed: String { loc("combo.cartAddFailed") }

    // MARK: - Pro
    static var proTitle: String { loc("pro.title") }
    static var proSubtitle: String { loc("pro.subtitle") }
    static var proWeeklyCredits: String { loc("pro.weeklyCredits") }
    static func proWeeklyCreditsDesc(_ credits: Int) -> String { loc("pro.weeklyCreditsDesc", credits) }
    static func proMonthlyCreditsDesc(_ credits: Int) -> String { loc("pro.monthlyCreditsDesc", credits) }
    static var proComboFeature: String { loc("pro.comboFeature") }
    static var proComboFeatureDesc: String { loc("pro.comboFeatureDesc") }
    static var proPriorityProcessing: String { loc("pro.priorityProcessing") }
    static var proPriorityProcessingDesc: String { loc("pro.priorityProcessingDesc") }
    static var proClosetFeature: String { loc("pro.closetFeature") }
    static var proClosetFeatureDesc: String { loc("pro.closetFeatureDesc") }
    static var proWeekly: String { loc("pro.weekly") }
    static var proPerWeek: String { loc("pro.perWeek") }
    static var proMonthly: String { loc("pro.monthly") }
    static var proPerMonth: String { loc("pro.perMonth") }
    static var proBestValue: String { loc("pro.bestValue") }
    static var proLaunchPrice: String { loc("pro.launchPrice") }
    static var proUpgrade: String { loc("pro.upgrade") }
    static var proComingSoon: String { loc("pro.comingSoon") }
    static var proWeeklyAutoRenew: String { loc("pro.weeklyAutoRenew") }
    static var proMonthlyAutoRenew: String { loc("pro.monthlyAutoRenew") }
    static var proRestore: String { loc("pro.restore") }
    static var proPurchaseError: String { loc("pro.purchaseError") }
    static var proRestoreError: String { loc("pro.restoreError") }
    static var proRestoreNoPurchases: String { loc("pro.restoreNoPurchases") }
    static var proAiEditFeature: String { loc("pro.aiEditFeature") }
    static var proAiEditFeatureDesc: String { loc("pro.aiEditFeatureDesc") }

    // MARK: - Cart
    static var cartEmpty: String { loc("cart.empty") }
    static var cartFilterEmpty: String { loc("cart.filterEmpty") }
    static var cartEmptyDescription: String { loc("cart.emptyDescription") }
    static var cartStartTrying: String { loc("cart.startTrying") }
    static var cartAll: String { loc("cart.all") }
    static var cartTotal: String { loc("cart.total") }
    static func cartItemCount(_ count: Int) -> String { loc("cart.itemCount", count) }
    static var cartBuy: String { loc("cart.buy") }
    static var cartPurchased: String { loc("cart.purchased") }
    static var cartDisclaimer: String { loc("cart.disclaimer") }
    static var cartEditProduct: String { loc("cart.editProduct") }
    static var cartSaveEdit: String { loc("cart.saveEdit") }

    // MARK: - Looks
    static var looksTitle: String { loc("looks.title") }
    static var looksEmpty: String { loc("looks.empty") }
    static var looksCombo: String { loc("looks.combo") }
    static var looksTabAll: String { loc("looks.tabAll") }
    static var looksTabCloset: String { loc("looks.tabCloset") }
    static var looksEmptyCloset: String { loc("looks.emptyCloset") }

    // MARK: - Credits
    static func creditsCount(_ count: Int) -> String { loc("credits.count", count) }
    static var creditsAdd: String { loc("credits.add") }
    static var creditsInvite: String { loc("credits.invite") }
    static var creditsPro: String { loc("credits.pro") }
    static func creditsProRemaining(_ count: Int) -> String { loc("credits.proRemaining", count) }
    static func creditsWeeklyFree(_ count: Int) -> String { loc("credits.weeklyFree", count) }
    static func creditsRenewsInDaysHours(_ days: Int, _ hours: Int) -> String { loc("credits.renewsInDaysHours", days, hours) }
    static func creditsRenewsInHours(_ hours: Int) -> String { loc("credits.renewsInHours", hours) }
    static var creditsInviteAndEarn: String { loc("credits.inviteAndEarn") }
    static var creditsProLabel: String { loc("credits.proLabel") }

    // MARK: - Garment Types
    static var garmentTop: String { loc("garment.top") }
    static var garmentBottom: String { loc("garment.bottom") }
    static var garmentDress: String { loc("garment.dress") }
    static var garmentJacket: String { loc("garment.jacket") }
    static var garmentGlasses: String { loc("garment.glasses") }
    static var garmentSunglasses: String { loc("garment.sunglasses") }
    static var garmentHat: String { loc("garment.hat") }
    static var garmentScarf: String { loc("garment.scarf") }
    static var garmentShoes: String { loc("garment.shoes") }
    static var garmentBag: String { loc("garment.bag") }
    static var garmentSocks: String { loc("garment.socks") }
    static var accessoryNecklace: String { loc("accessory.necklace") }
    static var accessoryEarrings: String { loc("accessory.earrings") }
    static var accessoryWatch: String { loc("accessory.watch") }
    static var accessoryBracelet: String { loc("accessory.bracelet") }
    static var accessoryRing: String { loc("accessory.ring") }
    static var accessoryBelt: String { loc("accessory.belt") }

    // MARK: - Auth
    static var authContinueApple: String { loc("auth.continueApple") }
    static var authContinueGoogle: String { loc("auth.continueGoogle") }
    static var authEmailContinue: String { loc("auth.emailContinue") }
    static var authSignUp: String { loc("auth.signUp") }
    static var authSignIn: String { loc("auth.signIn") }
    static var authCreateAccount: String { loc("auth.createAccount") }
    static var authCreateAccountSubtitle: String { loc("auth.createAccountSubtitle") }
    static var authPasswordMin6: String { loc("auth.passwordMin6") }
    static var authPasswordConfirm: String { loc("auth.passwordConfirm") }
    static var authPasswordMismatch: String { loc("auth.passwordMismatch") }
    static var authHaveReferralCode: String { loc("auth.haveReferralCode") }
    static var authEnterReferralCode: String { loc("auth.enterReferralCode") }
    static var authPaste: String { loc("auth.paste") }
    static var authTermsAgreement: String { loc("auth.termsAgreement") }
    static var authPrivacyPolicy: String { loc("auth.privacyPolicy") }
    static var authTermsOfUse: String { loc("auth.termsOfUse") }
    static var authAlreadyHaveAccount: String { loc("auth.alreadyHaveAccount") }
    static var authReferralSuccess: String { loc("auth.referralSuccess") }
    static var authReferralFailedButAccountCreated: String { loc("auth.referralFailedButAccountCreated") }

    // MARK: - TryOn (extra)
    static var tryonCartAddedSuccess: String { loc("tryon.cartAddedSuccess") }

    // MARK: - Combo (extra)
    static var comboAccessoryGroupHeadFace: String { loc("combo.accessoryGroupHeadFace") }
    static var comboAccessoryGroupJewelry: String { loc("combo.accessoryGroupJewelry") }
    static var comboAccessoryGroupFootOther: String { loc("combo.accessoryGroupFootOther") }
    static var comboAdd: String { loc("combo.add") }
    static var comboBagHint: String { loc("combo.bagHint") }
    static var comboJacketOpen: String { loc("combo.jacket.open") }
    static var comboJacketClosed: String { loc("combo.jacket.closed") }
    static var comboJacketFrontLabel: String { loc("combo.jacket.frontLabel") }

    // MARK: - Onboarding Complete
    static var onboardingCompleteReady: String { loc("onboarding.complete.ready") }
    static var onboardingCompleteCanTryOn: String { loc("onboarding.complete.canTryOn") }
    static var onboardingCompleteProtectAccount: String { loc("onboarding.complete.protectAccount") }
    static var onboardingCompleteProtectAccountDesc: String { loc("onboarding.complete.protectAccountDesc") }
    static var onboardingCompleteContinueApple: String { loc("onboarding.complete.continueApple") }
    static var onboardingCompleteContinueGoogle: String { loc("onboarding.complete.continueGoogle") }
    static var onboardingCompleteNotNow: String { loc("onboarding.complete.notNow") }

    // MARK: - Onboarding Setup
    static var onboardingSetupTitle: String { loc("onboarding.setup.title") }
    static var onboardingSetupSubtitle: String { loc("onboarding.setup.subtitle") }
    static var onboardingSetupName: String { loc("onboarding.setup.name") }
    static var onboardingSetupNamePlaceholder: String { loc("onboarding.setup.namePlaceholder") }
    static var onboardingSetupGender: String { loc("onboarding.setup.gender") }
    static var onboardingSetupGenderDesc: String { loc("onboarding.setup.genderDesc") }
    static var onboardingSetupFemale: String { loc("onboarding.setup.female") }
    static var onboardingSetupMale: String { loc("onboarding.setup.male") }
    static var onboardingSetupUnspecified: String { loc("onboarding.setup.unspecified") }

    // MARK: - Onboarding Crop
    static var onboardingCropTitle: String { loc("onboarding.crop.title") }
    static var onboardingCropConfirm: String { loc("onboarding.crop.confirm") }
    static var onboardingCropFrameBody: String { loc("onboarding.crop.frameBody") }
    static var onboardingCropSimpleTip: String { loc("onboarding.crop.simpleTip") }
    static var cropBgRemove: String { loc("onboarding.crop.bgRemove") }
    static var cropBgRemoveUndo: String { loc("onboarding.crop.bgRemoveUndo") }

    // MARK: - Onboarding Magic
    static var onboardingMagicTitle: String { loc("onboarding.magic.title") }
    static var onboardingMagicSubtitle: String { loc("onboarding.magic.subtitle") }
    static var onboardingMagicPreparing: String { loc("onboarding.magic.preparing") }
    static var onboardingMagicProcessing: String { loc("onboarding.magic.processing") }
    static var onboardingMagicAiWorking: String { loc("onboarding.magic.aiWorking") }
    static var onboardingMagicAlmostReady: String { loc("onboarding.magic.almostReady") }
    static var onboardingMagicDone: String { loc("onboarding.magic.done") }

    // MARK: - Auth (extra)
    static var authWelcomeBack: String { loc("auth.welcomeBack") }
    static var authSignInSubtitle: String { loc("auth.signInSubtitle") }
    static var authPassword: String { loc("auth.password") }
    static var authNoAccount: String { loc("auth.noAccount") }
    static var authSignOutFailed: String { loc("auth.signOutFailed") }
    static var authReauthTitle: String { loc("auth.reauthTitle") }
    static var authReauthMessage: String { loc("auth.reauthMessage") }

    // MARK: - Common (extra)
    static var commonConfirm: String { loc("common.confirm") }

    // MARK: - Combo (extra)
    static var comboCreateFirst: String { loc("combo.createFirst") }

    // MARK: - Error Messages
    static var errorGeneric: String { loc("error.generic") }
    static var errorEmailInUse: String { loc("error.emailInUse") }
    static var errorInvalidEmail: String { loc("error.invalidEmail") }
    static var errorWeakPassword: String { loc("error.weakPassword") }
    static var errorWrongPassword: String { loc("error.wrongPassword") }
    static var errorUserNotFound: String { loc("error.userNotFound") }
    static var errorUserDisabled: String { loc("error.userDisabled") }
    static var errorNetworkError: String { loc("error.networkError") }
    static var errorTooManyRequests: String { loc("error.tooManyRequests") }
    static var errorInvalidCredential: String { loc("error.invalidCredential") }
    static var errorCredentialInUse: String { loc("error.credentialInUse") }
    static var errorDifferentCredential: String { loc("error.differentCredential") }
    static var errorRecentLogin: String { loc("error.recentLogin") }
    static var errorInvalidAPIKey: String { loc("error.invalidAPIKey") }
    static var errorSignInFailed: String { loc("error.signInFailed") }
    static var errorUserLoadFailed: String { loc("error.userLoadFailed") }
    static var errorDeviceBlocked: String { loc("error.deviceBlocked") }
    static var deviceBlockedContactSupport: String { loc("deviceBlocked.contactSupport") }
    static var deviceBlockedEmailSubject: String { loc("deviceBlocked.emailSubject") }
    static var deviceBlockedEmailBody: String { loc("deviceBlocked.emailBody") }

    // MARK: - Credit Abuse
    static var creditAbuseTitle: String { loc("creditAbuse.title") }
    static var creditAbuseMessage: String { loc("creditAbuse.message") }

    // MARK: - Model Photo Sheet
    static var modelPhotoTitle: String { loc("modelPhoto.title") }
    static var modelPhotoNoPhoto: String { loc("modelPhoto.noPhoto") }
    static var modelPhotoTip: String { loc("modelPhoto.tip") }
    static var modelPhotoGallery: String { loc("modelPhoto.gallery") }
    static var modelPhotoCamera: String { loc("modelPhoto.camera") }
    static var modelPhotoLoadError: String { loc("modelPhoto.loadError") }
    static var modelPhotoUserNotFound: String { loc("modelPhoto.userNotFound") }
    static var modelPhotoUpdateError: String { loc("modelPhoto.updateError") }
    static var modelPhotoConvertError: String { loc("modelPhoto.convertError") }
    static var modelPhotoAIGenerate: String { loc("modelPhoto.aiGenerate") }
    static var modelPhotoAIGenerating: String { loc("modelPhoto.aiGenerating") }
    static var modelPhotoAIGeneratingSubtitle: String { loc("modelPhoto.aiGeneratingSubtitle") }
    static var modelPhotoAIReviewTitle: String { loc("modelPhoto.aiReviewTitle") }
    static var modelPhotoUseThisPhoto: String { loc("modelPhoto.useThisPhoto") }
    static var modelPhotoSelectFromGallery: String { loc("modelPhoto.selectFromGallery") }
    static var modelPhotoTakeSelfie: String { loc("modelPhoto.takeSelfie") }
    static var modelPhotoTakeSelfieSubtitle: String { loc("modelPhoto.takeSelfieSubtitle") }
    static var modelPhotoBodyInfo: String { loc("modelPhoto.bodyInfo") }
    static var modelPhotoCreate: String { loc("modelPhoto.create") }
    static var modelPhotoLimitReached: String { loc("modelPhoto.limitReached") }
    static var modelPhotoAIError: String { loc("modelPhoto.aiError") }
    static var modelPhotoDownloading: String { loc("modelPhoto.downloading") }
    static var modelPhotoICloudError: String { loc("modelPhoto.icloudError") }
    static var modelPhotoReviewTitle: String { loc("modelPhoto.reviewTitle") }
    static var modelPhotoReviewSubtitle: String { loc("modelPhoto.reviewSubtitle") }
    static var modelPhotoRetry: String { loc("modelPhoto.retry") }
    static func modelPhotoGenerateAnother(_ remaining: Int) -> String { loc("modelPhoto.generateAnother", remaining) }
    static func modelPhotoAIRemaining(_ count: Int) -> String { loc("modelPhoto.aiRemaining", count) }
    static var modelPhotoResetsWeekly: String { loc("modelPhoto.resetsWeekly") }
    static var modelPhotoGeneratingTitle: String { loc("modelPhoto.generatingTitle") }
    static var modelPhotoGeneratingSubtitle: String { loc("modelPhoto.generatingSubtitle") }
    static var modelPhotoStepFaceAnalysis: String { loc("modelPhoto.stepFaceAnalysis") }
    static var modelPhotoStepBodyGeneration: String { loc("modelPhoto.stepBodyGeneration") }
    static var modelPhotoStepSkinTone: String { loc("modelPhoto.stepSkinTone") }

    // MARK: - Pending Model
    static var pendingModelReadyTitle: String { loc("pendingModel.readyTitle") }
    static var pendingModelReadySubtitle: String { loc("pendingModel.readySubtitle") }
    static var modelPhotoSelfieLabel: String { loc("modelPhoto.selfieLabel") }

    // MARK: - Image Picker
    static var imagePickerTitle: String { loc("imagePicker.title") }
    static var imagePickerTakePhoto: String { loc("imagePicker.takePhoto") }
    static var imagePickerTakePhotoDesc: String { loc("imagePicker.takePhotoDesc") }
    static var imagePickerGallery: String { loc("imagePicker.gallery") }
    static var imagePickerGalleryDesc: String { loc("imagePicker.galleryDesc") }

    // MARK: - Cart (extra)
    static var cartTitle: String { loc("cart.title") }
    static var cartLoading: String { loc("cart.loading") }
    static var cartDeleteSelected: String { loc("cart.deleteSelected") }

    // MARK: - Common (extra)
    static var commonLoadMore: String { loc("common.loadMore") }

    // MARK: - Home (Trend Card)
    static var homeTrendCard: String { loc("home.trendCard") }
    static var homeTrendExplore: String { loc("home.trendExplore") }
    static var homeTrendCardTitle: String { loc("home.trendCardTitle") }

    // MARK: - Trend Magazine
    static var trendSeason: String { loc("trend.season") }
    static var trendMagazineTitle: String { loc("trend.magazineTitle") }
    static var trendMagazineSubtitle: String { loc("trend.magazineSubtitle") }

    // Colors
    static var trendColorsTitle: String { loc("trend.colors.title") }
    static var trendColorsSubtitle: String { loc("trend.colors.subtitle") }
    static var trendColorBurgundy: String { loc("trend.color.burgundy") }
    static var trendColorBurgundyDesc: String { loc("trend.color.burgundyDesc") }
    static var trendColorOlive: String { loc("trend.color.olive") }
    static var trendColorOliveDesc: String { loc("trend.color.oliveDesc") }
    static var trendColorLavender: String { loc("trend.color.lavender") }
    static var trendColorLavenderDesc: String { loc("trend.color.lavenderDesc") }
    static var trendColorCamel: String { loc("trend.color.camel") }
    static var trendColorCamelDesc: String { loc("trend.color.camelDesc") }
    static var trendColorPebbleGray: String { loc("trend.color.pebbleGray") }
    static var trendColorPebbleGrayDesc: String { loc("trend.color.pebbleGrayDesc") }
    static var trendColorChocolate: String { loc("trend.color.chocolate") }
    static var trendColorChocolateDesc: String { loc("trend.color.chocolateDesc") }

    // Pieces
    static var trendPiecesTitle: String { loc("trend.pieces.title") }
    static var trendPiecesSubtitle: String { loc("trend.pieces.subtitle") }
    static var trendPieceOversizedBlazer: String { loc("trend.piece.oversizedBlazer") }
    static var trendPieceOversizedBlazerDesc: String { loc("trend.piece.oversizedBlazerDesc") }
    static var trendPiecePoloSweater: String { loc("trend.piece.poloSweater") }
    static var trendPiecePoloSweaterDesc: String { loc("trend.piece.poloSweaterDesc") }
    static var trendPiecePencilSkirt: String { loc("trend.piece.pencilSkirt") }
    static var trendPiecePencilSkirtDesc: String { loc("trend.piece.pencilSkirtDesc") }
    static var trendPieceLeatherPieces: String { loc("trend.piece.leatherPieces") }
    static var trendPieceLeatherPiecesDesc: String { loc("trend.piece.leatherPiecesDesc") }
    static var trendPieceCroppedJacket: String { loc("trend.piece.croppedJacket") }
    static var trendPieceCroppedJacketDesc: String { loc("trend.piece.croppedJacketDesc") }
    static var trendPieceMiniDress: String { loc("trend.piece.miniDress") }
    static var trendPieceMiniDressDesc: String { loc("trend.piece.miniDressDesc") }

    // Shoes
    static var trendShoesTitle: String { loc("trend.shoes.title") }
    static var trendShoesSubtitle: String { loc("trend.shoes.subtitle") }
    static var trendShoeCowboyBoots: String { loc("trend.shoe.cowboyBoots") }
    static var trendShoeCowboyBootsDesc: String { loc("trend.shoe.cowboyBootsDesc") }
    static var trendShoeSlouchyBoots: String { loc("trend.shoe.slouchyBoots") }
    static var trendShoeSlouchyBootsDesc: String { loc("trend.shoe.slouchyBootsDesc") }
    static var trendShoeBalletFlats: String { loc("trend.shoe.balletFlats") }
    static var trendShoeBalletFlatsDesc: String { loc("trend.shoe.balletFlatsDesc") }
    static var trendShoeKneeHighBoots: String { loc("trend.shoe.kneeHighBoots") }
    static var trendShoeKneeHighBootsDesc: String { loc("trend.shoe.kneeHighBootsDesc") }

    // Accessories
    static var trendAccessoriesTitle: String { loc("trend.accessories.title") }
    static var trendAccessoriesSubtitle: String { loc("trend.accessories.subtitle") }
    static var trendAccessoryChunkyScarf: String { loc("trend.accessory.chunkyScarf") }
    static var trendAccessoryChunkyScarfDesc: String { loc("trend.accessory.chunkyScarfDesc") }
    static var trendAccessoryGoldJewelry: String { loc("trend.accessory.goldJewelry") }
    static var trendAccessoryGoldJewelryDesc: String { loc("trend.accessory.goldJewelryDesc") }
    static var trendAccessoryStructuredBag: String { loc("trend.accessory.structuredBag") }
    static var trendAccessoryStructuredBagDesc: String { loc("trend.accessory.structuredBagDesc") }
    static var trendAccessoryOversizedSunglasses: String { loc("trend.accessory.oversizedSunglasses") }
    static var trendAccessoryOversizedSunglassesDesc: String { loc("trend.accessory.oversizedSunglassesDesc") }
    static var trendReadMore: String { loc("trend.readMore") }

    // MARK: - Trend Collections
    static var trendsTitle: String { loc("trends.title") }
    static var trendsCollections: String { loc("trends.collections") }
    static var trendsMagazine: String { loc("trends.magazine") }
    static var trendsTryOn: String { loc("trends.tryOn") }
    static var trendsAllCategories: String { loc("trends.allCategories") }
    static var trendsDownloading: String { loc("trends.downloading") }
    static var trendsImageLoadError: String { loc("trends.imageLoadError") }
    static var trendsEmpty: String { loc("trends.empty") }
    static var trendsCategoryCasual: String { loc("trends.category.casual") }
    static var trendsCategoryElegant: String { loc("trends.category.elegant") }
    static var trendsCategoryStreetwear: String { loc("trends.category.streetwear") }
    static var trendsCategorySporty: String { loc("trends.category.sporty") }
    static var trendsCategoryBohemian: String { loc("trends.category.bohemian") }
    static var trendsCategoryMinimal: String { loc("trends.category.minimal") }
    static var trendsForYou: String { loc("trends.forYou") }
    static var trendsFavorites: String { loc("trends.favorites") }
    static var trendsFavoritesEmpty: String { loc("trends.favoritesEmpty") }
    static var trendsFavoritesEmptyDesc: String { loc("trends.favoritesEmptyDesc") }
    static var trendsSaveToFavorites: String { loc("trends.saveToFavorites") }
    static var trendsRemoveFromFavorites: String { loc("trends.removeFromFavorites") }
    static var trendsMakeCombo: String { loc("trends.makeCombo") }
    static var trendsOutfitReference: String { loc("trends.outfitReference") }
    static var trendsChooseSource: String { loc("trends.chooseSource") }
    static var trendsCropFromOutfit: String { loc("trends.cropFromOutfit") }
    static var trendsUploadFromGallery: String { loc("trends.uploadFromGallery") }

    // MARK: - Garment BG Removal
    static var garmentRemoveBg: String { loc("garment.removeBg") }
    static var garmentUndoBgRemoval: String { loc("garment.undoBgRemoval") }

    // MARK: - Onboarding Reference Choice
    static var onboardingRefChoiceTitle: String { loc("onboarding.refChoice.title") }
    static var onboardingRefChoiceSubtitle: String { loc("onboarding.refChoice.subtitle") }
    static var onboardingRefChoiceUploadGallery: String { loc("onboarding.refChoice.uploadGallery") }
    static var onboardingRefChoiceUploadGalleryDesc: String { loc("onboarding.refChoice.uploadGalleryDesc") }
    static var onboardingRefChoiceCreateAI: String { loc("onboarding.refChoice.createAI") }
    static var onboardingRefChoiceCreateAIDesc: String { loc("onboarding.refChoice.createAIDesc") }
    static var onboardingRefChoiceRecommended: String { loc("onboarding.refChoice.recommended") }
    static var onboardingRefChoiceAIResultLabel: String { loc("onboarding.refChoice.aiResultLabel") }
    static var onboardingRefChoiceOrDivider: String { loc("onboarding.refChoice.orDivider") }

    // MARK: - Onboarding Errors
    static var onboardingReviewUploadOwn: String { loc("onboarding.review.uploadOwn") }
    static var onboardingSelectPhoto: String { loc("onboarding.selectPhoto") }
    static var onboardingUploadFailed: String { loc("onboarding.uploadFailed") }
    static var onboardingUploadRetry: String { loc("onboarding.uploadRetry") }

    // MARK: - Looks Errors
    static var looksLoadError: String { loc("looks.loadError") }
    static var looksFavoriteError: String { loc("looks.favoriteError") }
    static var looksDeleteConfirmation: String { loc("looks.deleteConfirmation") }
    static var looksDeleteError: String { loc("looks.deleteError") }

    // MARK: - Combo Errors
    static var comboNoItemSelected: String { loc("combo.noItemSelected") }
    static var comboFailed: String { loc("combo.failed") }
    static var comboPreparing: String { loc("combo.preparing") }
    static var comboApplyingGarments: String { loc("combo.applyingGarments") }
    static var comboFinalizing: String { loc("combo.finalizing") }
    static var comboDone: String { loc("combo.done") }

    // MARK: - Tab Bar
    static var tabHome: String { loc("tab.home") }
    static var tabPro: String { loc("tab.pro") }
    static var tabProfile: String { loc("tab.profile") }

    // MARK: - AI Data Consent
    static var aiConsentTitle: String { loc("aiConsent.title") }
    static var aiConsentSubtitle: String { loc("aiConsent.subtitle") }
    static var aiConsentWhatIsSent: String { loc("aiConsent.whatIsSent") }
    static var aiConsentWhatIsSentDesc: String { loc("aiConsent.whatIsSentDesc") }
    static var aiConsentWhoReceives: String { loc("aiConsent.whoReceives") }
    static var aiConsentWhoReceivesDesc: String { loc("aiConsent.whoReceivesDesc") }
    static var aiConsentEncryption: String { loc("aiConsent.encryption") }
    static var aiConsentEncryptionDesc: String { loc("aiConsent.encryptionDesc") }
    static var aiConsentPrivacyLink: String { loc("aiConsent.privacyLink") }
    static var aiConsentAgree: String { loc("aiConsent.agree") }
    static var aiConsentDecline: String { loc("aiConsent.decline") }

    // MARK: - Onboarding Closet Color
    static var onboardingClosetColorTitle: String { loc("onboarding.closetColor.title") }
    static var onboardingClosetColorSubtitle: String { loc("onboarding.closetColor.subtitle") }
    static var onboardingClosetColorDarkWood: String { loc("onboarding.closetColor.darkWood") }
    static var onboardingClosetColorLightWood: String { loc("onboarding.closetColor.lightWood") }
    static var onboardingClosetColorWhite: String { loc("onboarding.closetColor.white") }
    static var onboardingClosetColorBlack: String { loc("onboarding.closetColor.black") }
    static var onboardingClosetColorNavy: String { loc("onboarding.closetColor.navy") }
    static var onboardingClosetColorGreen: String { loc("onboarding.closetColor.green") }
    static var onboardingClosetColorPink: String { loc("onboarding.closetColor.pink") }
    static var onboardingClosetColorYellow: String { loc("onboarding.closetColor.yellow") }
    static var onboardingClosetColorPurple: String { loc("onboarding.closetColor.purple") }
    static var onboardingClosetColorRed: String { loc("onboarding.closetColor.red") }

    // MARK: - New Onboarding Flow (v1.2)
    static var onboardingGenderTitle: String { loc("onboarding.gender.title") }
    static var onboardingGenderSubtitle: String { loc("onboarding.gender.subtitle") }

    static var onboardingAgeTitle: String { loc("onboarding.age.title") }
    static var onboardingAgeSubtitle: String { loc("onboarding.age.subtitle") }

    static var onboardingHearTitle: String { loc("onboarding.hear.title") }
    static var onboardingHearSubtitle: String { loc("onboarding.hear.subtitle") }

    static var onboardingShowcaseGetStarted: String { loc("onboarding.showcase.getStarted") }

    static var onboardingRateTitle: String { loc("onboarding.rate.title") }
    static var onboardingRateSubtitle: String { loc("onboarding.rate.subtitle") }
    static var onboardingRateThankYou: String { loc("onboarding.rate.thankYou") }
    static var onboardingRateSkip: String { loc("onboarding.rate.skip") }

    static var onboardingStyleTitle: String { loc("onboarding.style.title") }
    static var onboardingStyleSubtitle: String { loc("onboarding.style.subtitle") }

    static var onboardingShopTitle: String { loc("onboarding.shop.title") }
    static var onboardingShopSubtitle: String { loc("onboarding.shop.subtitle") }

    static var onboardingSocialTitle: String { loc("onboarding.social.title") }

    static var onboardingDemoTitle: String { loc("onboarding.demo.title") }
    static var onboardingDemoSubtitle: String { loc("onboarding.demo.subtitle") }
    static var onboardingDemoSelectTop: String { loc("onboarding.demo.selectTop") }
    static var onboardingDemoSelectBottom: String { loc("onboarding.demo.selectBottom") }
    static var onboardingDemoTryIt: String { loc("onboarding.demo.tryIt") }
    static var onboardingDemoResultTitle: String { loc("onboarding.demo.resultTitle") }
    static var onboardingDemoResultSubtitle: String { loc("onboarding.demo.resultSubtitle") }
    static var onboardingDemoCreateYours: String { loc("onboarding.demo.createYours") }

    static var onboardingPaywallTitle: String { loc("onboarding.paywall.title") }
    static var onboardingPaywallSubtitle: String { loc("onboarding.paywall.subtitle") }
    static var onboardingPaywallFeature1: String { loc("onboarding.paywall.feature1") }
    static var onboardingPaywallFeature2: String { loc("onboarding.paywall.feature2") }
    static var onboardingPaywallFeature3: String { loc("onboarding.paywall.feature3") }
    static var onboardingPaywallFeature4: String { loc("onboarding.paywall.feature4") }
    static var onboardingPaywallWeekly: String { loc("onboarding.paywall.weekly") }
    static var onboardingPaywallMonthly: String { loc("onboarding.paywall.monthly") }
    static var onboardingPaywallPerWeek: String { loc("onboarding.paywall.perWeek") }
    static var onboardingPaywallPerMonth: String { loc("onboarding.paywall.perMonth") }
    static var onboardingPaywallSave: String { loc("onboarding.paywall.save") }
    static var onboardingPaywallSubscribe: String { loc("onboarding.paywall.subscribe") }
    static var onboardingPaywallRestore: String { loc("onboarding.paywall.restore") }
    static var onboardingPaywallTerms: String { loc("onboarding.paywall.terms") }

    // MARK: - Closet
    static var closetTitle: String { loc("closet.title") }
    static var closetEmptyState: String { loc("closet.emptyState") }
    static var closetShelfTopsJackets: String { loc("closet.shelfTopsJackets") }
    static var closetShelfBottoms: String { loc("closet.shelfBottoms") }
    static var closetShelfDresses: String { loc("closet.shelfDresses") }
    static var closetShelfShoes: String { loc("closet.shelfShoes") }
    static var closetDressMe: String { loc("closet.dressMe") }
    static var closetAddProduct: String { loc("closet.addProduct") }
    static var closetSelectGarmentType: String { loc("closet.selectGarmentType") }
    static var closetShelfEmpty: String { loc("closet.shelfEmpty") }
    static var closetAddedToCloset: String { loc("closet.addedToCloset") }
    static var closetNoModelPhoto: String { loc("closet.noModelPhoto") }
    static func closetAddGarmentTitle(_ type: String) -> String { loc("closet.addGarmentTitle", type) }
    static var closetTipFlatSurface: String { loc("closet.tipFlatSurface") }
    static var closetTipGoodLighting: String { loc("closet.tipGoodLighting") }
    static var closetTipOnlyGarment: String { loc("closet.tipOnlyGarment") }
    static var closetAddToCloset: String { loc("closet.addToCloset") }
    static var closetTakePhoto: String { loc("closet.takePhoto") }
    static var closetSelectFromGallery: String { loc("closet.selectFromGallery") }
    static var closetChangePhoto: String { loc("closet.changePhoto") }
    static var closetAddPhotoPrompt: String { loc("closet.addPhotoPrompt") }
    static var closetSwipeHintLeft: String { loc("closet.swipeHintLeft") }
    static var closetSwipeHintRight: String { loc("closet.swipeHintRight") }
    static var closetDoneSelection: String { loc("closet.doneSelection") }
    static var closetAddFailed: String { loc("closet.addFailed") }
    static var closetSelectToDelete: String { loc("closet.selectToDelete") }
    static func closetDeleteSelected(_ count: Int) -> String { loc("closet.deleteSelected", count) }

    // MARK: - DressUp (Unified TryOn + Combo)
    static var dressUpTitle: String { loc("dressUp.title") }
    static func dressUpTryButton(_ credits: Int) -> String {
        credits == 1 ? loc("dressUp.tryButton", credits) : loc("dressUp.tryButtonPlural", credits)
    }

    // MARK: - Account Linking
    static var accountLinkingTitle: String { loc("accountLinking.title") }
    static var accountLinkingDataPreserved: String { loc("accountLinking.dataPreserved") }
    static var accountLinkingSubtitleSaveLook: String { loc("accountLinking.subtitle.saveLook") }
    static var accountLinkingSubtitleAddToCart: String { loc("accountLinking.subtitle.addToCart") }
    static var accountLinkingSubtitleAddToCloset: String { loc("accountLinking.subtitle.addToCloset") }
    static var accountLinkingSubtitleBuyPro: String { loc("accountLinking.subtitle.buyPro") }
    static var accountLinkingSubtitleGeneric: String { loc("accountLinking.subtitle.generic") }
    static var accountLinkingCredentialInUse: String { loc("accountLinking.credentialInUse") }
    static var accountLinkingEmailOption: String { loc("accountLinking.emailOption") }
    static var accountLinkingEmailContinue: String { loc("accountLinking.emailContinue") }
    static var profileAnonymousTitle: String { loc("profile.anonymous.title") }
    static var profileAnonymousSubtitle: String { loc("profile.anonymous.subtitle") }
    static var profileLinkAccount: String { loc("profile.linkAccount") }

    // MARK: - Share
    static var shareTryOnResult: String { loc("share.tryOnResult") }
    static var shareAppLink: String { loc("share.appLink") }
    static func shareReferralCode(_ code: String) -> String { loc("share.referralCode", code) }
    static var shareLookResult: String { loc("share.lookResult") }

    // MARK: - Debug
    static var debugClose: String { loc("debug.close") }
    static var debugCopy: String { loc("debug.copy") }
    static var debugClear: String { loc("debug.clear") }
    static var debugNoLogs: String { loc("debug.noLogs") }
    static var debugCopied: String { loc("debug.copied") }

    // MARK: - Common (extra)
    static var commonProfileSaveFailed: String { loc("common.profileSaveFailed") }
    static var commonUserNotFound: String { loc("common.userNotFound") }
    static var commonPhotoUploadError: String { loc("common.photoUploadError") }
    static var commonGenerationLimitReached: String { loc("common.generationLimitReached") }

    // MARK: - Preview strings
    static var previewSaveToGallery: String { loc("preview.saveToGallery") }
    static var previewDisabled: String { loc("preview.disabled") }
    static var previewLookSaved: String { loc("preview.lookSaved") }
    static var previewNetworkError: String { loc("preview.networkError") }
    static var previewTriesUsed: String { loc("preview.triesUsed") }
    static var previewDailyLimitReached: String { loc("preview.dailyLimitReached") }
    static var previewProcessingPhoto: String { loc("preview.processingPhoto") }
    static var previewThatsIt: String { loc("preview.thatsIt") }
    static var previewSuccess: String { loc("preview.success") }
    static var previewSingleTryOn: String { loc("preview.singleTryOn") }
    static var previewSingleTryOnDesc: String { loc("preview.singleTryOnDesc") }
    static var previewCreateCombo: String { loc("preview.createCombo") }
    static var previewCreateComboDesc: String { loc("preview.createComboDesc") }
    static var previewPassword: String { loc("preview.password") }
}
