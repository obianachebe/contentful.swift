//
//  SyncSpace.swift
//  Contentful
//
//  Created by Boris Bügling on 20/01/16.
//  Copyright © 2016 Contentful GmbH. All rights reserved.
//

import Foundation
import Interstellar
import ObjectMapper

/// A container for the synchronized state of a Space
public final class SyncSpace: ImmutableMappable {
    internal var assetsMap = [String: Asset]()
    internal var entriesMap = [String: Entry]()

    var deletedAssets = [String]()
    var deletedEntries = [String]()

    var hasMorePages: Bool

    /// A token which needs to be present to perform a subsequent synchronization operation
    internal(set) public var syncToken = ""

    /// List of Assets currently published on the Space being synchronized
    public var assets: [Asset] {
        return Swift.Array(assetsMap.values)
    }

    /// List of Entries currently published on the Space being synchronized
    public var entries: [Entry] {
        return Swift.Array(entriesMap.values)
    }

    /**
     Continue a synchronization with previous data.

     - parameter syncToken: The sync token from a previous synchronization

     - returns: An initialized synchronized space instance
     **/
    public init(syncToken: String) {
        self.hasMorePages = false
        self.syncToken = syncToken
    }

    func syncToken(from urlString: String) -> String {
        guard let components = URLComponents(string: urlString)?.queryItems else { return "" }
        for component in components {
            if let value = component.value, component.name == "sync_token" {
                return value
            }
        }
        return ""
    }

    // MARK: <ImmutableMappable>

    public required init(map: Map) throws {
        var hasMorePages = true
        var syncUrl: String?
        syncUrl <- map["nextPageUrl"]

        if syncUrl == nil {
            hasMorePages = false
            syncUrl <- map["nextSyncUrl"]
        }

        self.hasMorePages = hasMorePages
        self.syncToken = self.syncToken(from: syncUrl!)

        var items: [[String: Any]]!
        items <- map["items"]

        let resources: [Resource] = try items.flatMap { itemJSON in
            let map = Map(mappingType: .fromJSON, JSON: itemJSON, context: map.context)

            let type: String = try map.value("sys.type")

            switch type {
            case "Asset":           return try? Asset(map: map)
            case "Entry":           return try? Entry(map: map)
            case "ContentType":     return try? ContentType(map: map)
            case "DeletedAsset":    return try? DeletedResource(map: map)
            case "DeletedEntry":    return try? DeletedResource(map: map)
            default: fatalError("Unsupported resource type '\(type)'")
            }

            return nil
        }

        cache(resources: resources)

        // If it's a one page sync, resolve links.
        // Otherwise, we will wait until all pages have come in to resolve them.
        if hasMorePages == false {
            for entry in entries {
                entry.resolveLinks(against: entries, and: assets)
            }
        }
    }

    internal func cache(resources: [Resource]) {
        for resource in resources {
            switch resource {
            case let asset as Asset:
                self.assetsMap[asset.sys.id] = asset

            case let entry as Entry:
                self.entriesMap[entry.sys.id] = entry

            case let deletedResource as DeletedResource:
                switch deletedResource.sys.type {
                case "DeletedAsset": self.deletedAssets.append(deletedResource.sys.id)
                case "DeletedEntry": self.deletedEntries.append(deletedResource.sys.id)
                default: break
                }
            default: break
            }
        }
    }
}
