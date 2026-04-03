#pragma once

namespace lcodec {

    inline unsigned char tohex(unsigned char x) { 
        return  x > 9 ? x + 55 : x + 48; 
    }
    
    static sstring url_encode(sstring str) {
        sstring temp = "";
        size_t length = str.length();
        for (size_t i = 0; i < length; i++) {
            if (isalnum((unsigned char)str[i]) || (str[i] == '-') || (str[i] == '_') || (str[i] == '.') || (str[i] == '~'))
                temp += str[i];
            else if (str[i] == ' ')
                temp += "+";
            else {
                temp += '%';
                temp += tohex((unsigned char)str[i] >> 4);
                temp += tohex((unsigned char)str[i] % 16);
            }
        }
        return temp;
    }
    
    static sstring url_decode(sstring str) {
        sstring temp = "";
        size_t length = str.length();
        for (size_t i = 0; i < length; i++) {
            if (str[i] == '+') temp += ' ';
            else if (str[i] == '%'){
                unsigned char high = fromhex((unsigned char)str[++i]);
                unsigned char low = fromhex((unsigned char)str[++i]);
                temp += high * 16 + low;
            }
            else temp += str[i];
        }
        return temp;
    }
}
