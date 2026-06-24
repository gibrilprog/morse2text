#include "morse2text/MorseDictionary.hpp"

#include <cctype>

namespace m2t {

namespace {

char normalizeCharacter(char character)
{
    return static_cast<char>(std::toupper(static_cast<unsigned char>(character)));
}

} // namespace

const std::map<char, std::string>& MorseDictionary::textToMorseTable()
{
    static const std::map<char, std::string> table = {
        {'A', ".-"}, {'B', "-..."}, {'C', "-.-."}, {'D', "-.."},
        {'E', "."}, {'F', "..-."}, {'G', "--."}, {'H', "...."},
        {'I', ".."}, {'J', ".---"}, {'K', "-.-"}, {'L', ".-.."},
        {'M', "--"}, {'N', "-."}, {'O', "---"}, {'P', ".--."},
        {'Q', "--.-"}, {'R', ".-."}, {'S', "..."}, {'T', "-"},
        {'U', "..-"}, {'V', "...-"}, {'W', ".--"}, {'X', "-..-"},
        {'Y', "-.--"}, {'Z', "--.."},
        {'0', "-----"}, {'1', ".----"}, {'2', "..---"}, {'3', "...--"},
        {'4', "....-"}, {'5', "....."}, {'6', "-...."}, {'7', "--..."},
        {'8', "---.."}, {'9', "----."},
        {'.', ".-.-.-"}, {',', "--..--"}, {'?', "..--.."}, {'!', "-.-.--"},
        {':', "---..."}, {';', "-.-.-."}, {'/', "-..-."}, {'-', "-....-"},
        {'(', "-.--."}, {')', "-.--.-"}, {'@', ".--.-."},
    };

    return table;
}

const std::map<std::string, char>& MorseDictionary::morseToTextTable()
{
    static const std::map<std::string, char> table = [] {
        std::map<std::string, char> reversed;

        for (const auto& entry : textToMorseTable()) {
            reversed.emplace(entry.second, entry.first);
        }

        return reversed;
    }();

    return table;
}

std::optional<std::string> MorseDictionary::encode(char character)
{
    const char normalized = normalizeCharacter(character);
    const auto found = textToMorseTable().find(normalized);

    if (found == textToMorseTable().end()) {
        return std::nullopt;
    }

    return found->second;
}

std::optional<char> MorseDictionary::decode(const std::string& symbol)
{
    const auto found = morseToTextTable().find(symbol);

    if (found == morseToTextTable().end()) {
        return std::nullopt;
    }

    return found->second;
}

bool MorseDictionary::isSupported(char character)
{
    return encode(character).has_value();
}

} // namespace m2t
