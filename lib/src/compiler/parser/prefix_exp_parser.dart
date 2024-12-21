import '../ast/exp.dart';
import '../lexer/lexer.dart';
import '../lexer/token.dart';
import 'exp_parser.dart';

class PrefixExpParser {

  /*
    prefixexp ::= Name
        | ‘(’ exp ‘)’
        | prefixexp ‘[’ exp ‘]’
        | prefixexp ‘.’ Name
        | prefixexp [‘:’ Name] args
    */
  static Exp parsePrefixExp(Lexer lexer) {
    Exp exp;
    if (lexer.lookAhead() == TokenKind.identifier) {
      Token id = lexer.nextIdentifier(); // Name
      exp = NameExp(id.line, id.value);
    } else { // ‘(’ exp ‘)’
      exp = parseParensExp(lexer);
    }
    return finishPrefixExp(lexer, exp);
  }

  static Exp parseParensExp(Lexer lexer) {
    lexer.nextTokenOfKind(TokenKind.sepLParen); // (
    Exp exp = ExpParser.parseExp(lexer);               // exp
    lexer.nextTokenOfKind(TokenKind.sepRParen); // )

    if (exp is VarargExp
    || exp is FuncCallExp
    || exp is NameExp
    || exp is TableAccessExp) {
      return ParensExp(exp);
    }

    // no need to keep parens
    return exp;
  }

  static Exp finishPrefixExp(Lexer lexer, Exp exp) {
    while (true) {
      switch (lexer.lookAhead()) {
        case TokenKind.sepLBrack: { // prefixexp ‘[’ exp ‘]’
          lexer.nextToken();                       // ‘[’
          Exp keyExp = ExpParser.parseExp(lexer);            // exp
          lexer.nextTokenOfKind(TokenKind.sepRBrack); // ‘]’
          exp = TableAccessExp(lexer.line, exp, keyExp);
          break;
        }
        case TokenKind.sepDot: { // prefixexp ‘.’ Name
          lexer.nextToken();                   // ‘.’
          Token name = lexer.nextIdentifier(); // Name
          Exp keyExp = StringExp.fromToken(name);
          exp = TableAccessExp(name.line, exp, keyExp);
          break;
        }
        case TokenKind.sepColon: // prefixexp ‘:’ Name args
        case TokenKind.sepLParen:
        case TokenKind.sepLCurly:
        case TokenKind.string: // prefixexp args
          exp = finishFuncCallExp(lexer, exp);
          break;
        default:
          return exp;
      }
    }
  }

  // functioncall ::=  prefixexp args | prefixexp ‘:’ Name args
  static FuncCallExp finishFuncCallExp(Lexer lexer, Exp prefixExp) {
    FuncCallExp fcExp = FuncCallExp(
      prefixExp: prefixExp,
      nameExp: parseNameExp(lexer),
      args: parseArgs(lexer)
    );
    fcExp.line = lexer.line; // todo
    fcExp.lastLine = lexer.line;
    return fcExp;
  }

  static StringExp? parseNameExp(Lexer lexer) {
    if (lexer.lookAhead() == TokenKind.sepColon) {
      lexer.nextToken();
      Token name = lexer.nextIdentifier();
      return StringExp.fromToken(name);
    }
    return null;
  }

  // args ::=  ‘(’ [explist] ‘)’ | tableconstructor | LiteralString
  static List<Exp> parseArgs(Lexer lexer) {
    switch (lexer.lookAhead()) {
      case TokenKind.sepLParen: // ‘(’ [explist] ‘)’
        lexer.nextToken(); // TOKEN_SEP_LPAREN
        List<Exp>? args;
        if (lexer.lookAhead() != TokenKind.sepRParen) {
          args = ExpParser.parseExpList(lexer);
        }
        lexer.nextTokenOfKind(TokenKind.sepRParen);
        return args ?? List<Exp>.empty();
      case TokenKind.sepLCurly: // ‘{’ [fieldlist] ‘}’
        return <Exp>[ExpParser.parseTableConstructorExp(lexer)];
      default: // LiteralString
        Token str = lexer.nextTokenOfKind(TokenKind.string);
        return <Exp>[StringExp.fromToken(str)];
    }
  }
}