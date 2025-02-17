import '../ast/block.dart';
import '../ast/exp.dart';
import '../ast/stat.dart';
import '../lexer/lexer.dart';
import '../lexer/token.dart';
import 'block_parser.dart';
import 'exp_parser.dart';
import 'prefix_exp_parser.dart';

class StatParser {

  /*
    stat ::=  ‘;’
        | break
        | ‘::’ Name ‘::’
        | goto Name
        | do block end
        | while exp do block end
        | repeat block until exp
        | if exp then block {elseif exp then block} [else block] end
        | for Name ‘=’ exp ‘,’ exp [‘,’ exp] do block end
        | for namelist in explist do block end
        | function funcname funcbody
        | local function Name funcbody
        | local namelist [‘=’ explist]
        | varlist ‘=’ explist
        | functioncall
    */
  static Stat parseStat(Lexer lexer) {
    switch (lexer.lookAhead()) {
      case TokenKind.sepSemi:    return parseEmptyStat(lexer);
      case TokenKind.kwBreak:    return parseBreakStat(lexer);
      case TokenKind.sepLabel:   return parseLabelStat(lexer);
      case TokenKind.kwGoto:     return parseGotoStat(lexer);
      case TokenKind.kwDo:       return parseDoStat(lexer);
      case TokenKind.kwWhile:    return parseWhileStat(lexer);
      case TokenKind.kwRepeat:   return parseRepeatStat(lexer);
      case TokenKind.kwIf:       return parseIfStat(lexer);
      case TokenKind.kwFor:      return parseForStat(lexer);
      case TokenKind.kwFunction: return parseFuncDefStat(lexer);
      case TokenKind.kwLocal:    return parseLocalAssignOrFuncDefStat(lexer);
      default:                return parseAssignOrFuncCallStat(lexer);
    }
  }

  // ;
   static EmptyStat parseEmptyStat(Lexer lexer) {
    lexer.nextTokenOfKind(TokenKind.sepSemi);
    return EmptyStat.instance;
  }

  // break
   static BreakStat parseBreakStat(Lexer lexer) {
    lexer.nextTokenOfKind(TokenKind.kwBreak);
    return BreakStat(lexer.line);
  }

  // ‘::’ Name ‘::’
   static LabelStat parseLabelStat(Lexer lexer) {
    lexer.nextTokenOfKind(TokenKind.sepLabel);          // ::
    String? name = lexer.nextIdentifier().value; // name
    lexer.nextTokenOfKind(TokenKind.sepLabel);          // ::
    return LabelStat(name);
  }

  // goto Name
   static GotoStat parseGotoStat(Lexer lexer) {
    lexer.nextTokenOfKind(TokenKind.kwGoto);            // goto
    String? name = lexer.nextIdentifier().value; // name
    return GotoStat(name);
  }

  // do block end
   static DoStat parseDoStat(Lexer lexer) {
    lexer.nextTokenOfKind(TokenKind.kwDo);  // do
    Block block = BlockParser.parseBlock(lexer);     // block
    lexer.nextTokenOfKind(TokenKind.kwEnd); // end
    return DoStat(block);
  }

  // while exp do block end
   static WhileStat parseWhileStat(Lexer lexer) {
    lexer.nextTokenOfKind(TokenKind.kwWhile); // while
    Exp exp = ExpParser.parseExp(lexer);             // exp
    lexer.nextTokenOfKind(TokenKind.kwDo);    // do
    Block block = BlockParser.parseBlock(lexer);       // block
    lexer.nextTokenOfKind(TokenKind.kwEnd);   // end
    return WhileStat(exp, block);
  }

  // repeat block until exp
   static RepeatStat parseRepeatStat(Lexer lexer) {
    lexer.nextTokenOfKind(TokenKind.kwRepeat); // repeat
    Block block = BlockParser.parseBlock(lexer);        // block
    lexer.nextTokenOfKind(TokenKind.kwUntil);  // until
    Exp exp = ExpParser.parseExp(lexer);              // exp
    return RepeatStat(block, exp);
  }

