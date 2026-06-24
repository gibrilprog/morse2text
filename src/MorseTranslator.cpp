#include "morse2text/MorseTranslator.hpp"

#include "morse2text/MorseDictionary.hpp"

#include <cctype>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

namespace m2t {

namespace {

std::string printableCharacter(char character)
{
    if (std::isprint(static_cast<unsigned char>(character)) != 0) {
        return std::string(1, character);
    }

    return "<non-printable>";
}

} // namespace

std::string MorseTranslator::textToMorse(std::string_view text)
{
    std::vector<std::string> tokens;
    bool needsWordGap = false;

    for (char character : text) {
        if (std::isspace(static_cast<unsigned char>(character)) != 0) {
            if (!tokens.empty()) {
                needsWordGap = true;
            }
            continue;
        }

        const auto encoded = MorseDictionary::encode(character);
        if (!encoded.has_value()) {
            throw std::invalid_argument("Unsupported character: " + printableCharacter(character));
        }

        if (needsWordGap) {
            tokens.emplace_back("/");
            needsWordGap = false;
        }

        tokens.emplace_back(*encoded);
    }

    std::ostringstream output;
    for (std::size_t index = 0; index < tokens.size(); ++index) {
        if (index != 0) {
            output << ' ';
        }
        output << tokens[index];
    }

    return output.str();
}

std::string MorseTranslator::morseToText(std::string_view morse)
{
    std::istringstream input{std::string(morse)};
    std::string token;
    std::string output;
    bool previousWasWordGap = false;

    while (input >> token) {
        if (token == "/") {
            if (!output.empty() && !previousWasWordGap) {
                output.push_back(' ');
                previousWasWordGap = true;
            }
            continue;
        }

        const auto decoded = MorseDictionary::decode(token);
        if (!decoded.has_value()) {
            throw std::invalid_argument("Unsupported morse symbol: " + token);
        }

        output.push_back(*decoded);
        previousWasWordGap = false;
    }

    return output;
}

} // namespace m2t
