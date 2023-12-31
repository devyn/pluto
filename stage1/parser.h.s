.set PARSER_STATUS_OK, 0
.set PARSER_STATUS_VALUE, 1
.set PARSER_STATUS_ERR, -1
.set PARSER_STATUS_OVERFLOW, -2

.set PARSER_STATE_LENGTH, 0x00
.set PARSER_STATE_INDEX, 0x04
.set PARSER_STATE_FIRST, 0x08

.set PARSER_STATE_ELEN, 0x18

.set PARSER_STATE_E_FLAG, 0x00
.set PARSER_STATE_E_BEGIN_NODE, 0x08
.set PARSER_STATE_E_CURRENT_NODE, 0x10

.set PARSER_FLAG_LIST, 1
.set PARSER_FLAG_ASSOC, 2

.set TOKEN_ERROR, 0x0
.set TOKEN_WHITESPACE, 0x1
.set TOKEN_COMMENT, 0x2
.set TOKEN_LIST_BEGIN, 0x10
.set TOKEN_LIST_END, 0x11
.set TOKEN_LIST_ASSOC, 0x12
.set TOKEN_SYMBOL, 0x20
.set TOKEN_STRING, 0x21
.set TOKEN_INTEGER_DECIMAL, 0x30
.set TOKEN_INTEGER_HEX, 0x31
.set TOKEN_ADDRESS, 0x40
