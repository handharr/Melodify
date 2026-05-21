protocol DeepLinkHandler: AnyObject {
    @MainActor func handle(_ link: DeepLink)
}
