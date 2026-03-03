//
//  API.swift
//  appdb
//
//  Created by ned on 15/10/2016.
//  Copyright © 2016 ned. All rights reserved.
//

import Alamofire
import SwiftyJSON
import Localize_Swift

enum API {
    static let endpoint = "https://api.dbservices.to/v1.7/"
    static let statusEndpoint = "https://status.dbservices.to/API/v1.0/"
    static let itmsHelperEndpoint = "https://dbservices.to/manifest.php"

    static var languageCode: String {
        Localize.currentLanguage()
    }

    static let headers: HTTPHeaders = ["User-Agent": "appdb iOS Client v\(Global.appVersion)"]

    static var headersWithCookie: HTTPHeaders {
        guard Preferences.deviceIsLinked else { return headers }
        return [
            "User-Agent": "appdb iOS Client v\(Global.appVersion)",
            "Cookie": "lt=\(Preferences.linkToken)"
        ]
    }
}

enum DeviceType: String {
    case iphone
    case ipad
}

enum ItemType: String, Codable {
    case ios = "ios"
    case books = "books"
    case cydia = "cydia"
    case myAppstore = "MyAppStore"
    case altstore = "altstore"

    /// Maps legacy ItemType to the v1.7 newContentType used by search_index
    var newContentType: NewContentType? {
        switch self {
        case .ios: return .officialApp
        case .cydia: return .repoApp
        case .books: return nil // books no longer searchable as a separate type
        case .myAppstore: return .userApp
        case .altstore: return .repoApp
        }
    }
}

/// v1.7 content types used by search_index and universal_gateway
enum NewContentType: String, Codable {
    case repoApp = "repo_app"
    case officialApp = "official_app"
    case userApp = "user_app"
    case enhancement = "enhancement"
}

enum Order: String, CaseIterable {
    case added = "added"
    case day = "clicks_day"
    case week = "clicks_week"
    case month = "clicks_month"
    case year = "clicks_year"
    case all = "clicks_all"

    var pretty: String {
        switch self {
        case .added: return "Recently Uploaded".localized()
        case .day: return "Popular Today".localized()
        case .week: return "Popular This Week".localized()
        case .month: return "Popular This Month".localized()
        case .year: return "Popular This Year".localized()
        case .all: return "Popular All Time".localized()
        }
    }

    var associatedImage: String {
        switch self {
        case .added: return "clock"
        case .day: return "calendar"
        case .week: return "calendar"
        case .month: return "calendar"
        case .year: return "calendar"
        case .all: return "flame"
        }
    }
}

enum Price: String, CaseIterable {
    case all = "0"
    case paid = "1"
    case free = "2"

    var pretty: String {
        switch self {
        case .all: return "Any Price".localized()
        case .paid: return "Paid".localized()
        case .free: return "Free".localized()
        }
    }

    var associatedImage: String {
        switch self {
        case .all: return "cart"
        case .paid: return "dollarsign.circle"
        case .free: return "giftcard"
        }
    }
}

enum Actions: String {
    // Search & content discovery
    case searchIndex = "search_index"
    case universalGateway = "universal_gateway"
    case listGenres = "list_genres"
    case listArtists = "list_artists"
    case getPromotions = "get_promotions"
    case getPages = "get_pages"

    // Device linking & auth
    case link = "link"
    case getLinkCode = "get_link_code"
    case getLinkSession = "get_link_session"
    case getTvLinkCode = "get_tv_link_code"
    case getActionTicket = "get_action_ticket"
    case notifyProfileRemoval = "notify_profile_removal"
    case unlink = "unlink"

    // Device configuration
    case getConfiguration = "get_configuration"
    case configure = "configure"
    case getAllDevices = "get_all_devices"
    case changeEmail = "change_email"

    // Device commands & status
    case getStatus = "get_status"
    case clear = "clear"
    case retryCommand = "retry_command"
    case cancelCommand = "cancel_command"
    case forceAppManagement = "force_app_management"
    case setAppsRemoved = "set_apps_removed"

    // Installation
    case install = "install"
    case getFeatures = "get_features"
    case getSideloadingOptions = "get_sideloading_options"
    case getActiveApps = "get_active_apps"

    // Updates
    case getUpdatesTicket = "get_update_ticket"
    case getUpdates = "get_updates"

    // Personal library (IPAs)
    case getIpas = "get_ipas"
    case deleteIpa = "delete_ipa"
    case addIpa = "add_ipa"
    case getIpaAnalyzeJobs = "get_ipa_analyze_jobs"
    case deleteIpaAnalyzeJob = "delete_ipa_analyze_job"
    case importToLibrary = "import_to_library"

    // Enhancements (formerly dylibs)
    case getEnhancements = "get_enhancements"
    case addEnhancement = "add_enhancement"
    case deleteEnhancement = "delete_enhancement"
    case getEnhancementAnalyzeJobs = "get_enhancement_analyze_jobs"
    case deleteEnhancementAnalyzeJob = "delete_enhancement_analyze_job"

    // Installation history (replaces IPA cache)
    case getInstallationHistory = "get_installation_history"

    // Repos (formerly AltStore repos)
    case getRepos = "get_repos"
    case editRepo = "edit_repo"
    case deleteRepo = "delete_repo"

    // Publishing
    case createPublishRequest = "create_publish_request"
    case getPublishRequests = "get_publish_requests"

    // Purchases & subscriptions
    case getSubscriptions = "get_subscriptions"
    case getTransactions = "get_transactions"

    // Redirect processing
    case processRedirect = "process_redirect"

    // Enterprise certs & developer accounts
    case getEnterpriseCerts = "get_enterprise_certs"
    case getDevCredentialsProviders = "get_dev_credentials_providers"
    case editPlusDevAccount = "edit_plus_dev_account"
    case deletePlusDevAccount = "delete_plus_dev_account"
    case archiveRevokedPlusDevAccount = "archive_revoked_plus_dev_account"
    case getPlusDevAccountArchive = "get_plus_dev_account_archive"

    // Bundle IDs
    case getAppdbAppsBundleIdsTicket = "get_appdb_apps_bundle_ids_ticket"
    case getAppdbAppsBundleIds = "get_appdb_apps_bundle_ids"

    // Support
    case getSupportTickets = "get_support_tickets"
    case createSupportTicket = "create_support_ticket"
    case closeSupportTicket = "close_support_ticket"

    // Stats
    case getStats = "get_stats"

    // Customer profile
    case getCustomerProfile = "get_customer_profile"
    case editCustomerProfile = "edit_customer_profile"
}

enum ConfigurationParameters: String {
    case ignoreCompatibility = "params[ignore_compatibility]"
    case askForOptions = "params[ask_for_installation_options]"
    case clearDevEntity = "params[clear_developer_entity]"
    case signingIdentityType = "params[signing_identity_type]"
    case enterpriseCertId = "params[enterprise_cert_id]"
    case optedOutFromEmails = "params[is_opted_out_from_emails]"
    case useRevokedCerts = "params[use_revoked_certs]"
}

// Installation features are now dynamic — identifiers come from /get_features/ endpoint.
// Use enable_features[$identifier] as parameter keys when calling /install/.
// This enum provides the parameter key prefix for convenience.
enum InstallationFeatureParameter {
    static func key(for identifier: String) -> String {
        "enable_features[\(identifier)]"
    }
}
