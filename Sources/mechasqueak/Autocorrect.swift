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
import Regex

class Autocorrect {
    private static let proceduralSystemExpression =
        "([\\w\\s'.()/-]+) ([A-Za-z])([A-Za-z])-([A-Za-z]) ([A-Za-z])(?:(\\d+)-)?(\\d+)".r!
    private static let numberSubstitutions: [Character: Character] = [
        "1": "L",
        "5": "S",
        "8": "B",
        "0": "O"
    ]
    private static let letterSubstitutions: [Character: Character] = [
        "L": "1",
        "S": "5",
        "B": "8",
        "O": "0"
    ]

    static func check (system: String, search: SystemsAPISearchDocument) -> String? {
        let system = system.uppercased()

        // If the system name is less than 3 words, it is probably a special named system not a procedural one
        if system.split(separator: " ").count < 3 {
            /* Non-procedural systems are likely to exist in the Systems API, so we will suggest the one that is
             closest in edit distance */
            if search.data[0].distance ?? Int.max < 2 {
                return search.data[0].name
            }
        }

        guard system.contains(" SECTOR ") else {
            // Not a special system, and not a sector system, nothing we can do with this input
            return nil
        }

        let components = system.components(separatedBy: " SECTOR ")
        guard components.count == 2 else {
            // Only the sector itself was entered nothing after it, there is nothing we can do here, exit
            return nil
        }

        var sector = components[0]
        var fragments = components[1].components(separatedBy: " ")
        if sectors.contains(sector) == false {
            // If the sector is not in the known sector list attempt to replace it with a close match from the list
            let searchString = "\(sector) SECTOR"
            let sectorResults = sectors.map({
                ($0, searchString.levenshtein($0))
                }).sorted(by: {
                    $0.1 < $1.1
            })
            if sectorResults[0].1 < 3 {
                sector = sectorResults[0].0
            }
        }

        if proceduralSystemExpression.findFirst(in: system) != nil {
            // If the last part of the system name looks correct, return it with corrected sector name
            return "\(sector) SECTOR \(fragments.joined(separator: " "))"
        }

        /* This section of procedural system names do never contain digits, if there are one, replace them with letters
         that are commonly mistaken for these numbers. */
        if fragments[0].rangeOfCharacter(from: .decimalDigits) != nil {
            fragments[0] = Autocorrect.performNumberSubstitution(value: fragments[0])
        }
        var secondFragment = fragments[1]
        if secondFragment.first!.isNumber {
            /*  The first character of the second fragment of a procedural system name is never a letter.
             If it is a letter in the input, replace it with numbers that are commonly mistaken for numbers.  */
            secondFragment = secondFragment.replacingCharacters(
                in: ...secondFragment.startIndex,
                with: Autocorrect.performNumberSubstitution(value: String(secondFragment.first!))
            )
        }

        let correctedSystem = "\(sector) \(fragments.joined(separator: " "))"

        // Check that our corrected name now passes the check for valid procedural system
        if proceduralSystemExpression.findFirst(in: correctedSystem) != nil {
            return correctedSystem
        }

        // We were not able to correct this
        return nil
    }

    static func performNumberSubstitution (value: String) -> String {
        return String(value.map({ (char: Character) -> Character in
            if let substitution = numberSubstitutions[char] {
                return substitution
            }
            return char
        }))
    }

    static func performLetterrSubstitution (value: String) -> String {
        return String(value.map({ (char: Character) -> Character in
            if let substitution = letterSubstitutions[char] {
                return substitution
            }
            return char
        }))
    }
}

