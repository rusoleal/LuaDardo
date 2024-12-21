
import '../api/lua_vm.dart';
import 'instructions.dart';

typedef OpAction = void Function(int i, LuaVM vm);

enum OpMode {
  iABC, // [  B:9  ][  C:9  ][ A:8  ][OP:6]
  iABx, // [      Bx:18     ][ A:8  ][OP:6]
  iAsBx, // [     sBx:18     ][ A:8  ][OP:6]
  iAx, // [           Ax:26        ][OP:6]
}

enum OpArgMask {
  opArgN, // argument is not used
  opArgU, // argument is used
  opArgR, // argument is a register or a jump offset
  opArgK, // argument is a constant or register/constant
}

enum OpCodeKind {
  move,
  loadK,
  loadKx,
  loadBool,
  loadNil,
  getUpVal,
  getTabUp,
  getTable,
  setTabUp,
  setUpVal,
  setTable,
  newTable,
  self,
  add,
  sub,
  mul,
  mod,
  pow,
  div,
  idiv,
  band,
  bOr,
  bXor,
  shl,
  shr,
  unm,
  bNot,
  not,
  len,
  concat,
  jmp,
  eq,
  lt,
  le,
  test,
  testSet,
  call,
  tailCall,
  opReturn,
  forLoop,
  forPrep,
  tForCall,
  tForLoop,
  setList,
  closure,
  varArg,
  extraArg,
}

class OpCode {
  final int testFlag; // operator is a test (next instruction must be a jump)
  final int setAFlag; // instruction set register A
  final OpArgMask argBMode; // B arg mode
  final OpArgMask argCMode; // C arg mode
  final OpMode opMode; // op mode
  final String name;
  final OpAction? action;

  const OpCode(this.testFlag, this.setAFlag, this.argBMode, this.argCMode,
      this.opMode, this.name, this.action);
}

