//
//  AppVersion.swift
//  CynthCalMac
//
//  Created by cyan on 12/25/23.
//

import Foundation

/**
 [GitHub Releases API](https://api.github.com/repos/yuxuangezhu/CynthCal/releases/latest)
 */
struct AppVersion: Decodable {
  let name: String
  let body: String
  let htmlUrl: String
}
