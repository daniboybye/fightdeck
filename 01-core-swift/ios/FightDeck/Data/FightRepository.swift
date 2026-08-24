//
// FightRepository.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightCore
import Foundation

protocol FightRepository: Sendable {
    func loadEvents() async throws(FightCoreError) -> [EventItem]
    func loadFighters() async throws(FightCoreError) -> [FighterItem]
}
