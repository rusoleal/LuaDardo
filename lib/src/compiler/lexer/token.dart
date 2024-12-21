enum TokenKind {
  eof         , // end-of-file
  vararg     , // ...
  sepSemi   , // ;
  sepComma  , // ,
  sepDot    , // .
  sepColon  , // :
  sepLabel  , // ::
  sepLParen , // (
  sepRParen , // )
  sepLBrack , // [
  sepRBrack , // ]
  sepLCurly , // {
  sepRCurly , // }
  opAssign  , // =
  opMinus   , // - (sub or unm)
  opWave    , // ~ (bnot or bxor)
  opAdd     , // +
  opMul     , // *
  opDiv     , // /
  opIDiv    , // //
  opPow     , // ^
  opMod     , // %
  opBand    , // &
  opBor     , // |
  opShr     , // >>
  opShl     , // <<
  opConcat  , // ..
  opLt      , // <
  opLe      , // <=
  opGt      , // >
  opGe      , // >=
  opEq      , // ==
  opNe      , // ~=
  opLen     , // #
  opAnd     , // and
  opOr      , // or
  opNot     , // not
  kwBreak   , // break
  kwDo      , // do
  kwElse    , // else
  kwElseif  , // elseif
  kwEnd     , // end
  kwFalse   , // false
  kwFor     , // for
  kwFunction, // function
  kwGoto    , // goto
  kwIf      , // if
  kwIn      , // in
  kwLocal   , // local
  kwNil     , // nil
  kwRepeat  , // repeat
  kwReturn  , // return
  kwThen    , // then
  kwTrue    , // true
  kwUntil   , // until
  kwWhile   , // while
  identifier , // identifier
  number     , // number literal
  string     , // string literal
  opUnm     , // = TOKEN_OP_MINUS // unary minus
  opSub     , // = TOKEN_OP_MINUS
  opBNot    , // = TOKEN_OP_WAVE
  opBXor    , // = TOKEN_OP_WAVE
}


const Map keywords = <String, TokenKind>{
  "and": TokenKind.opAnd,
  "break": TokenKind.kwBreak,
  "do": TokenKind.kwDo,
  "else": TokenKind.kwElse,
  "elseif": TokenKind.kwElseif,
  "end": TokenKind.kwEnd,
  "false": TokenKind.kwFalse,
  "for": TokenKind.kwFor,
  "function": TokenKind.kwFunction,
  "goto": TokenKind.kwGoto,
  "if": TokenKind.kwIf,
  "in": TokenKind.kwIn,
  "local": TokenKind.kwLocal,
  "nil": TokenKind.kwNil,
  "not": TokenKind.opNot,
  "or": TokenKind.opOr,
  "repeat": TokenKind.kwRepeat,
  "return": TokenKind.kwReturn,
  "then": TokenKind.kwThen,
  "true": TokenKind.kwTrue,
  "until": TokenKind.kwUntil,
  "while": TokenKind.kwWhile,
};



class Token {

 final int line;
 final TokenKind kind;
 final String value;

 Token(this.line, this.kind, this.value);

}