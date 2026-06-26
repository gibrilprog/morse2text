CXX := c++
CXXFLAGS := -std=c++17 -Wall -Wextra -Werror -Iinclude
OBJCXXFLAGS := $(CXXFLAGS) -fobjc-arc
GUI_LDFLAGS := -framework Cocoa -framework AVFoundation
BUILD_DIR := build

CORE_SRC := \
	src/MorseDictionary.cpp \
	src/MorseTranslator.cpp \
	src/ClickInterpreter.cpp

APP_SRC := src/main.cpp $(CORE_SRC)
TEST_SRC := tests/test_main.cpp $(CORE_SRC)
GUI_MM_SRC := src/gui_main.mm
GUI_CPP_SRC := $(CORE_SRC)

APP_OBJ := $(APP_SRC:%.cpp=$(BUILD_DIR)/%.o)
TEST_OBJ := $(TEST_SRC:%.cpp=$(BUILD_DIR)/%.o)
GUI_OBJ := $(GUI_MM_SRC:%.mm=$(BUILD_DIR)/%.o) $(GUI_CPP_SRC:%.cpp=$(BUILD_DIR)/%.o)

APP_BIN := $(BUILD_DIR)/morse2text
TEST_BIN := $(BUILD_DIR)/morse2text_tests
GUI_BIN := $(BUILD_DIR)/morse2text_gui

.PHONY: all gui test clean fclean re

all: $(APP_BIN) $(GUI_BIN)

gui: $(GUI_BIN)

$(APP_BIN): $(APP_OBJ)
	$(CXX) $(CXXFLAGS) $^ -o $@

$(TEST_BIN): $(TEST_OBJ)
	$(CXX) $(CXXFLAGS) $^ -o $@

$(GUI_BIN): $(GUI_OBJ)
	$(CXX) $(OBJCXXFLAGS) $^ $(GUI_LDFLAGS) -o $@

$(BUILD_DIR)/%.o: %.cpp
	@mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) -c $< -o $@

$(BUILD_DIR)/%.o: %.mm
	@mkdir -p $(dir $@)
	$(CXX) $(OBJCXXFLAGS) -c $< -o $@

test: $(TEST_BIN)
	./$(TEST_BIN)

clean:
	rm -rf $(BUILD_DIR)

fclean: clean

re: fclean all
