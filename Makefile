CXX := c++
CXXFLAGS := -std=c++17 -Wall -Wextra -Werror -Iinclude
BUILD_DIR := build

CORE_SRC := \
	src/MorseDictionary.cpp \
	src/MorseTranslator.cpp \
	src/ClickInterpreter.cpp

APP_SRC := src/main.cpp $(CORE_SRC)
TEST_SRC := tests/test_main.cpp $(CORE_SRC)

APP_OBJ := $(APP_SRC:%.cpp=$(BUILD_DIR)/%.o)
TEST_OBJ := $(TEST_SRC:%.cpp=$(BUILD_DIR)/%.o)

APP_BIN := $(BUILD_DIR)/morse2text
TEST_BIN := $(BUILD_DIR)/morse2text_tests

.PHONY: all test clean fclean re

all: $(APP_BIN)

$(APP_BIN): $(APP_OBJ)
	$(CXX) $(CXXFLAGS) $^ -o $@

$(TEST_BIN): $(TEST_OBJ)
	$(CXX) $(CXXFLAGS) $^ -o $@

$(BUILD_DIR)/%.o: %.cpp
	@mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) -c $< -o $@

test: $(TEST_BIN)
	./$(TEST_BIN)

clean:
	rm -rf $(BUILD_DIR)

fclean: clean

re: fclean all
