import Foundation

// MARK: - UnPack Merkezi Bildirim (Notification) Tanımları

extension Notification.Name {
    public static let unpackNewArchive = Notification.Name("unpackNewArchive")
    public static let unpackOpenArchive = Notification.Name("unpackOpenArchive")
    public static let unpackExtract = Notification.Name("unpackExtract")
    public static let unpackExtractHere = Notification.Name("unpackExtractHere")
    public static let unpackExtractToFolder = Notification.Name("unpackExtractToFolder")
    public static let unpackExtractToChosen = Notification.Name("unpackExtractToChosen")
    public static let unpackExtractSelected = Notification.Name("unpackExtractSelected")
    public static let unpackAddFiles = Notification.Name("unpackAddFiles")
    public static let unpackDeleteSelected = Notification.Name("unpackDeleteSelected")
    public static let unpackRefresh = Notification.Name("unpackRefresh")
    public static let unpackShowInFinder = Notification.Name("unpackShowInFinder")
    public static let unpackExpandAll = Notification.Name("unpackExpandAll")
    public static let unpackCollapseAll = Notification.Name("unpackCollapseAll")
    public static let unpackTest = Notification.Name("unpackTest")
    public static let unpackInfo = Notification.Name("unpackInfo")
    public static let unpackFileDropped = Notification.Name("unpackFileDropped")
    public static let unpackCompressFilesWithDialog = Notification.Name("unpackCompressFilesWithDialog")
    public static let unpackShowOnboarding = Notification.Name("unpackShowOnboarding")
    public static let unpackRepair = Notification.Name("unpackRepair")
    public static let unpackSecurity = Notification.Name("unpackSecurity")

    // Coffer Uyumluluğu
    public static let cofferNewArchive = unpackNewArchive
    public static let cofferOpenArchive = unpackOpenArchive
    public static let cofferExtract = unpackExtract
    public static let cofferExtractHere = unpackExtractHere
    public static let cofferExtractToFolder = unpackExtractToFolder
    public static let cofferExtractToChosen = unpackExtractToChosen
    public static let cofferExtractSelected = unpackExtractSelected
    public static let cofferAddFiles = unpackAddFiles
    public static let cofferDeleteSelected = unpackDeleteSelected
    public static let cofferRefresh = unpackRefresh
    public static let cofferShowInFinder = unpackShowInFinder
    public static let cofferExpandAll = unpackExpandAll
    public static let cofferCollapseAll = unpackCollapseAll
    public static let cofferTest = unpackTest
    public static let cofferInfo = unpackInfo
    public static let cofferFileDropped = unpackFileDropped
    public static let cofferCompressFilesWithDialog = unpackCompressFilesWithDialog
    public static let cofferShowOnboarding = unpackShowOnboarding
    public static let cofferRepair = unpackRepair
    public static let cofferSecurity = unpackSecurity

    // Geriye Dönük Uyumluluk (MacRAR)
    public static let macRARNewArchive = unpackNewArchive
    public static let macRAROpenArchive = unpackOpenArchive
    public static let macRARExtract = unpackExtract
    public static let macRARExtractHere = unpackExtractHere
    public static let macRARExtractToFolder = unpackExtractToFolder
    public static let macRARExtractToChosen = unpackExtractToChosen
    public static let macRARExtractSelected = unpackExtractSelected
    public static let macRARAddFiles = unpackAddFiles
    public static let macRARDeleteSelected = unpackDeleteSelected
    public static let macRARRefresh = unpackRefresh
    public static let macRARShowInFinder = unpackShowInFinder
    public static let macRARExpandAll = unpackExpandAll
    public static let macRARCollapseAll = unpackCollapseAll
    public static let macRARTest = unpackTest
    public static let macRARInfo = unpackInfo
    public static let macRARFileDropped = unpackFileDropped
    public static let macRARCompressFilesWithDialog = unpackCompressFilesWithDialog
    public static let macRARShowOnboarding = unpackShowOnboarding
    public static let macRARRepair = unpackRepair
    public static let macRARSecurity = unpackSecurity
}
