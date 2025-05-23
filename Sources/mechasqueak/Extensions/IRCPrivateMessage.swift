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

extension IRCPrivateMessage {
    func reply(key: String, fromCommand command: IRCBotCommand, map: [String: Any]? = [:]) {
        self.reply(message: lingo.localize(key, locale: command.locale.short, interpolations: map))
    }

    func error(key: String, fromCommand command: IRCBotCommand, map: [String: Any]? = [:]) {
        let msg = lingo.localize(key, locale: command.locale.short, interpolations: map)
        self.reply(
            message: "\(command.message.user.nickname): \(msg)"
        )
    }

    func replyPrivate(message: String) {
        if self.destination.isPrivateMessage
            || (configuration.general.drillMode == true
                && configuration.general.drillChannels.contains(self.destination.name.lowercased())) {
            self.reply(message: message)
            return
        }
        var tags: [String: String?] = [:]
        if let msgid = self.raw.messageTags["msgid"] {
            tags["+draft/reply"] = msgid
        }
        if self.destination.isPrivateMessage == false {
            tags["+draft/channel-context"] = self.destination.name
        }
        self.client.send("CNOTICE", parameters: [
            self.user.nickname,
            self.destination.name,
            message
        ], tags: tags)
    }

    func replyPrivate(key: String, fromCommand command: IRCBotCommand, map: [String: Any]? = [:]) {
        let message = lingo.localize(key, locale: command.locale.short, interpolations: map)
        self.replyPrivate(message: message)
    }

    public func reply(list: [String], separator: String, heading: String = "") {
        let messages = list.ircList(separator: separator, heading: heading)

        for message in messages {
            self.reply(message: message)
        }
    }

    public func replyPrivate(list: [String], separator: String, heading: String = "") {
        let messages = list.ircList(separator: separator, heading: heading)

        for message in messages {
            self.replyPrivate(message: message)
        }
    }

    func retaliate() {
        let phrase = retaliationPhrases[Int.random(in: 0..<retaliationPhrases.count)]
        self.client.sendActionMessage(
            toChannel: self.destination,
            contents: String(format: phrase, arguments: [self.user.nickname]))
    }
}

private let retaliationPhrases = [
    "yeets %@ out of the airlock",
    "revokes %@'s snickers rations for 1 month",
    "launches a tactical nuclear strike in %@'s direction",
    "drops %@ into a pool of piranhas",
    "banishes %@ to the shadow realm",
    "drops %@ into Sagittarius A*",
    "releases an army of protomolecule hybrid monsters at %@",
    "designates %@'s email address as the official destination for all navlock related bug reports",
    "pours glitter onto %@'s keyboard",
    "forces %@ to play a vanilla ranger in D&D 5th edition",
    "forces %@ to play the last level of Simpsons Hit & Run over and over for 7 days",
    "turns the inside of %@'s PC into an aquarium",
    "has set mode +b %@!*@*",
    "locks %@ in a room with a TV playing season 8 of Game of Thrones on repeat",
    "unleashes a horde of angry canadian geese at %@",
    "locks %@ in a room where they have to solve traffic light captchas for all of eternity",
    "changes %@'s computer to light mode",
    "permanently subscribes %@ to daily LinkedIn inspirational posts"
]
