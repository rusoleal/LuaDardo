import '../../number/lua_number.dart';
import '../ast/block.dart';
import '../ast/exp.dart';
import '../lexer/lexer.dart';
import '../lexer/token.dart';
import 'block_parser.dart';
import 'optimizer.dart';
import 'prefix_exp_parser.dart';

class ExpParser {

  // explist ::= exp {‘,’ exp}
  static List<Exp> parseExpList(Lexer lexer) {
    List<Exp> exps =  <Exp>[];
    exps.add(parseExp(lexer));
    while (lexer.lookAhead() == TokenKind.sepComma) {
      lexer.nextToken();
      exps.add(parseExp(lexer));
    }
    return exps;
  }

  /*
    exp ::=  nil | false | true | Numeral | LiteralString | ‘...’ | functiondef |
         prefixexp | tableconstructor | exp binop exp | unop exp
    */
  /*
    exp   ::= exp12
    exp12 ::= exp11 {or exp11}
    exp11 ::= exp10 {and exp10}
    exp10 ::= exp9 {(‘<’ | ‘>’ | ‘<=’ | ‘>=’ | ‘~=’ | ‘==’) exp9}
    exp9  ::= exp8 {‘|’ exp8}
    exp8  ::= exp7 {‘~’ exp7}
    exp7  ::= exp6 {‘&’ exp6}
    exp6  ::= exp5 {(‘<<’ | ‘>>’) exp5}
    exp5  ::= exp4 {‘..’ exp4}
    exp4  ::= exp3 {(‘+’ | ‘-’ | ‘*’ | ‘/’ | ‘//’ | ‘%’) exp3}
    exp2  ::= {(‘not’ | ‘#’ | ‘-’ | ‘~’)} exp1
    exp1  ::= exp0 {‘^’ exp2}
    exp0  ::= nil | false | true | Numeral | LiteralString
            | ‘...’ | functiondef | prefixexp | tableconstructor
    */
  static Exp parseExp(Lexer lexer) {
    return parseExp12(lexer);
  }


  // x or y
   static Exp parseExp12(Lexer lexer) {
    Exp exp = parseExp11(lexer);
    while (lexer.lookAhead() == TokenKind.opOr) {
      Token op = lexer.nextToken();
      BinopExp lor = BinopExp(op, exp, parseExp11(lexer));
      exp = Optimizer.optimizeLogicalOr(lor);
    }
    return exp;
  }

  // x and y
   static Exp parseExp11(Lexer lexer) {
    Exp exp = parseExp10(lexer);
    while (lexer.lookAhead() == TokenKind.opAnd) {
      Token op = lexer.nextToken();
      BinopExp land = BinopExp(op, exp, parseExp10(lexer));
      exp = Optimizer.optimizeLogicalAnd(land);
    }
    return exp;
  }

  // compare
   static Exp parseExp10(Lexer lexer) {
    Exp exp = parseExp9(lexer);
    while (true) {
      switch (lexer.lookAhead()) {
        case TokenKind.opLt:
        case TokenKind.opGt:
        case TokenKind.opNe:
        case TokenKind.opLe:
        case TokenKind.opGe:
        case TokenKind.opEq:
          Token op = lexer.nextToken();
          exp = BinopExp(op, exp, parseExp9(lexer));
          break;
        default:
          return exp;
      }
    }
  }

  // x | y
   static Exp parseExp9(Lexer lexer) {
    Exp exp = parseExp8(lexer);
    while (lexer.lookAhead() == TokenKind.opBor) {
      Token op = lexer.nextToken();
      BinopExp bor = BinopExp(op, exp, parseExp8(lexer));
      exp = Optimizer.optimizeBitwiseBinaryOp(bor);
    }
    return exp;
  }

  // x ~ y
   static Exp parseExp8(Lexer lexer) {
    Exp exp = parseExp7(lexer);
    while (lexer.lookAhead() == TokenKind.opWave) {
      Token op = lexer.nextToken();
      BinopExp bxor = BinopExp(op, exp, parseExp7(lexer));
      exp = Optimizer.optimizeBitwiseBinaryOp(bxor);
    }
    return exp;
  }

