import Foundation

// MARK: - Coffer Merkezi Bildirim (Notification) Tanımları

extension Notification.Name {
    public static let cofferNewArchive = Notification.Name("cofferNewArchive")
    public static let cofferOpenArchive = Notification.Name("cofferOpenArchive")
    public static let cofferExtract = Notification.Name("cofferExtract")
    public static let cofferExtractHere = Notification.Name("cofferExtractHere")
    public static let cofferExtractToFolder = Notification.Name("cofferExtractToFolder")
    public static let cofferExtractToChosen = Notification.Name("cofferExtractToChosen")
    public static let cofferExtractSelected = Notification.Name("cofferExtractSelected")
    public static let cofferAddFiles = Notification.Name("cofferAddFiles")
    public static let cofferDeleteSelected = Notification.Name("cofferDeleteSelected")
    public static let cofferRefresh = Notification.Name("cofferRefresh")
    public static let cofferShowInFinder = Notification.Name("cofferShowInFinder")
    public static let cofferExpandAll = Notification.Name("cofferExpandAll")
    public static let cofferCollapseAll = Notification.Name("cofferCollapseAll")
    public static let cofferTest = Notification.Name("cofferTest")
    public static let cofferInfo = Notification.Name("cofferInfo")
    public static let cofferFileDropped = Notification.Name("cofferFileDropped")
    public static let cofferCompressFilesWithDialog = Notification.Name("cofferCompressFilesWithDialog")
    public static let cofferShowOnboarding = Notification.Name("cofferShowOnboarding")
    public static let cofferRepair = Notification.Name("cofferRepair")
    public static let cofferSecurity = Notification.Name("cofferSecurity")

    // Geriye Dönük Uyumluluk (Backwards Compatibility)
    public static let macRARNewArchive = cofferNewArchive
    public static let macRAROpenArchive = cofferOpenArchive
    public static let macRARExtract = cofferExtract
    public static let macRARExtractHere = cofferExtractHere
    public static let macRARExtractToFolder = cofferExtractToFolder
    public static let macRARExtractToChosen = cofferExtractToChosen
    public static let macRARExtractSelected = cofferExtractSelected
    public static let macRARAddFiles = cofferAddFiles
    public static let macRARDeleteSelected = cofferDeleteSelected
    public static let macRARRefresh = cofferRefresh
    public static let macRARShowInFinder = cofferShowInFinder
    public static let macRARExpandAll = cofferExpandAll
    public static let macRARCollapseAll = cofferCollapseAll
    public static let macRARTest = cofferTest
    public static let macRARInfo = cofferInfo
    public static let macRARFileDropped = cofferFileDropped
    public static let macRARCompressFilesWithDialog = cofferCompressFilesWithDialog
    public static let macRARShowOnboarding = cofferShowOnboarding
    public static let macRARRepair = cofferRepair
    public static let macRARSecurity = cofferSecurity
}
