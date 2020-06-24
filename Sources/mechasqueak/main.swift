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
import Lingo
import IRCKit

let lingo = try! Lingo(rootPath: "\(FileManager.default.currentDirectoryPath)/localisation", defaultLocale: "en")

func loadConfiguration () -> MechaConfiguration {
    var configPath = URL(
        fileURLWithPath: FileManager.default.currentDirectoryPath
    ).appendingPathComponent("config.json")
    if CommandLine.arguments.count > 1 {
        configPath = URL(fileURLWithPath: CommandLine.arguments[1])
    }

    guard let configData = try? Data(contentsOf: configPath) else {
        fatalError("Could not locate configuration file in \(configPath.absoluteString)")
    }

    let configDecoder = JSONDecoder()
    return try! configDecoder.decode(MechaConfiguration.self, from: configData)
}

let configuration = loadConfiguration()

class MechaSqueak {
    static var commands: [IRCBotCommandDeclaration] = []
    let moduleManager: IRCBotModuleManager
    let accounts: NicknameLookupManager
    let commands: [IRCBotModule]
    let connections: [IRCClient]
    let rescueBoard: RescueBoard
    var rescueChannel: IRCChannel?
    let startupTime: Date
    let version = "3.0.0"
    private var accountChangeObserver: NotificationToken?
    private var userJoinObserver: NotificationToken?
    private var userQuitObserver: NotificationToken?
    private var userNickChangeObserver: NotificationToken?

    init () {
        self.startupTime = Date()
        self.accounts = NicknameLookupManager()
        self.rescueBoard = RescueBoard()

        self.connections = configuration.connections.map({
            return IRCClient(configuration: $0)
        })

        self.moduleManager = IRCBotModuleManager()
        self.commands = [
            GeneralCommands(moduleManager),
            SystemSearch(moduleManager),
            BoardCommands(moduleManager),
            RemoteRescueCommands(moduleManager),
            FactCommands(moduleManager),
            ShortenURLCommands(moduleManager),
            TweetCommands(moduleManager)
        ]

        self.accountChangeObserver = NotificationCenter.default.addObserver(
            descriptor: IRCUserAccountChangeNotification(),
            using: onAccountChange(accountChange:)
        )

        self.userJoinObserver = NotificationCenter.default.addObserver(
            descriptor: IRCUserJoinedChannelNotification(),
            using: onUserJoin(userJoin:)
        )
        self.userQuitObserver = NotificationCenter.default.addObserver(
            descriptor: IRCUserQuitNotification(),
            using: onUserQuit(userQuit:)
        )
        self.userNickChangeObserver = NotificationCenter.default.addObserver(
            descriptor: IRCUserChangedNickNotification(),
            using: onUserNickChange(nickChange:)
        )
    }

    func onAccountChange (accountChange: IRCUserAccountChangeNotification.Payload) {
        let user = accountChange.user

        guard user.account != nil else {
            accounts.mapping[user.nickname] = nil
            return
        }

        if accountChange.oldValue != user.account || accounts.mapping[user.nickname] == nil {
            accounts.lookupIfNotExists(user: user)
        }
    }

    func onUserJoin (userJoin: IRCUserJoinedChannelNotification.Payload) {
        let client = userJoin.raw.client
        if userJoin.raw.sender!.isCurrentUser(client: client)
            && userJoin.channel.name.lowercased() == configuration.general.reportingChannel.lowercased() {
            mecha.rescueChannel = userJoin.channel
            mecha.rescueBoard.syncBoard()
        } else {
            accounts.lookupIfNotExists(user: userJoin.user)
        }
    }

    func onUserQuit (userQuit: IRCUserQuitNotification.Payload) {
        accounts.mapping.removeValue(forKey: userQuit.sender!.nickname)
    }

    func onUserNickChange (nickChange: IRCUserChangedNickNotification.Payload) {
        let sender = nickChange.raw.sender!

        if let apiNickname = accounts.mapping[sender.nickname] {
            accounts.mapping.removeValue(forKey: sender.nickname)
            accounts.mapping[nickChange.newNick] = apiNickname
        }
    }
}

let mecha = MechaSqueak()

RunLoop.main.run()
