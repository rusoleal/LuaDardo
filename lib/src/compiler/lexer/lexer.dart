import 'char_sequence.dart';
import 'token.dart';


/// 词法分析器
class Lexer {

  /// 源码
  CharSequence chunk;
  /// 源文件名
  String chunkName;
  /// 当前行号
  int line;

  // to support lookahead
  Token? cachedNextToken;
  int? lineBackup;

  final StringBuffer _buff = StringBuffer();

  Lexer(this.chunk,this.chunkName):line=1;

  TokenKind lookAhead() {
    if (cachedNextToken == null) {
      lineBackup = line;
      cachedNextToken = nextToken();
    }
    return cachedNextToken!.kind;
  }

  Token nextTokenOfKind(TokenKind? kind) {
    Token token = nextToken();
    if (token.kind != kind) {
      error("syntax error near '${token.value}'");
    }
    return token;
  }

  Token nextIdentifier() {
    return nextTokenOfKind(TokenKind.identifier);
  }

  Token nextToken() {
    if (cachedNextToken != null) {
      Token token = cachedNextToken!;
      cachedNextToken = null;
      return token;
    }

    skipWhiteSpaces();
    if (chunk.length <= 0) {
      return Token(line, TokenKind.eof, "EOF");
    }

    _buff.clear();
    switch (chunk.current) {
      case ';': chunk.next(1); return  Token(line, TokenKind.sepSemi,   ";");
      case ',': chunk.next(1); return  Token(line, TokenKind.sepComma,  ",");
      case '(': chunk.next(1); return  Token(line, TokenKind.sepLParen, "(");
      case ')': chunk.next(1); return  Token(line, TokenKind.sepRParen, ")");
      case ']': chunk.next(1); return  Token(line, TokenKind.sepRBrack, "]");
      case '{': chunk.next(1); return  Token(line, TokenKind.sepLCurly, "{");
      case '}': chunk.next(1); return  Token(line, TokenKind.sepRCurly, "}");
      case '+': chunk.next(1); return  Token(line, TokenKind.opAdd,     "+");
      case '-': chunk.next(1); return  Token(line, TokenKind.opMinus,   "-");
      case '*': chunk.next(1); return  Token(line, TokenKind.opMul,     "*");
      case '^': chunk.next(1); return  Token(line, TokenKind.opPow,     "^");
      case '%': chunk.next(1); return  Token(line, TokenKind.opMod,     "%");
      case '&': chunk.next(1); return  Token(line, TokenKind.opBand,    "&");
      case '|': chunk.next(1); return  Token(line, TokenKind.opBor,     "|");
      case '#': chunk.next(1); return  Token(line, TokenKind.opLen,     "#");
      case ':':
        if (chunk.startsWith("::")) {
          chunk.next(2);
          return  Token(line, TokenKind.sepLabel, "::");
        } else {
          chunk.next(1);
          return  Token(line, TokenKind.sepColon, ":");
        }
      case '/':
        if (chunk.startsWith("//")) {
          chunk.next(2);
          return  Token(line, TokenKind.opIDiv, "//");
        } else {
          chunk.next(1);
          return  Token(line, TokenKind.opDiv, "/");
        }
      case '~':
        if (chunk.startsWith("~=")) {
          chunk.next(2);
          return  Token(line, TokenKind.opNe, "~=");
        } else {
          chunk.next(1);
          return  Token(line, TokenKind.opWave, "~");
        }
      case '=':
        if (chunk.startsWith("==")) {
          chunk.next(2);
          return  Token(line, TokenKind.opEq, "==");
        } else {
          chunk.next(1);
          return  Token(line, TokenKind.opAssign, "=");
        }
      case '<':
        if (chunk.startsWith("<<")) {
          chunk.next(2);
          return  Token(line, TokenKind.opShl, "<<");
        } else if (chunk.startsWith("<=")) {
          chunk.next(2);
          return  Token(line, TokenKind.opLe, "<=");
        } else {
          chunk.next(1);
          return  Token(line, TokenKind.opLt, "<");
        }
      case '>':
        if (chunk.startsWith(">>")) {
          chunk.next(2);
          return  Token(line, TokenKind.opShr, ">>");
        } else if (chunk.startsWith(">=")) {
          chunk.next(2);
          return  Token(line, TokenKind.opGe, ">=");
        } else {
          chunk.next(1);
          return  Token(line, TokenKind.opGt, ">");
        }
      case '.':
        if (chunk.startsWith("...")) {
          chunk.next(3);
          return  Token(line, TokenKind.vararg, "...");
        } else if (chunk.startsWith("..")) {
          chunk.next(2);
          return  Token(line, TokenKind.opConcat, "..");
        } else if (chunk.length == 1) {
          chunk.next(1);
          return  Token(line, TokenKind.sepDot, ".");
        }else if(!CharSequence.isDigit(chunk.charAt(1))){
          chunk.next(1);
          return  Token(line, TokenKind.sepDot, ".");
        }else{  // is digit
          return Token(line, TokenKind.number, readNumeral());
        }
      case '[':  // long string or simply '['
        int sep = _skipSep();
        if (sep >= 0) {
          return Token(line, TokenKind.string, readLongString(true, sep));
        } else if (sep == -1) {
          return Token(line, TokenKind.sepLBrack, "[");
        } else { 
          error("invalid long string delimiter"); 
        }

        break;
      case '\'':
      case '"':
        return  Token(line, TokenKind.string, readString());
    }

    if (CharSequence.isDigit(chunk.current)) {
      return Token(line, TokenKind.number, readNumeral());
    }

    if (chunk.current == '_' || CharSequence.isLetter(chunk.current)) {
      do {
        _saveAndNext();
      } while (CharSequence.isalnum(chunk.current) || chunk.current == '_');
      String id = _buff.toString();
      return keywords.containsKey(id)
          ?  Token(line, keywords[id], id)
          :  Token(line, TokenKind.identifier, id);
    }

    return error("unexpected symbol near ${chunk.current}");
  }

