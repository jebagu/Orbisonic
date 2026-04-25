import XCTest
@testable import Orbisonic

final class RoonBridgeClientTests: XCTestCase {
    func testDecodesReadyBridgeSnapshot() throws {
        let json = """
        {
          "ok": true,
          "updated_at": "2026-04-25T12:00:00.000Z",
          "bridge": {
            "state": "paired",
            "message": "Ready to control Orbisonic Roon Input.",
            "zone_hint": "Orbisonic Roon Input"
          },
          "core": {
            "core_id": "core-1",
            "display_name": "Roon Server",
            "display_version": "2.0"
          },
          "selected_zone_id": "zone-1",
          "selected_zone": {
            "zone_id": "zone-1",
            "display_name": "Orbisonic Roon Input",
            "state": "playing",
            "is_play_allowed": false,
            "is_pause_allowed": true,
            "is_previous_allowed": true,
            "is_next_allowed": true,
            "is_seek_allowed": true,
            "outputs": [
              {
                "output_id": "output-1",
                "display_name": "Orbisonic Roon Input",
                "state": "playing"
              }
            ],
            "controls": {
              "play": false,
              "pause": true,
              "playpause": true,
              "stop": true,
              "previous": true,
              "next": true
            },
            "now_playing": {
              "seek_position": 42,
              "length": 240,
              "three_line": {
                "line1": "Money",
                "line2": "Pink Floyd",
                "line3": "The Dark Side of the Moon"
              }
            }
          },
          "zones": []
        }
        """

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let snapshot = try decoder.decode(RoonBridgeSnapshot.self, from: Data(json.utf8))

        XCTAssertTrue(snapshot.isReadyForTransport)
        XCTAssertEqual(snapshot.compactStatusText, "Connected")
        XCTAssertEqual(snapshot.statusText, "Orbisonic Roon Input / PLAYING")
        XCTAssertEqual(snapshot.audioPathText, "Orbisonic Roon Input")
        XCTAssertEqual(snapshot.selectedZone?.titleText, "Money")
        XCTAssertEqual(snapshot.selectedZone?.subtitleText, "Pink Floyd - The Dark Side of the Moon")
        XCTAssertEqual(snapshot.selectedZone?.allows(.pause), true)
        XCTAssertEqual(snapshot.selectedZone?.allows(.play), false)
        XCTAssertEqual(snapshot.selectedZone?.allows(.stop), true)
        XCTAssertEqual(snapshot.core?.displayName, "Roon Server")
    }

    func testReportsAuthorizationStateAsEnableInRoon() {
        let snapshot = RoonBridgeSnapshot(
            ok: false,
            updatedAt: nil,
            bridge: RoonBridgeInfo(
                state: "waiting_for_authorization",
                message: "Open Roon Settings > Extensions and enable Orbisonic Roon Bridge.",
                zoneHint: "Orbisonic Roon Input"
            ),
            core: nil,
            selectedZoneId: nil,
            selectedZone: nil,
            zones: []
        )

        XCTAssertFalse(snapshot.isReadyForTransport)
        XCTAssertEqual(snapshot.compactStatusText, "Enable in Roon")
        XCTAssertEqual(snapshot.statusText, "Open Roon Settings > Extensions and enable Orbisonic Roon Bridge.")
    }
}
