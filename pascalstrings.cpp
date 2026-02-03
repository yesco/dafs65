#include <iostream>
#include <string>
#include <vector>
#include <cstdint>

// 1. Define the Pascal String structure
struct PascalString {
    std::vector<uint8_t> data;

    // Constructor to create from a string literal
    PascalString(const char* str, size_t len) {
        if (len > 255) len = 255; // Pascal strings max length is 255
        data.reserve(len + 1);
        data.push_back(static_cast<uint8_t>(len)); // Length byte
        for (size_t i = 0; i < len; ++i) {
            data.push_back(str[i]);
        }
    }

    void print() const {
        if (data.empty()) return;
        std::cout << "Length: " << (int)data[0] << ", Data: ";
        for (size_t i = 1; i < data.size(); ++i) {
            std::cout << data[i];
        }
        std::cout << std::endl;
    }
};

// 2. Define the User-Defined Literal operator p""
PascalString operator"" _p(const char* str, size_t len) {
    return PascalString(str, len);
}

int main() {
    // 3. Usage with p"foobar" notation
    auto pStr = p"HelloPascal";
    pStr.print();

    auto shortStr = p"Hi";
    shortStr.print();

    return 0;
}