let sectors = [
    "Trianguli Sector",
    "Crucis Sector",
    "Tascheter Sector",
    "Hydrae Sector",
    "Col 285 Sector",
    "Scorpii Sector",
    "Shui Wei Sector",
    "Shudun Sector",
    "Yin Sector",
    "Jastreb Sector",
    "Pegasi Sector",
    "Cephei Sector",
    "Bei Dou Sector",
    "Puppis Sector",
    "Sharru Sector",
    "Alrai Sector",
    "Lyncis Sector",
    "Tucanae Sector",
    "Piscium Sector",
    "Herculis Sector",
    "Antliae Sector",
    "Arietis Sector",
    "Capricorni Sector",
    "Ceti Sector",
    "Core Sys Sector",
    "Blanco 1 Sector",
    "NGC 129 Sector",
    "NGC 225 Sector",
    "NGC 188 Sector",
    "IC 1590 Sector",
    "NGC 457 Sector",
    "M103 Sector",
    "NGC 654 Sector",
    "NGC 659 Sector",
    "NGC 663 Sector",
    "Col 463 Sector",
    "NGC 752 Sector",
    "NGC 744 Sector",
    "Stock 2 Sector",
    "h Persei Sector",
    "Chi Persei Sector",
    "IC 1805 Sector",
    "NGC 957 Sector",
    "Tr 2 Sector",
    "M34 Sector",
    "NGC 1027 Sector",
    "IC 1848 Sector",
    "NGC 1245 Sector",
    "NGC 1342 Sector",
    "IC 348 Sector",
    "Mel 22 Sector",
    "NGC 1444 Sector",
    "NGC 1502 Sector",
    "NGC 1528 Sector",
    "NGC 1545 Sector",
    "Hyades Sector",
    "NGC 1647 Sector",
    "NGC 1662 Sector",
    "NGC 1664 Sector",
    "NGC 1746 Sector",
    "NGC 1778 Sector",
    "NGC 1817 Sector",
    "NGC 1857 Sector",
    "NGC 1893 Sector",
    "M38 Sector",
    "Col 69 Sector",
    "NGC 1981 Sector",
    "Trapezium Sector",
    "Col 70 Sector",
    "M36 Sector",
    "M37 Sector",
    "NGC 2129 Sector",
    "NGC 2169 Sector",
    "M35 Sector",
    "NGC 2175 Sector",
    "Col 89 Sector",
    "NGC 2232 Sector",
    "Col 97 Sector",
    "NGC 2244 Sector",
    "NGC 2251 Sector",
    "Col 107 Sector",
    "NGC 2264 Sector",
    "M41 Sector",
    "NGC 2286 Sector",
    "NGC 2281 Sector",
    "NGC 2301 Sector",
    "Col 121 Sector",
    "M50 Sector",
    "NGC 2324 Sector",
    "NGC 2335 Sector",
    "NGC 2345 Sector",
    "NGC 2343 Sector",
    "NGC 2354 Sector",
    "NGC 2353 Sector",
    "Col 132 Sector",
    "Col 135 Sector",
    "NGC 2360 Sector",
    "NGC 2362 Sector",
    "NGC 2367 Sector",
    "Col 140 Sector",
    "NGC 2374 Sector",
    "NGC 2384 Sector",
    "NGC 2395 Sector",
    "NGC 2414 Sector",
    "M47 Sector",
    "NGC 2423 Sector",
    "Mel 71 Sector",
    "NGC 2439 Sector",
    "M46 Sector",
    "M93 Sector",
    "NGC 2451A Sector",
    "NGC 2477 Sector",
    "NGC 2467 Sector",
    "NGC 2482 Sector",
    "NGC 2483 Sector",
    "NGC 2489 Sector",
    "NGC 2516 Sector",
    "NGC 2506 Sector",
    "Col 173 Sector",
    "NGC 2527 Sector",
    "NGC 2533 Sector",
    "NGC 2539 Sector",
    "NGC 2547 Sector",
    "NGC 2546 Sector",
    "M48 Sector",
    "NGC 2567 Sector",
    "NGC 2571 Sector",
    "NGC 2579 Sector",
    "Pismis 4 Sector",
    "NGC 2627 Sector",
    "NGC 2645 Sector",
    "NGC 2632 Sector",
    "IC 2391 Sector",
    "IC 2395 Sector",
    "NGC 2669 Sector",
    "NGC 2670 Sector",
    "Tr 10 Sector",
    "M67 Sector",
    "IC 2488 Sector",
    "NGC 2910 Sector",
    "NGC 2925 Sector",
    "NGC 3114 Sector",
    "NGC 3228 Sector",
    "NGC 3247 Sector",
    "IC 2581 Sector",
    "NGC 3293 Sector",
    "NGC 3324 Sector",
    "NGC 3330 Sector",
    "Col 228 Sector",
    "IC 2602 Sector",
    "Tr 14 Sector",
    "Tr 16 Sector",
    "NGC 3519 Sector",
    "Fe 1 Sector",
    "NGC 3532 Sector",
    "NGC 3572 Sector",
    "Col 240 Sector",
    "NGC 3590 Sector",
    "NGC 3680 Sector",
    "NGC 3766 Sector",
    "IC 2944 Sector",
    "Stock 14 Sector",
    "NGC 4103 Sector",
    "NGC 4349 Sector",
    "Mel 111 Sector",
    "NGC 4463 Sector",
    "NGC 5281 Sector",
    "NGC 4609 Sector",
    "Jewel Box Sector",
    "NGC 5138 Sector",
    "NGC 5316 Sector",
    "NGC 5460 Sector",
    "NGC 5606 Sector",
    "NGC 5617 Sector",
    "NGC 5662 Sector",
    "NGC 5822 Sector",
    "NGC 5823 Sector",
    "NGC 6025 Sector",
    "NGC 6067 Sector",
    "NGC 6087 Sector",
    "NGC 6124 Sector",
    "NGC 6134 Sector",
    "NGC 6152 Sector",
    "NGC 6169 Sector",
    "NGC 6167 Sector",
    "NGC 6178 Sector",
    "NGC 6193 Sector",
    "NGC 6200 Sector",
    "NGC 6208 Sector",
    "NGC 6231 Sector",
    "NGC 6242 Sector",
    "Tr 24 Sector",
    "NGC 6250 Sector",
    "NGC 6259 Sector",
    "NGC 6281 Sector",
    "NGC 6322 Sector",
    "IC 4651 Sector",
    "NGC 6383 Sector",
    "M6 Sector",
    "NGC 6416 Sector",
    "IC 4665 Sector",
    "NGC 6425 Sector",
    "M7 Sector",
    "M23 Sector",
    "M20 Sector",
    "NGC 6520 Sector",
    "M21 Sector",
    "NGC 6530 Sector",
    "NGC 6546 Sector",
    "NGC 6604 Sector",
    "M16 Sector",
    "M18 Sector",
    "M17 Sector",
    "NGC 6633 Sector",
    "M25 Sector",
    "NGC 6664 Sector",
    "IC 4756 Sector",
    "M26 Sector",
    "NGC 6705 Sector",
    "NGC 6709 Sector",
    "Col 394 Sector",
    "Steph 1 Sector",
    "NGC 6716 Sector",
    "NGC 6755 Sector",
    "Stock 1 Sector",
    "NGC 6811 Sector",
    "NGC 6819 Sector",
    "NGC 6823 Sector",
    "NGC 6830 Sector",
    "NGC 6834 Sector",
    "NGC 6866 Sector",
    "NGC 6871 Sector",
    "NGC 6885 Sector",
    "IC 4996 Sector",
    "Mel 227 Sector",
    "NGC 6910 Sector",
    "M29 Sector",
    "NGC 6939 Sector",
    "NGC 6940 Sector",
    "NGC 7039 Sector",
    "NGC 7063 Sector",
    "NGC 7082 Sector",
    "M39 Sector",
    "IC 1396 Sector",
    "IC 5146 Sector",
    "NGC 7160 Sector",
    "NGC 7209 Sector",
    "NGC 7235 Sector",
    "NGC 7243 Sector",
    "NGC 7380 Sector",
    "NGC 7510 Sector",
    "M52 Sector",
    "NGC 7686 Sector",
    "NGC 7789 Sector",
    "NGC 7790 Sector",
    "IC 410 Sector",
    "NGC 3603 Sector",
    "NGC 7822 Sector",
    "NGC 281 Sector",
    "LBN 623 Sector",
    "Heart Sector",
    "Soul Sector",
    "Pleiades Sector",
    "Perseus Dark Region",
    "NGC 1333 Sector",
    "California Sector",
    "NGC 1491 Sector",
    "Hind Sector",
    "Trifid of the North Sector",
    "Flaming Star Sector",
    "NGC 1931 Sector",
    "Crab Sector",
    "Running Man Sector",
    "Orion Sector",
    "Col 359 Sector",
    "Spirograph Sector",
    "NGC 1999 Sector",
    "Flame Sector",
    "Horsehead Sector",
    "Witch Head Sector",
    "Monkey Head Sector",
    "Jellyfish Sector",
    "Rosette Sector",
    "Hubble's Variable Sector",
    "Cone Sector",
    "Seagull Sector",
    "Thor's Helmet Sector",
    "Skull and Crossbones Neb. Sector",
    "Pencil Sector",
    "NGC 3199 Sector",
    "Eta Carina Sector",
    "Statue of Liberty Sector",
    "NGC 5367 Sector",
    "NGC 6188 Sector",
    "Cat's Paw Sector",
    "NGC 6357 Sector",
    "Trifid Sector",
    "Lagoon Sector",
    "Eagle Sector",
    "Omega Sector",
    "B133 Sector",
    "IC 1287 Sector",
    "R CrA Sector",
    "NGC 6820 Sector",
    "Crescent Sector",
    "Sadr Region Sector",
    "Veil West Sector",
    "North America Sector",
    "B352 Sector",
    "Pelican Sector",
    "Veil East Sector",
    "Iris Sector",
    "Elephant's Trunk Sector",
    "Cocoon Sector",
    "Cave Sector",
    "NGC 7538 Sector",
    "Bubble Sector",
    "Aries Dark Region",
    "Taurus Dark Region",
    "Orion Dark Region",
    "Messier 78 Sector",
    "Barnard's Loop Sector",
    "Puppis Dark Region",
    "Puppis Dark Region B Sector",
    "Vela Dark Region",
    "Musca Dark Region",
    "Coalsack Sector",
    "Chamaeleon Sector",
    "Coalsack Dark Region",
    "Lupus Dark Region B Sector",
    "Lupus Dark Region",
    "Scorpius Dark Region",
    "IC 4604 Sector",
    "Pipe (stem) Sector",
    "Ophiuchus Dark Region B Sector",
    "Scutum Dark Region",
    "B92 Sector",
    "Snake Sector",
    "Pipe (bowl) Sector",
    "Ophiuchus Dark Region C Sector",
    "Rho Ophiuchi Sector",
    "Ophiuchus Dark Region",
    "Corona Austr. Dark Region",
    "Aquila Dark Region",
    "Vulpecula Dark Region",
    "Cepheus Dark Region",
    "Cepheus Dark Region B Sector",
    "Horsehead Dark Region",
    "Parrot's Head Sector",
    "Struve's Lost Sector",
    "Bow-Tie Sector",
    "Skull Sector",
    "Little Dumbbell Sector",
    "IC 289 Sector",
    "NGC 1360 Sector",
    "NGC 1501 Sector",
    "NGC 1514 Sector",
    "NGC 1535 Sector",
    "NGC 2022 Sector",
    "IC 2149 Sector",
    "IC 2165 Sector",
    "Butterfly Sector",
    "NGC 2371/2 Sector",
    "Eskimo Sector",
    "NGC 2438 Sector",
    "NGC 2440 Sector",
    "NGC 2452 Sector",
    "IC 2448 Sector",
    "NGC 2792 Sector",
    "NGC 2818 Sector",
    "NGC 2867 Sector",
    "NGC 2899 Sector",
    "IC 2501 Sector",
    "Eight Burst Sector",
    "IC 2553 Sector",
    "NGC 3195 Sector",
    "NGC 3211 Sector",
    "Ghost of Jupiter Sector",
    "IC 2621 Sector",
    "Owl Sector",
    "NGC 3699 Sector",
    "Blue planetary Sector",
    "NGC 4361 Sector",
    "Lemon Slice Sector",
    "IC 4191 Sector",
    "Spiral Planetary Sector",
    "NGC 5307 Sector",
    "NGC 5315 Sector",
    "Retina Sector",
    "NGC 5873 Sector",
    "NGC 5882 Sector",
    "NGC 5979 Sector",
    "Fine Ring Sector",
    "NGC 6058 Sector",
    "White Eyed Pea Sector",
    "NGC 6153 Sector",
    "NGC 6210 Sector",
    "IC 4634 Sector",
    "Bug Sector",
    "Box Sector",
    "NGC 6326 Sector",
    "NGC 6337 Sector",
    "Little Ghost Sector",
    "IC 4663 Sector",
    "NGC 6445 Sector",
    "Cat's Eye Sector",
    "IC 4673 Sector",
    "Red Spider Sector",
    "NGC 6565 Sector",
    "NGC 6563 Sector",
    "NGC 6572 Sector",
    "NGC 6567 Sector",
    "IC 4699 Sector",
    "NGC 6629 Sector",
    "NGC 6644 Sector",
    "IC 4776 Sector",
    "Ring Sector",
    "Phantom Streak Sector",
    "NGC 6751 Sector",
    "IC 4846 Sector",
    "IC 1297 Sector",
    "NGC 6781 Sector",
    "NGC 6790 Sector",
    "NGC 6803 Sector",
    "NGC 6804 Sector",
    "Little Gem Sector",
    "Blinking Sector",
    "NGC 6842 Sector",
    "Dumbbell Sector",
    "NGC 6852 Sector",
    "NGC 6884 Sector",
    "NGC 6879 Sector",
    "NGC 6886 Sector",
    "NGC 6891 Sector",
    "IC 4997 Sector",
    "Blue Flash Sector",
    "Fetus Sector",
    "Saturn Sector",
    "NGC 7026 Sector",
    "NGC 7027 Sector",
    "NGC 7048 Sector",
    "IC 5117 Sector",
    "IC 5148 Sector",
    "IC 5217 Sector",
    "Helix Sector",
    "NGC 7354 Sector",
    "Blue Snowball Sector",
    "G2 Dust Cloud Sector",
    "Regor Sector"
].map({ $0.uppercased() })
