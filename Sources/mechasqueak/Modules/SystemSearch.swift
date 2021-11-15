/*
 Copyright 2021 The Fuel Rats Mischief

 Redistribution and use in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice,
 this list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following
 disclaimer in the documentation and/or other materials provided with the distribution.

 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote
 products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
 INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation
import IRCKit
import NIO

class SystemSearch: IRCBotModule {
    var name: String = "SystemSearch"

    required init(_ moduleManager: IRCBotModuleManager) {
        moduleManager.register(module: self)
    }

    @AsyncBotCommand(
        ["search"],
        [.param("system name", "NLTT 48288", .continuous)],
        category: .utility,
        description: "Search for a system in the galaxy database.",
        cooldown: .seconds(30)
    )
    var didReceiveSystemSearchCommand = { command in
        let system = command.parameters.joined(separator: " ")
        
        do {
            let searchResults = try await SystemsAPI.performSearch(forSystem: system)
            
            guard var results = searchResults.data else {
                command.message.error(key: "systemsearch.error", fromCommand: command)
                return
            }

            guard results.count > 0 else {
                command.message.reply(key: "systemsearch.noresults", fromCommand: command)
                return
            }

            let resultString = results.map({
                $0.textRepresentation
            }).joined(separator: ", ")

            command.message.reply(key: "systemsearch.nearestmatches", fromCommand: command, map: [
                "system": system,
                "results": resultString
            ])

        } catch {
            command.message.error(key: "systemsearch.error", fromCommand: command)
        }
    }

    @AsyncBotCommand(
        ["landmark"],
        [.param("system name", "NLTT 48288", .continuous)],
        category: .utility,
        description: "Search for a star system's proximity to known landmarks such as Sol, Sagittarius A* or Colonia.",
        cooldown: .seconds(30)
    )
    var didReceiveLandmarkCommand = { command in
        var system = command.parameters.joined(separator: " ")
        if system.lowercased().starts(with: "near ") {
            system.removeFirst(5)
        }
        
        var starSystem = StarSystem(name: system)
        starSystem = autocorrect(system: starSystem)
        
        do {
            let result = try await SystemsAPI.performSystemCheck(forSystem: starSystem.name)
            
            guard let landmarkDescription = result.landmarkDescription else {
                command.message.reply(key: "landmark.noresults", fromCommand: command, map: [
                    "system": system
                ])
                return
            }
            command.message.reply(message: await result.info)
        } catch {
            command.message.reply(key: "landmark.noresults", fromCommand: command, map: [
                "system": system
            ])
        }
    }
    
    @AsyncBotCommand(
        ["distance", "plot", "distanceto"],
        [.param("departure system", "NLTT 48288"), .param("arrival system", "Sagittarius A*")],
        category: .utility,
        description: "Calculate the distance between two star systems",
        cooldown: .seconds(30)
    )
    var didReceiveDistanceCommand = { command in
        let (depSystem, arrSystem) = command.param2 as! (String, String)
        
        do {
            let (departure, arrival) = try await (SystemsAPI.performSystemCheck(forSystem: depSystem), SystemsAPI.performSystemCheck(forSystem: arrSystem))
            
            guard let depCoords = departure.coordinates, let arrCoords = arrival.coordinates else {
                command.message.error(key: "distance.notfound", fromCommand: command)
                return
            }
            
            let distance = arrCoords.distance(from: depCoords)
            let formatter = NumberFormatter.englishFormatter()
            
            let positionsAreApproximated = departure.landmark == nil || arrival.landmark == nil
            var plotDepName = departure.name
            var plotArrName = arrival.name
            if let proceduralCheck = departure.proceduralCheck {
                if let nearestKnown = try? await SystemsAPI.getNearestSystem(forCoordinates: proceduralCheck.sectordata.coords)?.data {
                    plotDepName = nearestKnown.name
                }
            }
            
            if let proceduralCheck = arrival.proceduralCheck {
                if let nearestKnown = try? await SystemsAPI.getNearestSystem(forCoordinates: proceduralCheck.sectordata.coords)?.data {
                    plotArrName = nearestKnown.name
                }
            }
            
            var spanshUrl: URL? = nil
            if distance > 1000 {
                spanshUrl = try? await generateSpanshRoute(from: plotDepName, to: plotArrName)
            }
            
            var key = positionsAreApproximated ? "distance.resultapprox" : "distance.result"
            if spanshUrl != nil {
                key += ".plotter"
            }
            
            command.message.reply(key: key, fromCommand: command, map: [
                "departure": departure.name,
                "arrival": arrival.name,
                "distance": formatter.string(from: distance)!,
                "plotterUrl": spanshUrl?.absoluteString ?? ""
            ])
        } catch {
            print(error)
            command.message.error(key: "distance.error", fromCommand: command)
        }
    }
    
    @AsyncBotCommand(
        ["station", "stations"],
        [.param("reference system / case id / client name", "Sagittarius A*", .continuous), .argument("planet"), .options(["p", "l"])],
        category: .utility,
        description: "Get the nearest station to a system, use a system name, case ID, or client name",
        cooldown: .seconds(30)
    )
    var didReceiveStationCommand = { command in
        var systemName = command.param1!
        let requireLargePad = command.options.contains("l")
        let requireSpace = !(command.options.contains("p"))
        
        if let (_, rescue) = await board.findRescue(withCaseIdentifier: systemName) {
            systemName = rescue.system?.name ?? ""
        }
        
        var proceduralCheck: SystemsAPI.ProceduralCheckDocument? = nil
        var nearestSystem: SystemsAPI.NearestSystemDocument.NearestSystem? = nil
        let systemCheck = try? await SystemsAPI.performSystemCheck(forSystem: systemName)
        if systemCheck?.landmark == nil, let cords = systemCheck?.proceduralCheck?.sectordata.coords {
            if let nearestSystemSearch = try? await SystemsAPI.getNearestSystem(forCoordinates: cords)?.data {
                systemName = nearestSystemSearch.name
                proceduralCheck = systemCheck?.proceduralCheck
                nearestSystem = nearestSystemSearch
            }
        }
        
        do {
            var stationResult = try await SystemsAPI.getNearestPreferableStation(
                forSystem: systemName,
                limit: 10,
                largePad: requireLargePad,
                requireSpace: requireSpace
            )
            
            if stationResult == nil {
                stationResult = try await SystemsAPI.getNearestPreferableStation(
                    forSystem: systemName,
                    limit: 30,
                    largePad: requireLargePad,
                    requireSpace: requireSpace
                )
            }
            
            if stationResult == nil {
                stationResult = try await SystemsAPI.getNearestPreferableStation(
                    forSystem: systemName,
                    limit: 100,
                    largePad: requireLargePad,
                    requireSpace: requireSpace
                )
            }
            
            guard let (system, station) = stationResult else {
                command.message.error(key: "station.notfound", fromCommand: command)
                return
            }
            
            var approximatedDistance: String? = nil
            if let proc = proceduralCheck, let nearest = nearestSystem {
                let formatter = NumberFormatter.englishFormatter()
                formatter.usesSignificantDigits = true
                // Round of output distance based on uncertainty provided by SystemsAPI
                formatter.maximumSignificantDigits = proc.sectordata.uncertainty.significandWidth
                // Pythagoras strikes again, he won't ever leave me alone
                let calculatedDistance = (pow(nearest.distance, 2) + pow(system.distance, 2)).squareRoot()
                approximatedDistance = formatter.string(from: calculatedDistance)
            }
            
            command.message.reply(message: try! stencil.renderLine(name: "station.stencil", context: [
                "system": system,
                "approximatedDistance": approximatedDistance as Any,
                "station": station,
                "travelTime": station.distance.distanceToSeconds(destinationGravity: true).timeSpan,
                "services": station.allServices,
                "notableServices": station.notableServices,
                "stationType": station.type.rawValue,
                "showAllServices": command.options.contains("s"),
                "additionalServices": station.services.count - station.notableServices.count
            ]))
        } catch {
            print(String(describing: error))
            command.error(error)
        }
    }
}