  // x & y
   static Exp parseExp7(Lexer lexer) {
    Exp exp = parseExp6(lexer);
    while (lexer.lookAhead() == TokenKind.opBand) {
      Token op = lexer.nextToken();
      BinopExp band = BinopExp(op, exp, parseExp6(lexer));
      exp = Optimizer.optimizeBitwiseBinaryOp(band);
    }
    return exp;
  }

  // shift
   static Exp parseExp6(Lexer lexer) {
    Exp exp = parseExp5(lexer);
    while (true) {
      switch (lexer.lookAhead()) {
        case TokenKind.opShl:
        case TokenKind.opShr:
          Token op = lexer.nextToken();
          BinopExp shx = BinopExp(op, exp, parseExp5(lexer));
          exp = Optimizer.optimizeBitwiseBinaryOp(shx);
          break;
        default:
          return exp;
      }
    }
  }

  // a .. b
   static Exp parseExp5(Lexer lexer) {
    Exp exp = parseExp4(lexer);
    if (lexer.lookAhead() != TokenKind.opConcat) {
      return exp;
    }

    List<Exp> exps = <Exp>[];
    exps.add(exp);
    int line = 0;
    while (lexer.lookAhead() == TokenKind.opConcat) {
      line = lexer.nextToken().line;
      exps.add(parseExp4(lexer));
    }
    return ConcatExp(line, exps);
  }

  // x +/- y
   static Exp parseExp4(Lexer lexer) {
    Exp exp = parseExp3(lexer);
    while (true) {
      switch (lexer.lookAhead()) {
        case TokenKind.opAdd:
        case TokenKind.opMinus:
          Token op = lexer.nextToken();
          BinopExp arith = BinopExp(op, exp, parseExp3(lexer));
          exp = Optimizer.optimizeArithBinaryOp(arith);
          break;
        default:
          return exp;
      }
    }
  }

  // *, %, /, //
   static Exp parseExp3(Lexer lexer) {
    Exp exp = parseExp2(lexer);
    while (true) {
      switch (lexer.lookAhead()) {
        case TokenKind.opMul:
        case TokenKind.opMod:
        case TokenKind.opDiv:
        case TokenKind.opIDiv:
          Token op = lexer.nextToken();
          BinopExp arith = BinopExp(op, exp, parseExp2(lexer));
          exp = Optimizer.optimizeArithBinaryOp(arith);
          break;
        default:
          return exp;
      }
    }
  }

  // unary
   static Exp parseExp2(Lexer lexer) {
    switch (lexer.lookAhead()) {
      case TokenKind.opMinus:
      case TokenKind.opWave:
      case TokenKind.opLen:
      case TokenKind.opNot:
        Token op = lexer.nextToken();
        UnopExp exp = UnopExp(op, parseExp2(lexer));
        return Optimizer.optimizeUnaryOp(exp);
      default:
    }
    return parseExp1(lexer);
  }

  // x ^ y
   static Exp parseExp1(Lexer lexer) { // pow is right associative
    Exp exp = parseExp0(lexer);
    if (lexer.lookAhead() == TokenKind.opPow) {
      Token op = lexer.nextToken();
      exp = BinopExp(op, exp, parseExp2(lexer));
    }
    return Optimizer.optimizePow(exp);
  }

   static Exp parseExp0(Lexer lexer) {
    switch (lexer.lookAhead()) {
      case TokenKind.vararg: // ...
        return VarargExp(lexer.nextToken().line);
      case TokenKind.kwNil: // nil
        return NilExp(lexer.nextToken().line);
      case TokenKind.kwTrue: // true
        return TrueExp(lexer.nextToken().line);
      case TokenKind.kwFalse: // false
        return FalseExp(lexer.nextToken().line);
      case TokenKind.string: // LiteralString
        return StringExp.fromToken(lexer.nextToken());
      case TokenKind.number: // Numeral
        return parseNumberExp(lexer);
      case TokenKind.sepLCurly: // tableconstructor
        return parseTableConstructorExp(lexer);
      case TokenKind.kwFunction: // functiondef
        lexer.nextToken();
        return parseFuncDefExp(lexer);
      default: // prefixexp
        return PrefixExpParser.parsePrefixExp(lexer);
    }
  }

