//
//  AppRouter.swift
//  AuraSpatial
//
//  Which tab is showing. Shared through the environment so one screen can
//  send the user to another - e.g. opening a Saved Layout jumps to the
//  Canvas so you immediately see (and hear) it.
//

import Foundation
import Observation

enum AppTab: Hashable {
    case canvas
    case community
    case saved
    case profile
}

@Observable
final class AppRouter {
    var selectedTab: AppTab = .canvas
}