/// Instruction List
const opCodes = <OpCode>[
  /*     T  A    B       C     mode         name    */
  OpCode(0, 1, OpArgMask.opArgR, OpArgMask.opArgN, OpMode.iABC , "MOVE",Instructions.move), // R(A) := R(B)
  OpCode(0, 1, OpArgMask.opArgK, OpArgMask.opArgN, OpMode.iABx , "LOADK",Instructions.loadK), // R(A) := Kst(Bx)
  OpCode(0, 1, OpArgMask.opArgN, OpArgMask.opArgN, OpMode.iABx , "LOADKX",Instructions.loadKx), // R(A) := Kst(extra arg)
  OpCode(0, 1, OpArgMask.opArgU, OpArgMask.opArgU, OpMode.iABC , "LOADBOOL",Instructions.loadBool), // R(A) := (bool)B; if (C) pc++
  OpCode(0, 1, OpArgMask.opArgU, OpArgMask.opArgN, OpMode.iABC , "LOADNIL",Instructions.loadNil), // R(A), R(A+1), ..., R(A+B) := nil
  OpCode(0, 1, OpArgMask.opArgU, OpArgMask.opArgN, OpMode.iABC , "GETUPVAL",Instructions.getUpval), // R(A) := UpValue[B]
  OpCode(0, 1, OpArgMask.opArgU, OpArgMask.opArgK, OpMode.iABC , "GETTABUP",Instructions.getTabUp), // R(A) := UpValue[B][RK(C)]
  OpCode(0, 1, OpArgMask.opArgR, OpArgMask.opArgK, OpMode.iABC , "GETTABLE",Instructions.getTable), // R(A) := R(B)[RK(C)]
  OpCode(0, 0, OpArgMask.opArgK, OpArgMask.opArgK, OpMode.iABC , "SETTABUP",Instructions.setTabUp), // UpValue[A][RK(B)] := RK(C)
  OpCode(0, 0, OpArgMask.opArgU, OpArgMask.opArgN, OpMode.iABC , "SETUPVAL",Instructions.setUpval), // UpValue[B] := R(A)
  OpCode(0, 0, OpArgMask.opArgK, OpArgMask.opArgK, OpMode.iABC , "SETTABLE",Instructions.setTable), // R(A)[RK(B)] := RK(C)
  OpCode(0, 1, OpArgMask.opArgU, OpArgMask.opArgU, OpMode.iABC , "NEWTABLE",Instructions.newTable), // R(A) := () (size = B,C)
  OpCode(0, 1, OpArgMask.opArgR, OpArgMask.opArgK, OpMode.iABC , "SELF",Instructions.self), // R(A+1) := R(B); R(A) := R(B)[RK(C)]
  OpCode(0, 1, OpArgMask.opArgK, OpArgMask.opArgK, OpMode.iABC , "ADD",Instructions.add), // R(A) := RK(B) + RK(C)
  OpCode(0, 1, OpArgMask.opArgK, OpArgMask.opArgK, OpMode.iABC , "SUB",Instructions.sub), // R(A) := RK(B) - RK(C)
  OpCode(0, 1, OpArgMask.opArgK, OpArgMask.opArgK, OpMode.iABC , "MUL",Instructions.mul), // R(A) := RK(B) * RK(C)
  OpCode(0, 1, OpArgMask.opArgK, OpArgMask.opArgK, OpMode.iABC , "MOD",Instructions.mod), // R(A) := RK(B) % RK(C)
  OpCode(0, 1, OpArgMask.opArgK, OpArgMask.opArgK, OpMode.iABC , "POW",Instructions.pow), // R(A) := RK(B) ^ RK(C)
  OpCode(0, 1, OpArgMask.opArgK, OpArgMask.opArgK, OpMode.iABC , "DIV",Instructions.div), // R(A) := RK(B) / RK(C)
  OpCode(0, 1, OpArgMask.opArgK, OpArgMask.opArgK, OpMode.iABC , "IDIV",Instructions.idiv), // R(A) := RK(B) // RK(C)
  OpCode(0, 1, OpArgMask.opArgK, OpArgMask.opArgK, OpMode.iABC , "BAND",Instructions.band), // R(A) := RK(B) & RK(C)
  OpCode(0, 1, OpArgMask.opArgK, OpArgMask.opArgK, OpMode.iABC , "BOR",Instructions.bor), // R(A) := RK(B) | RK(C)
  OpCode(0, 1, OpArgMask.opArgK, OpArgMask.opArgK, OpMode.iABC , "BXOR",Instructions.bxor), // R(A) := RK(B) ~ RK(C)
  OpCode(0, 1, OpArgMask.opArgK, OpArgMask.opArgK, OpMode.iABC , "SHL",Instructions.shl), // R(A) := RK(B) << RK(C)
  OpCode(0, 1, OpArgMask.opArgK, OpArgMask.opArgK, OpMode.iABC , "SHR",Instructions.shr), // R(A) := RK(B) >> RK(C)
  OpCode(0, 1, OpArgMask.opArgR, OpArgMask.opArgN, OpMode.iABC , "UNM",Instructions.unm), // R(A) := -R(B)
  OpCode(0, 1, OpArgMask.opArgR, OpArgMask.opArgN, OpMode.iABC , "BNOT",Instructions.bnot), // R(A) := ~R(B)
  OpCode(0, 1, OpArgMask.opArgR, OpArgMask.opArgN, OpMode.iABC , "NOT",Instructions.not), // R(A) := not R(B)
  OpCode(0, 1, OpArgMask.opArgR, OpArgMask.opArgN, OpMode.iABC , "LEN",Instructions.length), // R(A) := length of R(B)
  OpCode(0, 1, OpArgMask.opArgR, OpArgMask.opArgR, OpMode.iABC , "CONCAT",Instructions.concat), // R(A) := R(B).. ... ..R(C)
  OpCode(0, 0, OpArgMask.opArgR, OpArgMask.opArgN, OpMode.iAsBx , "JMP",Instructions.jmp), // pc+=sBx; if (A) close all upvalues >= R(A - 1)
  OpCode(1, 0, OpArgMask.opArgK, OpArgMask.opArgK, OpMode.iABC , "EQ",Instructions.eq), // if ((RK(B) == RK(C)) ~= A) then pc++
  OpCode(1, 0, OpArgMask.opArgK, OpArgMask.opArgK, OpMode.iABC , "LT",Instructions.lt), // if ((RK(B) <  RK(C)) ~= A) then pc++
  OpCode(1, 0, OpArgMask.opArgK, OpArgMask.opArgK, OpMode.iABC , "LE",Instructions.le), // if ((RK(B) <= RK(C)) ~= A) then pc++
  OpCode(1, 0, OpArgMask.opArgN, OpArgMask.opArgU, OpMode.iABC , "TEST",Instructions.test), // if not (R(A) <=> C) then pc++
  OpCode(1, 1, OpArgMask.opArgR, OpArgMask.opArgU, OpMode.iABC , "TESTSET",Instructions.testSet), // if (R(B) <=> C) then R(A) := R(B) else pc++
  OpCode(0, 1, OpArgMask.opArgU, OpArgMask.opArgU, OpMode.iABC , "CALL",Instructions.call), // R(A), ... ,R(A+C-2) := R(A)(R(A+1), ... ,R(A+B-1))
  OpCode(0, 1, OpArgMask.opArgU, OpArgMask.opArgU, OpMode.iABC , "TAILCALL",Instructions.tailCall), // return R(A)(R(A+1), ... ,R(A+B-1))
  OpCode(0, 0, OpArgMask.opArgU, OpArgMask.opArgN, OpMode.iABC , "RETURN",Instructions.return_), // return R(A), ... ,R(A+B-2)
  OpCode(0, 1, OpArgMask.opArgR, OpArgMask.opArgN, OpMode.iAsBx , "FORLOOP",Instructions.forLoop), // R(A)+=R(A+2); if R(A) <?= R(A+1) then ( pc+=sBx; R(A+3)=R(A) )
  OpCode(0, 1, OpArgMask.opArgR, OpArgMask.opArgN, OpMode.iAsBx , "FORPREP",Instructions.forPrep), // R(A)-=R(A+2); pc+=sBx
  OpCode(0, 0, OpArgMask.opArgN, OpArgMask.opArgU, OpMode.iABC , "TFORCALL",Instructions.tForCall), // R(A+3), ... ,R(A+2+C) := R(A)(R(A+1), R(A+2));
  OpCode(0, 1, OpArgMask.opArgR, OpArgMask.opArgN, OpMode.iAsBx , "TFORLOOP",Instructions.tForLoop), // if R(A+1) ~= nil then ( R(A)=R(A+1); pc += sBx )
  OpCode(0, 0, OpArgMask.opArgU, OpArgMask.opArgU, OpMode.iABC , "SETLIST",Instructions.setList), // R(A)[(C-1)*FPF+i] := R(A+i), 1 <= i <= B
  OpCode(0, 1, OpArgMask.opArgU, OpArgMask.opArgN, OpMode.iABx , "CLOSURE",Instructions.closure), // R(A) := closure(KPROTO[Bx])
  OpCode(0, 1, OpArgMask.opArgU, OpArgMask.opArgN, OpMode.iABC , "VARARG",Instructions.vararg), // R(A), R(A+1), ..., R(A+B-2) = vararg
  OpCode(0, 0, OpArgMask.opArgU, OpArgMask.opArgU, OpMode.iAx , "EXTRAARG",null), // extra (larger) argument for previous opcode
];