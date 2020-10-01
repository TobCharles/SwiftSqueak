/*
 Copyright 2020 The Fuel Rats Mischief

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

class GeneralCommands: IRCBotModule {
    var name: String = "GeneralCommands"

    required init(_ moduleManager: IRCBotModuleManager) {
        moduleManager.register(module: self)
    }

    @BotCommand(
        ["sysstats", "syscount", "systems"],
        parameters: 0...0,
        category: .utility,
        description: "See statistics about the systems API.",
        permission: nil
    )
    var didReceiveSystemStatisticsCommand = { command in
        SystemsAPI.performStatisticsQuery(onComplete: { results in
            let result = results.data[0]
            guard let date = try? Double(value: result.id) else {
                return
            }

            let numberFormatter = NumberFormatter.englishFormatter()

            command.message.reply(key: "sysstats.message", fromCommand: command, map: [
                "date": Date(timeIntervalSince1970: date).timeAgo,
                "systems": numberFormatter.string(from: result.attributes.syscount)!,
                "stars": numberFormatter.string(from: result.attributes.starcount)!,
                "bodies": numberFormatter.string(from: result.attributes.bodycount)!
            ])
        }, onError: { _ in
            command.message.error(key: "sysstats.error", fromCommand: command)
        })
    }

    @BotCommand(
        ["sctime", "sccalc", "traveltime"],
        parameters: 1...,
        category: .utility,
        description: "Calculate supercruise travel time",
        paramText: "<distance>",
        example: "2500ls",
        permission: nil
    )
    var didReceiveTravelTimeCommand = { command in
        var distanceString = command.parameters.joined(separator: " ").lowercased().trimmingCharacters(in: .whitespaces)
        let isYear = distanceString.hasSuffix("ly")
        var kiloPhrases = ["kls", "k ls", "k", "kly", "k ly"]
        let isKilo = kiloPhrases.contains(where: {
            distanceString.hasSuffix($0)
        })
        let nonNumberCharacters = CharacterSet.decimalDigits.union(CharacterSet(charactersIn: ".")).inverted

        distanceString = distanceString.components(separatedBy: nonNumberCharacters).joined()
        distanceString = distanceString.trimmingCharacters(in: nonNumberCharacters)
        guard var distance = Double(distanceString) else {
            command.message.replyPrivate(key: "sctime.error", fromCommand: command)
            return
        }

        if isYear {
            distance = distance * 365.28 * 24 * 60 * 60
        }

        if isKilo {
            distance = distance * 1000
        }

        let seconds = Int(65 + (1.8 * sqrt(Double(distance))))

        var time = ""
        if seconds > 3600 {
            let hours = Int(seconds / 3600)
            let minutes = Int((seconds % 3600) / 60)
            time = "\(hours) hours, and \(minutes) minutes"
        } else if seconds > 60 {
            let minutes = Int(seconds / 60)
            time = "\(minutes) minutes"
        } else {
            time = "\(seconds) seconds"
        }

        let formatter = NumberFormatter.englishFormatter()
        let formattedDistance = formatter.string(from: distance) ?? "\(distance)"
        command.message.reply(key: "sctime.response", fromCommand: command, map: [
            "distance": formattedDistance,
            "time": time
        ])
    }

    @BotCommand(
        ["version", "uptime"],
        parameters: 0...0,
        category: .utility,
        description: "See version information about the bot.",
        permission: nil
    )
    var didReceiveVersionCommand = { command in
        let replyKey = configuration.general.drillMode ? "version.drillmode" : "version.message"

        command.message.reply(key: replyKey, fromCommand: command, map: [
            "version": mecha.version,
            "uptime": mecha.startupTime.timeAgo,
            "startup": mecha.startupTime.description
        ])
    }

    @BotCommand(
        ["whoami"],
        parameters: 0...0,
        category: .utility,
        description: "Check the Fuel Rats account information the bot is currently associating with your nick"
    )
    var didReceiveWhoAmICommand = { command in
        let message = command.message
        let user = message.user
        guard let account = user.account else {
            command.message.reply(key: "whoami.notloggedin", fromCommand: command)
            return
        }

        guard let associatedNickname = user.associatedAPIData else {
            command.message.reply(key: "whoami.nodata", fromCommand: command, map: [
                "account": account
            ])
            return
        }

        guard let apiUser = associatedNickname.body.includes![User.self].first(where: {
            return $0.id.rawValue == associatedNickname.body.data?.primary.values[0].relationships.user?.id.rawValue
        }) else {
            command.message.reply(key: "whoami.noaccount", fromCommand: command, map: [
                "account": account
            ])
            return
        }

        let rats = associatedNickname.ratsBelongingTo(user: apiUser).map({
            "\($0.attributes.name.value) (\($0.attributes.platform.value.ircRepresentable))"
        }).joined(separator: ", ")

        let joinedDate = associatedNickname.ratsBelongingTo(user: apiUser).reduce(nil, { (acc: Date?, rat: Rat) -> Date? in
            if acc == nil || rat.attributes.createdAt.value < acc! {
                return rat.attributes.createdAt.value
            }
            return acc
        })

        let verifiedStatus = associatedNickname.permissions.contains(.UserVerified) ?
            IRCFormat.color(.LightGreen, "Verified") :
            IRCFormat.color(.LightGreen, "Unverified")

        command.message.reply(key: "whoami.response", fromCommand: command, map: [
            "account": account,
            "userId": apiUser.id.rawValue.ircRepresentation,
            "rats": rats,
            "joined": joinedDate?.eliteFormattedString ?? "unknown",
            "verified": verifiedStatus
        ])
    }

    @BotCommand(
        ["whois", "ratid", "who", "id"],
        parameters: 1...1,
        category: .utility,
        description: "Check the Fuel Rats account information the bot is associating with someone's nick.",
        paramText: "<nickname>",
        example: "SpaceDawg",
        permission: .RatReadOwn
    )
    var didReceiveWhoIsCommand = { command in
        let message = command.message
        let nick = command.parameters[0]

        guard let user = message.destination.member(named: nick) else {
            command.message.error(key: "whois.notfound", fromCommand: command, map: [
                "nick": nick
            ])
            return
        }

        guard let account = user.account else {
            command.message.reply(key: "whois.notloggedin", fromCommand: command, map: [
                "nick": nick
            ])
            return
        }

        guard let associatedNickname = user.associatedAPIData else {
            command.message.reply(key: "whois.nodata", fromCommand: command, map: [
                "nick": nick,
                "account": account
            ])
            return
        }

        guard let apiUser = associatedNickname.body.includes![User.self].first(where: {
            return $0.id.rawValue == associatedNickname.body.data?.primary.values[0].relationships.user?.id.rawValue
        }) else {
            command.message.reply(key: "whois.noaccount", fromCommand: command, map: [
                "nick": nick,
                "account": account
            ])
            return
        }

        let rats = associatedNickname.ratsBelongingTo(user: apiUser).map({
            "\($0.attributes.name.value) (\($0.attributes.platform.value.ircRepresentable))"
        }).joined(separator: ", ")

        let joinedDate = associatedNickname.ratsBelongingTo(user: apiUser).reduce(nil, { (acc: Date?, rat: Rat) -> Date? in
            if acc == nil || rat.attributes.createdAt.value < acc! {
                return rat.attributes.createdAt.value
            }
            return acc
        })

        let verifiedStatus = associatedNickname.permissions.contains(.UserVerified) ?
            IRCFormat.color(.LightGreen, "Verified") :
            IRCFormat.color(.LightGreen, "Unverified")

        command.message.reply(key: "whois.response", fromCommand: command, map: [
            "nick": nick,
            "account": account,
            "userId": apiUser.id.rawValue.ircRepresentation,
            "rats": rats,
            "joined": joinedDate?.eliteFormattedString ?? "unknown",
            "verified": verifiedStatus
        ])
    }

    @BotCommand(
        ["msg", "say"],
        parameters: 2...2,
        lastParameterIsContinous: true,
        category: .utility,
        description: "Make the bot send an IRC message somewhere.",
        paramText: "<destination> <message>",
        example: "#ratchat Squeak!",
        permission: .UserWrite
    )
    var didReceiveSayCommand = { command in
        command.message.reply(key: "say.sending", fromCommand: command, map: [
            "target": command.parameters[0],
            "contents": command.parameters[1]
        ])
        command.message.client.sendMessage(toChannelName: command.parameters[0], contents: command.parameters[1])
    }

    @BotCommand(
        ["me", "action", "emote"],
        parameters: 2...2,
        lastParameterIsContinous: true,
        category: .utility,
        description: "Make the bot send an IRC action (/me) somewhere.",
        paramText: "<destination> <action message>",
        example: "#ratchat noms popcorn.",
        permission: .UserWrite
    )
    var didReceiveMeCommand = { command in
        command.message.reply(key: "me.sending", fromCommand: command, map: [
            "target": command.parameters[0],
            "contents": command.parameters[1]
        ])
        command.message.client.sendActionMessage(toChannelName: command.parameters[0], contents: command.parameters[1])
    }
}
