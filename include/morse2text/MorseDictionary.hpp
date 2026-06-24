#pragma once

#include <map>
#include <optional>
#include <string>

namespace m2t {

class MorseDictionary {
public:
    static const std::map<char, std::string>& textToMorseTable();
    static const std::map<std::string, char>& morseToTextTable();

    static std::optional<std::string> encode(char character);
    static std::optional<char> decode(const std::string& symbol);
    static bool isSupported(char character);
};

} // namespace m2t