  // if exp then block {elseif exp then block} [else block] end
   static IfStat parseIfStat(Lexer lexer) {
    List<Exp> exps = <Exp>[];
    List<Block> blocks = <Block>[];

    lexer.nextTokenOfKind(TokenKind.kwIf);       // if
    exps.add(ExpParser.parseExp(lexer));                // exp
    lexer.nextTokenOfKind(TokenKind.kwThen);     // then
    blocks.add(BlockParser.parseBlock(lexer));            // block

    while (lexer.lookAhead() == TokenKind.kwElseif) {
      lexer.nextToken();                    // elseif
      exps.add(ExpParser.parseExp(lexer));            // exp
      lexer.nextTokenOfKind(TokenKind.kwThen); // then
      blocks.add(BlockParser.parseBlock(lexer));        // block
    }

    // else block => elseif true then block
    if (lexer.lookAhead() == TokenKind.kwElse) {
      lexer.nextToken();                    // else
      exps.add(TrueExp(lexer.line));  //
      blocks.add(BlockParser.parseBlock(lexer));        // block
    }

    lexer.nextTokenOfKind(TokenKind.kwEnd);      // end
    return IfStat(exps, blocks);
  }

  // for Name ‘=’ exp ‘,’ exp [‘,’ exp] do block end
  // for namelist in explist do block end
   static Stat parseForStat(Lexer lexer) {
    int lineOfFor = lexer.nextTokenOfKind(TokenKind.kwFor).line;
    String name = lexer.nextIdentifier().value;
    if (lexer.lookAhead() == TokenKind.opAssign) {
      return finishForNumStat(lexer, name, lineOfFor);
    } else {
      return finishForInStat(lexer, name);
    }
  }

  // for Name ‘=’ exp ‘,’ exp [‘,’ exp] do block end
  static ForNumStat finishForNumStat(Lexer lexer, String name, int lineOfFor) {
    lexer.nextTokenOfKind(TokenKind.opAssign); // =
    var initExp = ExpParser.parseExp(lexer); // exp
    lexer.nextTokenOfKind(TokenKind.sepComma); // ,
    var limitExp = ExpParser.parseExp(lexer); // exp
    Exp stepExp;
    if (lexer.lookAhead() == TokenKind.sepComma) {
      lexer.nextToken(); // ,
      stepExp = ExpParser.parseExp(lexer); // exp
    } else {
      stepExp = IntegerExp(lexer.line, 1);
    }

    lexer.nextTokenOfKind(TokenKind.kwDo); // do
    var lineOfDo = lexer.line; //
    var block = BlockParser.parseBlock(lexer); // block
    lexer.nextTokenOfKind(TokenKind.kwEnd); // end

    return ForNumStat(
        lineOfFor: lineOfFor,
        // for
        varName: name,
        // name
        initExp: initExp,
        limitExp: limitExp,
        stepExp: stepExp,
        lineOfDo: lineOfDo,
        block: block);
  }

  // for namelist in explist do block end
  // namelist ::= Name {‘,’ Name}
  // explist ::= exp {‘,’ exp}
  static ForInStat finishForInStat(Lexer lexer, String name0) {
    // for
    var nameList = finishNameList(lexer, name0); // namelist
    lexer.nextTokenOfKind(TokenKind.kwIn); // in
    var expList = ExpParser.parseExpList(lexer); // explist
    lexer.nextTokenOfKind(TokenKind.kwDo); // do
    var lineOfDo = lexer.line; //
    var block = BlockParser.parseBlock(lexer); // block
    lexer.nextTokenOfKind(TokenKind.kwEnd); // end

    return ForInStat(
        nameList: nameList, expList: expList, lineOfDo: lineOfDo, block: block);
  }

  // namelist ::= Name {‘,’ Name}
   static List<String> finishNameList(Lexer lexer, String name0) {
    List<String> names = <String>[];
    names.add(name0);
    while (lexer.lookAhead() == TokenKind.sepComma) {
      lexer.nextToken();                            // ,
      names.add(lexer.nextIdentifier().value); // Name
    }
    return names;
  }

  // local function Name funcbody
  // local namelist [‘=’ explist]
   static Stat parseLocalAssignOrFuncDefStat(Lexer lexer) {
    lexer.nextTokenOfKind(TokenKind.kwLocal);
    if (lexer.lookAhead() == TokenKind.kwFunction) {
      return finishLocalFuncDefStat(lexer);
    } else {
      return finishLocalVarDeclStat(lexer);
    }
  }

  /*
    http://www.lua.org/manual/5.3/manual.html#3.4.11

    function f() end          =>  f = function() end
    function t.a.b.c.f() end  =>  t.a.b.c.f = function() end
    function t.a.b.c:f() end  =>  t.a.b.c.f = function(self) end
    local function f() end    =>  local f; f = function() end

    The statement `local function f () body end`
    translates to `local f; f = function () body end`
    not to `local f = function () body end`
    (This only makes a difference when the body of the function
     contains references to f.)
    */
  // local function Name funcbody
   static LocalFuncDefStat finishLocalFuncDefStat(Lexer lexer) {
    lexer.nextTokenOfKind(TokenKind.kwFunction);        // local function
    String? name = lexer.nextIdentifier().value; // name
    FuncDefExp fdExp = ExpParser.parseFuncDefExp(lexer);       // funcbody
    return LocalFuncDefStat(name, fdExp);
  }

