import XCTest
@testable import Orbisonic

final class RoonNowPlayingMonitorTests: XCTestCase {
    func testParsesRoonServerPlaybackLine() {
        let line = "04/24 04:41:55 Trace: [roon-blackhole] [HighQuality, 24/96 FLAC => 24/96] [100% buf] [PLAYING @ 5:47/6:48] Time (Quadrophonic Mix) - Pink Floyd"

        let nowPlaying = RoonNowPlayingReader.parse(line: line)

        XCTAssertEqual(nowPlaying?.zoneName, "roon-blackhole")
        XCTAssertEqual(nowPlaying?.qualityFormat, "HighQuality, 24/96 FLAC => 24/96")
        XCTAssertEqual(nowPlaying?.tidyFormatText, "96 kHz / 24-bit")
        XCTAssertEqual(nowPlaying?.state, "PLAYING")
        XCTAssertEqual(nowPlaying?.positionText, "5:47")
        XCTAssertEqual(nowPlaying?.durationText, "6:48")
        XCTAssertEqual(nowPlaying?.title, "Time (Quadrophonic Mix)")
        XCTAssertEqual(nowPlaying?.artist, "Pink Floyd")
        XCTAssertEqual(nowPlaying?.updatedText, "04/24 04:41:55")
    }

    func testParsesRenderedOutputSampleRate() {
        let line = "04/24 04:41:55 Trace: [roon-blackhole] [HighQuality, 24/48 FLAC => 24/48 8ch 6ch] [100% buf] [PLAYING @ 5:47/6:48] Time (Quadrophonic Mix) - Pink Floyd"

        let nowPlaying = RoonNowPlayingReader.parse(line: line)

        XCTAssertEqual(nowPlaying?.outputSampleRate, 48_000)
    }

    func testParsesRoonFortyFourAsFortyFourPointOneKilohertz() {
        let line = "04/24 11:22:32 Trace: [roon-blackhole] [HighQuality, 16/44 QOBUZ FLAC => 16/44] [100% buf] [PLAYING @ 0:02/4:32] Colours - Grouplove"

        let nowPlaying = RoonNowPlayingReader.parse(line: line)

        XCTAssertEqual(nowPlaying?.outputSampleRate, 44_100)
        XCTAssertEqual(nowPlaying?.tidyFormatText, "44.1 kHz / 16-bit")
    }

    func testIgnoresNonPlaybackRoonLines() {
        let line = "04/24 04:41:40 Trace: [roon-blackhole] [zoneplayer/raat] sync BlackHole 64ch: realtime=1734095876333"

        XCTAssertNil(RoonNowPlayingReader.parse(line: line))
    }

    func testParseLatestReturnsNewestPlaybackLine() {
        let content = """
        04/24 04:39:19 Trace: [roon-blackhole] [HighQuality, 24/96 FLAC => 24/96] [100% buf] [PLAYING @ 3:11/6:48] Time (Quadrophonic Mix) - Pink Floyd
        04/24 04:41:40 Trace: [roon-blackhole] [zoneplayer/raat] sync BlackHole 64ch: realtime=1734095876333
        04/24 04:45:01 Trace: [roon-blackhole] [HighQuality, 24/96 FLAC => 24/96] [100% buf] [PLAYING @ 0:11/4:02] Money (Quadrophonic Mix) - Pink Floyd
        """

        let nowPlaying = RoonNowPlayingReader.parseLatest(in: content)

        XCTAssertEqual(nowPlaying?.title, "Money (Quadrophonic Mix)")
        XCTAssertEqual(nowPlaying?.positionText, "0:11")
    }

    func testParseLatestSignalPathDetectsStereoDownmix() {
        let content = """
        04/24 04:47:37 Trace: [roon-blackhole] [HighQuality, 24/96 FLAC => 24/96 4ch] [2% buf] [PLAYING @ 4:40/4:43] The Great Gig In The Sky (Quadrophonic Mix) - Pink Floyd / Clare Torry
            Source Format=Flac 96000/24/4 BitRate=5122 Quality=Lossless
            ChannelMapping Quad → 2.0
            Raat Device=BlackHole 64ch
            Output OutputType=Local_SharedMode_CoreAudio Quality=HighQuality SubType= Model=BlackHole 64ch
        """

        let signalPath = RoonNowPlayingReader.parseLatestSignalPath(in: content)

        XCTAssertEqual(signalPath?.sourceFormat, "Flac 96000/24/4 BitRate=5122 Quality=Lossless")
        XCTAssertEqual(signalPath?.sourceChannelCount, 4)
        XCTAssertEqual(signalPath?.sourceChannelText, "4 ch")
        XCTAssertEqual(signalPath?.channelMapping, "Quad → 2.0")
        XCTAssertEqual(signalPath?.device, "BlackHole 64ch")
        XCTAssertTrue(signalPath?.isDownmixingToStereo == true)
    }

    func testParseLatestSignalPathUsesNewestSourceFormat() {
        let content = """
            Source Format=Flac 48000/24/2 BitRate=1411 Quality=Lossless
            ChannelMapping Stereo → 2.0
            Raat Device=MacBook Pro Speakers
            Output OutputType=Local_SharedMode_CoreAudio Quality=HighQuality SubType= Model=MacBook Pro Speakers
        04/24 04:47:37 Trace: [roon-blackhole] [HighQuality, 24/96 FLAC => 24/96 4ch] [2% buf] [PLAYING @ 4:40/4:43] The Great Gig In The Sky (Quadrophonic Mix) - Pink Floyd / Clare Torry
            Source Format=Flac 96000/24/4 BitRate=5122 Quality=Lossless
            ChannelMapping Quad → 7.1
            Raat Device=BlackHole 64ch
            Output OutputType=Local_SharedMode_CoreAudio Quality=HighQuality SubType= Model=BlackHole 64ch
        """

        let signalPath = RoonNowPlayingReader.parseLatestSignalPath(in: content)

        XCTAssertEqual(signalPath?.sourceChannelCount, 4)
        XCTAssertEqual(signalPath?.channelMapping, "Quad → 7.1")
        XCTAssertFalse(signalPath?.isDownmixingToStereo == true)
    }

    func testParseLatestSignalPathReadsStereoSourceWithoutChannelMapping() {
        let content = """
        --[ SignalPath ]---------------------------------------------
        SignalPath Quality = HighQuality
        Elements:
            Source Format=Flac 44100/16/2  Quality=Lossless
            Raat Device=BlackHole 64ch
            Output OutputType=Local_SharedMode_CoreAudio Quality=HighQuality SubType= Model=BlackHole 64ch
        ------------------------------------------------------------
        """

        let signalPath = RoonNowPlayingReader.parseLatestSignalPath(in: content)

        XCTAssertEqual(signalPath?.sourceFormat, "Flac 44100/16/2  Quality=Lossless")
        XCTAssertEqual(signalPath?.sourceChannelCount, 2)
        XCTAssertEqual(signalPath?.sourceChannelText, "2 ch")
        XCTAssertEqual(signalPath?.channelMapping, "")
        XCTAssertEqual(signalPath?.statusText, "-")
        XCTAssertEqual(signalPath?.device, "BlackHole 64ch")
    }
}
