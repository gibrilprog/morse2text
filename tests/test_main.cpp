#include "morse2text/ClickInterpreter.hpp"
#include "morse2text/MorseDictionary.hpp"
#include "morse2text/MorseTranslator.hpp"

#include <exception>
#include <functional>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

namespace {

struct TestCase {
    std::string name;
    std::function<void()> run;
};

void require(bool condition, const std::string& message)
{
    if (!condition) {
        throw std::runtime_error(message);
    }
}

void requireEqual(const std::string& actual, const std::string& expected)
{
    if (actual != expected) {
        throw std::runtime_error("Expected [" + expected + "], got [" + actual + "]");
    }
}

template <typename ExceptionType, typename Callable>
void requireThrows(Callable callable)
{
    try {
        callable();
    } catch (const ExceptionType&) {
        return;
    }

    throw std::runtime_error("Expected exception was not thrown");
}

void testDictionary()
{
    require(m2t::MorseDictionary::encode('s') == std::optional<std::string>("..."), "S must encode to ...");
    require(m2t::MorseDictionary::encode('O') == std::optional<std::string>("---"), "O must encode to ---");
    require(m2t::MorseDictionary::decode("..---") == std::optional<char>('2'), "2 must decode correctly");
    require(m2t::MorseDictionary::encode('@') == std::optional<std::string>(".--.-."), "@ must encode correctly");
    require(!m2t::MorseDictionary::isSupported('#'), "# must not be supported yet");
}

void testTextToMorse()
{
    requireEqual(m2t::MorseTranslator::textToMorse("SOS TEST"), "... --- ... / - . ... -");
    requireEqual(m2t::MorseTranslator::textToMorse("morse2text"), "-- --- .-. ... . ..--- - . -..- -");
    requireEqual(m2t::MorseTranslator::textToMorse("Hello, World!"), ".... . .-.. .-.. --- --..-- / .-- --- .-. .-.. -.. -.-.--");
    requireEqual(m2t::MorseTranslator::textToMorse("  A   B  "), ".- / -...");
}

void testMorseToText()
{
    requireEqual(m2t::MorseTranslator::morseToText("... --- ... / - . ... -"), "SOS TEST");
    requireEqual(m2t::MorseTranslator::morseToText("-- --- .-. ... . ..--- - . -..- -"), "MORSE2TEXT");
    requireEqual(m2t::MorseTranslator::morseToText(".... . .-.. .-.. --- --..-- / .-- --- .-. .-.. -.. -.-.--"), "HELLO, WORLD!");
}

void testTranslatorErrors()
{
    requireThrows<std::invalid_argument>([] {
        (void)m2t::MorseTranslator::textToMorse("cafe#");
    });

    requireThrows<std::invalid_argument>([] {
        (void)m2t::MorseTranslator::morseToText("... --- ... / ......");
    });
}

void testClickInterpreterBuildsMessage()
{
    m2t::TimingConfig config;
    config.dotDuration = std::chrono::milliseconds(200);
    config.dashDuration = std::chrono::milliseconds(500);
    config.letterGap = std::chrono::milliseconds(1000);
    config.wordGap = std::chrono::milliseconds(2000);

    m2t::ClickInterpreter interpreter(config);

    interpreter.press(std::chrono::milliseconds(0));
    interpreter.release(std::chrono::milliseconds(200));
    interpreter.press(std::chrono::milliseconds(300));
    interpreter.release(std::chrono::milliseconds(500));
    interpreter.press(std::chrono::milliseconds(600));
    interpreter.release(std::chrono::milliseconds(800));
    interpreter.tick(std::chrono::milliseconds(1800));
    requireEqual(interpreter.morse(), "... ");
    requireEqual(interpreter.message(), "S");

    interpreter.tick(std::chrono::milliseconds(2800));
    requireEqual(interpreter.morse(), "... / ");
    requireEqual(interpreter.message(), "S ");

    interpreter.press(std::chrono::milliseconds(3000));
    interpreter.release(std::chrono::milliseconds(3200));
    interpreter.press(std::chrono::milliseconds(3300));
    interpreter.release(std::chrono::milliseconds(3800));
    interpreter.flush();
    requireEqual(interpreter.morse(), "... / .- ");
    requireEqual(interpreter.message(), "S A");
}

void testClickInterpreterTimingBoundaries()
{
    m2t::ClickInterpreter interpreter;

    interpreter.press(std::chrono::milliseconds(0));
    interpreter.release(std::chrono::milliseconds(200));
    requireEqual(interpreter.morse(), ".");
    requireEqual(interpreter.pendingSymbol(), ".");

    interpreter.reset();
    interpreter.press(std::chrono::milliseconds(0));
    interpreter.release(std::chrono::milliseconds(499));
    requireEqual(interpreter.pendingSymbol(), ".");

    interpreter.reset();
    interpreter.press(std::chrono::milliseconds(0));
    interpreter.release(std::chrono::milliseconds(500));
    requireEqual(interpreter.pendingSymbol(), "-");
}

void testClickInterpreterErrors()
{
    m2t::ClickInterpreter interpreter;

    requireThrows<std::logic_error>([&interpreter] {
        interpreter.release(std::chrono::milliseconds(10));
    });

    interpreter.press(std::chrono::milliseconds(50));
    requireThrows<std::logic_error>([&interpreter] {
        interpreter.press(std::chrono::milliseconds(60));
    });

    m2t::TimingConfig config;
    config.dotDuration = std::chrono::milliseconds(1000);
    config.dashDuration = std::chrono::milliseconds(200);
    requireThrows<std::invalid_argument>([&config] {
        m2t::ClickInterpreter invalidInterpreter(config);
    });
}

} // namespace

int main()
{
    const std::vector<TestCase> tests = {
        {"Dictionary", testDictionary},
        {"Text to morse", testTextToMorse},
        {"Morse to text", testMorseToText},
        {"Translator errors", testTranslatorErrors},
        {"Click interpreter builds message", testClickInterpreterBuildsMessage},
        {"Click interpreter timing boundaries", testClickInterpreterTimingBoundaries},
        {"Click interpreter errors", testClickInterpreterErrors},
    };

    int failures = 0;

    for (const auto& test : tests) {
        try {
            test.run();
            std::cout << "[PASS] " << test.name << '\n';
        } catch (const std::exception& exception) {
            ++failures;
            std::cerr << "[FAIL] " << test.name << ": " << exception.what() << '\n';
        }
    }

    if (failures != 0) {
        std::cerr << failures << " test(s) failed\n";
        return 1;
    }

    std::cout << tests.size() << " test(s) passed\n";
    return 0;
}