  // local namelist [‘=’ explist]
   static LocalVarDeclStat finishLocalVarDeclStat(Lexer lexer) {
    String name0 = lexer.nextIdentifier().value;     // local Name
    List<String> nameList = finishNameList(lexer, name0); // { , Name }
    List<Exp>? expList;
    if (lexer.lookAhead() == TokenKind.opAssign) {
      lexer.nextToken();                                // ==
      expList = ExpParser.parseExpList(lexer);                    // explist
    }
    int lastLine = lexer.line;
    return LocalVarDeclStat(lastLine, nameList, expList ?? List<Exp>.empty());
  }

  // varlist ‘=’ explist
  // functioncall
   static Stat parseAssignOrFuncCallStat(Lexer lexer) {
    Exp prefixExp = PrefixExpParser.parsePrefixExp(lexer);
    if (prefixExp is FuncCallExp) {
      return FuncCallStat(prefixExp);
    } else {
      return parseAssignStat(lexer, prefixExp);
    }
  }

  // varlist ‘=’ explist |
   static AssignStat parseAssignStat(Lexer lexer, Exp var0) {
    List<Exp> varList = finishVarList(lexer, var0); // varlist
    lexer.nextTokenOfKind(TokenKind.opAssign);         // =
    List<Exp> expList = ExpParser.parseExpList(lexer);        // explist
    int lastLine = lexer.line;
    return AssignStat(lastLine, varList, expList);
  }

  // varlist ::= var {‘,’ var}
   static List<Exp> finishVarList(Lexer lexer, Exp var0) {
    List<Exp> vars = <Exp>[];
    vars.add(checkVar(lexer, var0));               // var
    while (lexer.lookAhead() == TokenKind.sepComma) { // {
      lexer.nextToken();                         // ,
      Exp exp = PrefixExpParser.parsePrefixExp(lexer);           // var
      vars.add(checkVar(lexer, exp));            //
    }                                              // }
    return vars;
  }

  // var ::=  Name | prefixexp ‘[’ exp ‘]’ | prefixexp ‘.’ Name
   static Exp checkVar(Lexer lexer, Exp exp) {
    if (exp is NameExp || exp is TableAccessExp) {
      return exp;
    }
    lexer.nextTokenOfKind(null); // trigger error
    throw Exception("unreachable!");
  }

  // function funcname funcbody
  // funcname ::= Name {‘.’ Name} [‘:’ Name]
  // funcbody ::= ‘(’ [parlist] ‘)’ block end
  // parlist ::= namelist [‘,’ ‘...’] | ‘...’
  // namelist ::= Name {‘,’ Name}
   static AssignStat parseFuncDefStat(Lexer lexer) {
    lexer.nextTokenOfKind(TokenKind.kwFunction);     // function
    Map<Exp, bool> map = parseFuncName(lexer); // funcname
    Exp fnExp = map.keys.first;
    bool hasColon = map.values.first;
    FuncDefExp fdExp = ExpParser.parseFuncDefExp(lexer);    // funcbody
    if (hasColon) { // insert self
      fdExp.parList.insert(0, "self");
    }

    return AssignStat(fdExp.lastLine, <Exp>[fnExp], <Exp>[fdExp]);
  }

  // funcname ::= Name {‘.’ Name} [‘:’ Name]
   static Map<Exp, bool> parseFuncName(Lexer lexer) {
    Token id = lexer.nextIdentifier();
    Exp exp = NameExp(id.line, id.value);
    bool hasColon = false;

    while (lexer.lookAhead() == TokenKind.sepDot) {
      lexer.nextToken();
      id = lexer.nextIdentifier();
      Exp idx = StringExp.fromToken(id);
      exp = TableAccessExp(id.line, exp, idx);
    }
    if (lexer.lookAhead() == TokenKind.sepColon) {
      lexer.nextToken();
      id = lexer.nextIdentifier();
      Exp idx = StringExp.fromToken(id);
      exp = TableAccessExp(id.line, exp, idx);
      hasColon = true;
    }

    // workaround: return multiple values
    return {}..[exp] = hasColon;
  }

}