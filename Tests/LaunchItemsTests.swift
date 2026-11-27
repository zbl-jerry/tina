// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation

enum LaunchItemsTests {
    static func run(_ suite: TestSuite) {
        let home = URL(fileURLWithPath: "/Users/fixture")

        func data(_ value: [String: Any]) -> Data {
            (try? PropertyListSerialization.data(fromPropertyList: value,
                                                 format: .xml,
                                                 options: 0)) ?? Data()
        }

        let parsed = LaunchItemsSupport.parse(data([
            "Label": "com.vendor.agent",
            "ProgramArguments": ["/usr/bin/true", "--flag"],
        ]))
        suite.expect(parsed?.label == "com.vendor.agent"
                     && parsed?.program == "/usr/bin/true",
                     "the label and first argument are read")

        let program = LaunchItemsSupport.parse(data([
            "Label": "com.vendor.daemon",
            "Program": "/usr/local/bin/helper",
        ]))
        suite.expect(program?.program == "/usr/local/bin/helper",
                     "a Program key wins over arguments")

        suite.expect(LaunchItemsSupport.parse(data(["Program": "/x"])) == nil,
                     "a plist without a label is not a launch item")
        suite.expect(LaunchItemsSupport.parse(Data("nope".utf8)) == nil,
                     "unreadable data is not a launch item")

        suite.expect(LaunchItemsSupport.scope(
            for: home.appendingPathComponent("Library/LaunchAgents/a.plist"), home: home)
            == .userAgent,
            "the home folder is the writable user scope")
        suite.expect(LaunchItemsSupport.scope(
            for: URL(fileURLWithPath: "/Library/LaunchAgents/a.plist"), home: home)
            == .systemAgent,
            "system agents are read-only")
        suite.expect(LaunchItemsSupport.scope(
            for: URL(fileURLWithPath: "/Library/LaunchDaemons/a.plist"), home: home)
            == .systemDaemon,
            "system daemons are read-only")
        suite.expect(LaunchItemsSupport.scope(
            for: URL(fileURLWithPath: "/tmp/a.plist"), home: home) == nil,
            "an unrelated plist has no launch scope")

        let list = """
        PID	Status	Label
        123	0	com.vendor.agent
        -	78	com.vendor.other
        """
        let labels = LaunchItemsSupport.loadedLabels(from: list)
        suite.expect(labels == ["com.vendor.agent", "com.vendor.other"],
                     "loaded labels come from the last column, got \(labels)")

        suite.expect(LaunchItemsSupport.bootoutArguments(uid: 501, label: "com.x")
                     == ["bootout", "gui/501/com.x"],
                     "stopping targets the user's own label")
        suite.expect(LaunchItemsSupport.bootstrapArguments(
            uid: 501, url: URL(fileURLWithPath: "/Users/x/Library/LaunchAgents/com.x.plist"))
            == ["bootstrap", "gui/501", "/Users/x/Library/LaunchAgents/com.x.plist"],
                     "starting bootstraps the user's own plist")

        let user = LaunchItem(url: URL(fileURLWithPath: "/u.plist"), label: "u",
                              program: nil, scope: .userAgent, loaded: true,
                              disabledByTina: false)
        let daemon = LaunchItem(url: URL(fileURLWithPath: "/d.plist"), label: "d",
                                program: nil, scope: .systemDaemon, loaded: false,
                                disabledByTina: false)
        suite.expect(user.canToggle && !daemon.canToggle,
                     "only the user scope can be toggled")
    }
}