   static Exp parseNumberExp(Lexer lexer) {
    Token token = lexer.nextToken();
    int? i = LuaNumber.parseInteger(token.value);
    if (i != null) {
      return IntegerExp(token.line, i);
    }
    double? f = LuaNumber.parseFloat(token.value);
    if (f != null) {
      return FloatExp(token.line, f);
    }
    throw Exception("not a number: $token");
  }

  // functiondef ::= function funcbody
  // funcbody ::= ‘(’ [parlist] ‘)’ block end
  static FuncDefExp parseFuncDefExp(Lexer lexer) {
    int line = lexer.line;                    // function
    lexer.nextTokenOfKind(TokenKind.sepLParen);    // (
    List<String> parList = parseParList(lexer); // [parlist]
    lexer.nextTokenOfKind(TokenKind.sepRParen);    // )
    Block block = BlockParser.parseBlock(lexer);            // block
    lexer.nextTokenOfKind(TokenKind.kwEnd);        // end
    int lastLine = lexer.line;

    FuncDefExp fdExp = FuncDefExp(
        parList: parList,
        isVararg: parList.remove("..."),
        block: block
    );
    fdExp.line = line;
    fdExp.lastLine = lastLine;
    return fdExp;
  }

  // [parlist]
  // parlist ::= namelist [‘,’ ‘...’] | ‘...’
   static List<String> parseParList(Lexer lexer) {
    List<String> names = <String>[];

    switch (lexer.lookAhead()) {
      case TokenKind.sepRParen:
        return names;
      case TokenKind.vararg:
        lexer.nextToken();
        names.add("...");
        return names;
      default:
    }

    names.add(lexer.nextIdentifier().value);
    while (lexer.lookAhead() == TokenKind.sepComma) {
      lexer.nextToken();
      if (lexer.lookAhead() == TokenKind.identifier) {
        names.add(lexer.nextIdentifier().value);
      } else {
        lexer.nextTokenOfKind(TokenKind.vararg);
        names.add("...");
        break;
      }
    }

    return names;
  }

  // tableconstructor ::= ‘{’ [fieldlist] ‘}’
  static TableConstructorExp parseTableConstructorExp(Lexer lexer) {
    TableConstructorExp tcExp = TableConstructorExp();
    tcExp.line = lexer.line;
    lexer.nextTokenOfKind(TokenKind.sepLCurly); // {
    parseFieldList(lexer, tcExp);            // [fieldlist]
    lexer.nextTokenOfKind(TokenKind.sepRCurly); // }
    tcExp.lastLine = lexer.line;
    return tcExp;
  }

  // fieldlist ::= field {fieldsep field} [fieldsep]
   static void parseFieldList(Lexer lexer, TableConstructorExp tcExp) {
    if (lexer.lookAhead() != TokenKind.sepRCurly) {
      parseField(lexer, tcExp);

      while (isFieldSep(lexer.lookAhead())) {
        lexer.nextToken();
        if (lexer.lookAhead() != TokenKind.sepRCurly) {
          parseField(lexer, tcExp);
        } else {
          break;
        }
      }
    }
  }

  // fieldsep ::= ‘,’ | ‘;’
   static bool isFieldSep(TokenKind? kind) {
    return kind == TokenKind.sepComma || kind == TokenKind.sepSemi;
  }

  // field ::= ‘[’ exp ‘]’ ‘=’ exp | Name ‘=’ exp | exp
   static void parseField(Lexer lexer, TableConstructorExp tcExp) {
    if (lexer.lookAhead() == TokenKind.sepLBrack) {
      lexer.nextToken();                       // [
      tcExp.keyExps.add(parseExp(lexer));           // exp
      lexer.nextTokenOfKind(TokenKind.sepRBrack); // ]
      lexer.nextTokenOfKind(TokenKind.opAssign);  // =
      tcExp.valExps.add(parseExp(lexer));           // exp
      return;
    }

    Exp exp = parseExp(lexer);
    if (exp is NameExp) {
      if (lexer.lookAhead() == TokenKind.opAssign) {
        // Name ‘=’ exp => ‘[’ LiteralString ‘]’ = exp
        tcExp.keyExps.add(StringExp(exp.line, exp.name));
        lexer.nextToken();
        tcExp.valExps.add(parseExp(lexer));
        return;
      }
    }

    tcExp.keyExps.add(null);
    tcExp.valExps.add(exp);
  }

}