  void skipWhiteSpaces() {
    while (chunk.length > 0) {
      if (chunk.startsWith("--")) {
        skipComment();
      } else if (chunk.startsWith("\r\n") || chunk.startsWith("\n\r")) {
        chunk.next(2);
        line += 1;
      } else if (CharSequence.isNewLine(chunk.current)) {
        chunk.next(1);
        line += 1;
      } else if(CharSequence.isWhiteSpace(chunk.current)) {
        chunk.next(1);
      } else {
        break;
      }
    }
  }

  void skipComment() {
    chunk.next(2); // skip --

    // long comment ?
    if (chunk.startsWith("[")) {
      int sep = _skipSep();
      _buff.clear(); /* `skip_sep' 可能会弄脏缓冲区 */
      if (sep >= 0) {
        readLongString(false, sep);  /* long comment */
        _buff.clear();
        return;
      }
    }

    // short comment
    while(chunk.length > 0 && !CharSequence.isNewLine(chunk.current)) {
      chunk.next(1);
    }
  }

  void _save() {
    _buff.write(chunk.current);
  }

  void _saveC(int c) {
    _buff.writeCharCode(c);
  }

  void _saveAndNext(){
    _save();
    chunk.next(1);
  }

  void _incLineNumber() {
    String old = chunk.current;
    chunk.next(1); // skip '\n' or '\r'
    if (CharSequence.isNewLine(chunk.current) && chunk.current != old) {
      chunk.next(1); // skip '\n\r' or '\r\n'
    }
    if (++line < 0) { // overflow
      error("chunk has too many lines");
    }
  }

