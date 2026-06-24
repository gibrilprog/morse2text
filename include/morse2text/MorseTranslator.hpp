#pragma once

#include <string>
#include <string_view>

namespace m2t {

class MorseTranslator {
public:
    static std::string textToMorse(std::string_view text);
    static std::string morseToText(std::string_view morse);
};

} // namespace m2t
