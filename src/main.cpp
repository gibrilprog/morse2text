#include "morse2text/MorseTranslator.hpp"

#include <iostream>
#include <stdexcept>
#include <string>

namespace {

std::string joinArguments(int argc, char** argv, int startIndex)
{
    std::string joined;

    for (int index = startIndex; index < argc; ++index) {
        if (!joined.empty()) {
            joined.push_back(' ');
        }
        joined += argv[index];
    }

    return joined;
}

void printUsage(const char* executable)
{
    std::cerr << "Usage:\n"
              << "  " << executable << " --text \"SOS TEST\"\n"
              << "  " << executable << " --morse \"... --- ... / - . ... -\"\n";
}

} // namespace

int main(int argc, char** argv)
{
    if (argc < 3) {
        printUsage(argv[0]);
        return 1;
    }

    const std::string mode = argv[1];
    const std::string payload = joinArguments(argc, argv, 2);

    try {
        if (mode == "--text") {
            std::cout << m2t::MorseTranslator::textToMorse(payload) << '\n';
            return 0;
        }

        if (mode == "--morse") {
            std::cout << m2t::MorseTranslator::morseToText(payload) << '\n';
            return 0;
        }

        printUsage(argv[0]);
        return 1;
    } catch (const std::exception& exception) {
        std::cerr << "Error: " << exception.what() << '\n';
        return 1;
    }
}
