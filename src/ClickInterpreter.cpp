#include "morse2text/ClickInterpreter.hpp"

#include "morse2text/MorseDictionary.hpp"

#include <stdexcept>

namespace m2t {

ClickInterpreter::ClickInterpreter(TimingConfig config)
    : config_(config)
    , wordGapEmitted_(false)
{
    if (config_.dotDuration.count() <= 0 || config_.dashDuration.count() <= 0
        || config_.letterGap.count() <= 0 || config_.wordGap.count() <= 0) {
        throw std::invalid_argument("Timing values must be positive");
    }

    if (config_.dotDuration >= config_.dashDuration) {
        throw std::invalid_argument("dotDuration must be lower than dashDuration");
    }

    if (config_.letterGap > config_.wordGap) {
        throw std::invalid_argument("letterGap must be lower than or equal to wordGap");
    }
}

void ClickInterpreter::press(Milliseconds timestamp)
{
    if (pressStart_.has_value()) {
        throw std::logic_error("A click is already in progress");
    }

    pressStart_ = timestamp;
}

void ClickInterpreter::release(Milliseconds timestamp)
{
    if (!pressStart_.has_value()) {
        throw std::logic_error("Cannot release without a press");
    }

    const auto duration = timestamp - *pressStart_;
    if (duration.count() < 0) {
        throw std::invalid_argument("Release timestamp cannot be earlier than press timestamp");
    }

    pendingSymbol_.push_back(symbolForDuration(duration));
    pressStart_.reset();
    lastRelease_ = timestamp;
    wordGapEmitted_ = false;
}

void ClickInterpreter::tick(Milliseconds timestamp)
{
    if (!lastRelease_.has_value() || timestamp < *lastRelease_) {
        return;
    }

    const auto idleTime = timestamp - *lastRelease_;

    if (idleTime >= config_.letterGap) {
        finalizeLetter();
    }

    if (idleTime >= config_.wordGap) {
        appendWordGap();
    }
}

void ClickInterpreter::flush()
{
    finalizeLetter();
}

void ClickInterpreter::reset()
{
    pressStart_.reset();
    lastRelease_.reset();
    pendingSymbol_.clear();
    message_.clear();
    wordGapEmitted_ = false;
}

const std::string& ClickInterpreter::message() const
{
    return message_;
}

const std::string& ClickInterpreter::pendingSymbol() const
{
    return pendingSymbol_;
}

char ClickInterpreter::symbolForDuration(Milliseconds duration) const
{
    return duration >= config_.dashDuration ? '-' : '.';
}

void ClickInterpreter::finalizeLetter()
{
    if (pendingSymbol_.empty()) {
        return;
    }

    const auto decoded = MorseDictionary::decode(pendingSymbol_);
    if (!decoded.has_value()) {
        throw std::invalid_argument("Unknown morse symbol: " + pendingSymbol_);
    }

    message_.push_back(*decoded);
    pendingSymbol_.clear();
}

void ClickInterpreter::appendWordGap()
{
    if (message_.empty() || wordGapEmitted_) {
        return;
    }

    if (message_.back() != ' ') {
        message_.push_back(' ');
    }

    wordGapEmitted_ = true;
}

} // namespace m2t
