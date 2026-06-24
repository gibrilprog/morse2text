#pragma once

#include <chrono>
#include <optional>
#include <string>

namespace m2t {

struct TimingConfig {
    std::chrono::milliseconds dashThreshold{1000};
    std::chrono::milliseconds letterGap{1000};
    std::chrono::milliseconds wordGap{2000};
};

class ClickInterpreter {
public:
    using Milliseconds = std::chrono::milliseconds;

    explicit ClickInterpreter(TimingConfig config = {});

    void press(Milliseconds timestamp);
    void release(Milliseconds timestamp);
    void tick(Milliseconds timestamp);
    void flush();
    void reset();

    const std::string& message() const;
    const std::string& pendingSymbol() const;

private:
    void finalizeLetter();
    void appendWordGap();

    TimingConfig config_;
    std::optional<Milliseconds> pressStart_;
    std::optional<Milliseconds> lastRelease_;
    std::string pendingSymbol_;
    std::string message_;
    bool wordGapEmitted_;
};

} // namespace m2t
