import '../ast/block.dart';
import '../ast/exp.dart';
import '../ast/stat.dart';
import '../lexer/lexer.dart';
import '../lexer/token.dart';
import 'exp_parser.dart';
import 'stat_parser.dart';

class BlockParser {

  // block ::= {stat} [retstat]
  static Block parseBlock(Lexer lexer) {
    Block block = Block(stats: parseStats(lexer), retExps: parseRetExps(lexer));
    block.lastLine = lexer.line;
    return block;
  }

  static List<Stat> parseStats(Lexer lexer) {
    List<Stat> stats = <Stat>[];
    while (!_isReturnOrBlockEnd(lexer.lookAhead())) {
      Stat stat = StatParser.parseStat(lexer);
      if (stat is! EmptyStat) {
        stats.add(stat);
      }
    }
    return stats;
  }

   static bool _isReturnOrBlockEnd(TokenKind? kind) {
    switch (kind) {
      case TokenKind.kwReturn:
      case TokenKind.eof:
      case TokenKind.kwEnd:
      case TokenKind.kwElse:
      case TokenKind.kwElseif:
      case TokenKind.kwUntil:
        return true;
      default:
        return false;
    }
  }

  // retstat ::= return [explist] [‘;’]
  // explist ::= exp {‘,’ exp}
   static List<Exp> parseRetExps(Lexer lexer) {
    if (lexer.lookAhead() != TokenKind.kwReturn) {
      return List.empty();
    }

    lexer.nextToken();
    switch (lexer.lookAhead()) {
      case TokenKind.eof:
      case TokenKind.kwEnd:
      case TokenKind.kwElse:
      case TokenKind.kwElseif:
      case TokenKind.kwUntil:
        return const <Exp>[];
      case TokenKind.sepSemi:
        lexer.nextToken();
        return const <Exp>[];
      default:
        List<Exp> exps = ExpParser.parseExpList(lexer);
        if (lexer.lookAhead() == TokenKind.sepSemi) {
          lexer.nextToken();
        }
        return exps;
    }
  }

}