  String readString() {
    String del = chunk.current;
    _saveAndNext();
    while (chunk.current != del) {
      switch (chunk.current) {
        // EOZ
        case '': error("unfinished string"); break;
        case '\n':
        case '\r':
          error("unfinished string");
          continue;
        case '\\':
        {
            late int c;
            // do not save the '\'
            chunk.next(1);
            switch (chunk.current) {
              case 'a':
                c = 7;  // '\a'
                break;
              case 'b':
                c = 8;  // '\b'
                break;
              case 'f':
                c = 12; // '\f'
                break;
              case 'n':
                c = 10; // '\n'
                break;
              case 'r':
                c = 13; // '\r'
                break;
              case 't':
                c = 9;  // '\t'
                break;
              case 'v':
                c = 11; // '\v'
                break;
              case 'x': // '\xXX'
                var hex = chunk.substring(1, 3);
                if(CharSequence.isxDigit(hex)){
                  _saveC(int.parse(hex, radix: 16));
                  chunk.next(3);
                  continue;
                } else { 
                  error("hexadecimal digit expected"); 
                }
                break;
              case 'u': // '\u{XXX}'
                chunk.next(1);
                if(chunk.current != '{') error("missing '{'");

                int j = 1;
                while(CharSequence.isxDigit(chunk.charAt(j))) {
                  j++;
                }

                if(chunk.charAt(j) != '}') error("missing '}'");
                var seq = chunk.substring(1, j);
                int d = int.parse(seq, radix: 16);
                if (d <= 0x10FFFF) {
                  _saveC(d);
                  chunk.next(j+1);
                } else { 
                  error("UTF-8 value too large near '$seq'"); 
                }
                continue;
              case '\n': case '\r':
                _saveC(10); // write '\n'
                _incLineNumber();
                continue;
              case '\\': case '"': case '\'':
                _saveAndNext();
                continue;
              case '': // EOZ
                continue; // will raise an error next loop
              case 'z':    // zap following span of spaces
                chunk.next(1);
                while (chunk.length > 0 && CharSequence.isWhiteSpace(chunk.current)) {
                  if(CharSequence.isNewLine(chunk.current)) { 
                    _incLineNumber(); 
                  }
                  else { 
                    chunk.next(1); 
                  }
                }
                continue;
              default:
                if (!CharSequence.isDigit(chunk.current)) {
                  error("invalid escape sequence near '\\${chunk.current}'");
                } else {  // digital escape '\ddd'
                  c = 0;
                  /* 最多读取3位数字 */
                  for (int i = 0; i < 3 && CharSequence.isDigit(chunk.current); i++) {
                    c = 10 * c + (chunk.current - '0') as int;
                      chunk.next(1);
                  }
                  _saveC(c);
                }
                continue;
            }
            _saveC(c);
            chunk.next(1);
            continue;
          }
        default:
          _saveAndNext();
      }
    }
    _saveAndNext(); // 跳过分隔符
    var rawToken = _buff.toString();
    return rawToken.substring(1, rawToken.length - 1);
  }

  String readLongString(bool isString, int sep) {
    _saveAndNext(); /* skip 2nd `[' */
    if (CharSequence.isNewLine(chunk.current)) {
      /* string starts with a newline? */
      _incLineNumber();
    }
    /* skip it */
    loop:
    for (;;) {
      switch (chunk.current) {
        case '':
          error(
              isString ? "unfinished long string" : "unfinished long comment");
          break;
        case ']':
          if (_skipSep() == sep) {
            _saveAndNext(); /* skip 2nd `]' */
            break loop;
          }
          break;

        case '\n':
        case '\r':
          _saveC(10); // write '\n'
          _incLineNumber();
          if (!isString) _buff.clear();
          break;
        default:
          if (isString) {
            _saveAndNext();
          } else {
            chunk.next(1); 
          }
      }
    }
    /* loop */
    if (isString) {
      var rawToken = _buff.toString();
      int trimBy = 2 + sep;
      return rawToken.substring(trimBy, rawToken.length - trimBy);
    } else {
      return ''; 
    }
  }

  int _skipSep() {
    int count = 0;
    String s = chunk.current;
    // assert(s == '[' || s == ']') ;
    _saveAndNext();
    while (chunk.current == '=') {
      _saveAndNext();
      count++;
    }
    return (chunk.current == s) ? count : (-count) - 1;
  }

  String readNumeral() {
    //print('readNumeral');
    String expo = "[Ee]";
    String first = chunk.current;
    _saveAndNext();
    if (first == '0' && chunk.startsWithRegexp(RegExp("[xX]"))) {
      /* hexadecimal? */
      expo = "[Pp]";
      _saveAndNext();
    }

    for (;;) {
      if (chunk.startsWithRegexp(RegExp(expo))) {
        /* exponent part? */
        _saveAndNext();
        if (chunk.startsWithRegexp(RegExp("[-+]"))) {
          /* optional exponent sign */
          _saveAndNext();
        }
      }
      if (CharSequence.isxDigit(chunk.current) || chunk.current == '.') {
        _saveAndNext();
      }
      else  {
        break;
      }
    }
    //print('readNumeral result: ${_buff.toString()}');
    return _buff.toString();
  }

  int? _line() {
    return cachedNextToken != null ? lineBackup : line;
  }

  error(String msg) {
    throw Exception("$chunkName:${_line()}: $msg");
  }
}
