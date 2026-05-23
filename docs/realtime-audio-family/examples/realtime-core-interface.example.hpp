#pragma once

#include <cstdint>
#include <span>

namespace rtaudio_family {

struct AudioBlockView final {
    float** channels = nullptr;
    int numChannels = 0;
    int numFrames = 0;
};

struct RenderContext final {
    double sampleRate = 0.0;
    int numFrames = 0;
    std::uint64_t streamFrame = 0;
};

struct PreparedConfig final {
    double sampleRate = 0.0;
    int maxBlockFrames = 0;
    int maxInputChannels = 0;
    int maxOutputChannels = 0;
    int maxEventsPerBlock = 0;
};

struct CompactEvent final {
    std::uint32_t sampleOffset = 0;
    std::uint16_t type = 0;
    std::uint16_t flags = 0;
    std::uint32_t a = 0;
    std::uint32_t b = 0;
    float x = 0.0f;
    float y = 0.0f;
};

struct EventBlockView final {
    const CompactEvent* events = nullptr;
    int count = 0;
};

struct MeterSnapshot final {
    static constexpr int kMaxChannels = 128;
    float peak[kMaxChannels] = {0};
    float rms[kMaxChannels] = {0};
    int numChannels = 0;
    std::uint64_t generation = 0;
};

class RealtimeAudioCore final {
public:
    void prepare(const PreparedConfig& config); // May allocate. Not realtime.
    void reset() noexcept;

    void process(const RenderContext& ctx,
                 AudioBlockView input,
                 AudioBlockView output,
                 EventBlockView events,
                 MeterSnapshot& meterOut) noexcept;
};

} // namespace rtaudio_family
