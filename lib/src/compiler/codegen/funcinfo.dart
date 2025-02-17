import '../../number/lua_math.dart';
import '../../vm/fpb.dart';
import '../../vm/opcodes.dart';
import '../ast/exp.dart';
import '../lexer/token.dart';
import '../../vm/instruction.dart';

class UpvalInfo {
  int locVarSlot;
  int upvalIndex;
  int index;

  UpvalInfo(this.index,this.upvalIndex,this.locVarSlot);
}

class LocVarInfo {
  LocVarInfo? prev;
  String name;
  int scopeLv;
  int slot;
  int startPC;
  int endPC;
  bool captured = false;

  LocVarInfo(this.prev,this.name,this.slot,this.scopeLv,this.startPC,this.endPC);
}

class FuncInfo {
  static final Map<TokenKind, OpCodeKind> arithAndBitwiseBinops =
      <TokenKind, OpCodeKind>{
    TokenKind.opAdd: OpCodeKind.add,
    TokenKind.opSub: OpCodeKind.sub,
    TokenKind.opMul: OpCodeKind.mul,
    TokenKind.opMod: OpCodeKind.mod,
    TokenKind.opPow: OpCodeKind.pow,
    TokenKind.opDiv: OpCodeKind.div,
    TokenKind.opIDiv: OpCodeKind.idiv,
    TokenKind.opBand: OpCodeKind.band,
    TokenKind.opBor: OpCodeKind.bOr,
    TokenKind.opBXor: OpCodeKind.bXor,
    TokenKind.opShl: OpCodeKind.shl,
    TokenKind.opShr: OpCodeKind.shr,
  };

  FuncInfo? parent;
  List<FuncInfo> subFuncs = <FuncInfo>[];
  int usedRegs = 0;
  int maxRegs = 0;
  int scopeLv = 0;
  List<LocVarInfo> locVars = <LocVarInfo>[];
  Map<String?, LocVarInfo?> locNames = {};
  Map<String?, UpvalInfo> upvalues = {};
  Map<Object?, int> constants = {};
  List<List<int>?> breaks = <List<int>?>[];
  List<int> insts = <int>[];
  List<int> lineNums = <int>[];
  int? line;
  int? lastLine;
  int? numParams;
  bool? isVararg;

  FuncInfo(this.parent, FuncDefExp fd) {
    line = fd.line;
    lastLine = fd.lastLine;
    numParams = fd.parList.length;
    isVararg = fd.isVararg;
    breaks.add(null);
  }

/* constants */

  int indexOfConstant(Object? k) {
    int? idx = constants[k];
    if (idx != null) {
      return idx;
    }

    idx = constants.length;
    constants[k] = idx;
    return idx;
  }

/* registers */

  int allocReg() {
    usedRegs++;
    if (usedRegs >= 255) {
      throw Exception("function or expression needs too many registers");
    }
    if (usedRegs > maxRegs) {
      maxRegs = usedRegs;
    }
    return usedRegs - 1;
  }

  void freeReg() {
    if (usedRegs <= 0) {
      throw Exception("usedRegs <= 0 !");
    }
    usedRegs--;
  }

  int allocRegs(int n) {
    if (n <= 0) {
      throw Exception("n <= 0 !");
    }
    for (int i = 0; i < n; i++) {
      allocReg();
    }
    return usedRegs - n;
  }

  void freeRegs(int n) {
    if (n < 0) {
      throw Exception("n < 0 !");
    }
    for (int i = 0; i < n; i++) {
      freeReg();
    }
  }

/* lexical scope */

  void enterScope(bool breakable) {
    scopeLv++;
    if (breakable) {
      breaks.add(<int>[]);
    } else {
      breaks.add(null);
    }
  }

  void exitScope(int endPC) {
    List<int>? pendingBreakJmps = breaks.removeAt(breaks.length - 1);

    if (pendingBreakJmps != null) {
      int a = getJmpArgA();
      for (int pcValue in pendingBreakJmps) {
        int sBx = pc() - pcValue;
        int i = LuaMath.toInt32((sBx + Instruction.maxArgSbx) << 14) | 
        LuaMath.toInt32(a << 6) | 
        OpCodeKind.jmp.index;
        insts[pcValue] = i;
      }
    }
    
    scopeLv--;
    Map<String?, LocVarInfo?> tmp = Map.from(locNames);
    for (LocVarInfo? locVar in tmp.values) {
      if (locVar!.scopeLv> scopeLv) {
        // out of scope
        locVar.endPC = endPC;
        removeLocVar(locVar);
      }
    }
  }

  void removeLocVar(LocVarInfo locVar) {
    freeReg();
    if (locVar.prev == null) {
      locNames.remove(locVar.name);
    } else if (locVar.prev!.scopeLv == locVar.scopeLv) {
      removeLocVar(locVar.prev!);
    } else {
      locNames[locVar.name] = locVar.prev;
    }
  }

  int addLocVar(String name, int startPC) {
    LocVarInfo newVar = LocVarInfo(locNames[name],name,allocReg(),scopeLv,startPC,0);
    // newVar.name = name;
    // newVar.prev = locNames[name];
    // newVar.scopeLv = scopeLv;
    // newVar.slot = allocReg();
    // newVar.startPC = startPC;
    // newVar.endPC = 0;

    locVars.add(newVar);
    locNames[name] = newVar;

    return newVar.slot;
  }

  int? slotOfLocVar(String? name) {
    return locNames.containsKey(name) ? locNames[name]!.slot : -1;
  }

  void addBreakJmp(int pc) {
    for (int i = scopeLv; i >= 0; i--) {
      if (breaks[i] != null) {
        // breakable
        breaks[i]!.add(pc);
        return;
      }
    }

    throw Exception("<break> at line ? not inside a loop!");
  }

/* upvalues */

  int indexOfUpval(String? name) {
    if (upvalues.containsKey(name)) {
      return upvalues[name]!.index;
    }
    if (parent != null) {
      if (parent!.locNames.containsKey(name)) {
        LocVarInfo locVar = parent!.locNames[name]!;
        int idx = upvalues.length;
        UpvalInfo upval = UpvalInfo(idx,-1,locVar.slot);
        // upval.locVarSlot = locVar.slot;
        // upval.upvalIndex = -1;
        // upval.index = idx;
        upvalues[name] = upval;
        locVar.captured = true;
        return idx;
      }
      int uvIdx = parent!.indexOfUpval(name);
      if (uvIdx >= 0) {
        int idx = upvalues.length;
        UpvalInfo upval = UpvalInfo(idx,uvIdx,-1);
        // upval.locVarSlot = -1;
        // upval.upvalIndex = uvIdx;
        // upval.index = idx;
        upvalues[name] = upval;
        return idx;
      }
    }
    return -1;
  }

  void closeOpenUpvals(int line) {
    int a = getJmpArgA();
    if (a > 0) {
      emitJmp(line, a, 0);
    }
  }

  int getJmpArgA() {
    bool hasCapturedLocVars = false;
    int? minSlotOfLocVars = maxRegs;
    for (LocVarInfo? locVar in locNames.values) {
      if (locVar!.scopeLv == scopeLv) {
        for (LocVarInfo? v = locVar;
            v != null && v.scopeLv == scopeLv;
            v = v.prev) {
          if (v.captured) {
            hasCapturedLocVars = true;
          }
          if (v.slot< minSlotOfLocVars! && v.name[0] != '(') {
            minSlotOfLocVars = v.slot;
          }
        }
      }
    }
    if (hasCapturedLocVars) {
      return minSlotOfLocVars! + 1;
    } else {
      return 0;
    }
  }

/* code */

  int pc() {
    return insts.length - 1;
  }

  void fixSbx(int pc, int sBx) {
    int i = insts[pc];
    i = LuaMath.toInt32(i << 18) >> 18; // clear sBx
    i = i | LuaMath.toInt32((sBx + Instruction.maxArgSbx) << 14); // reset sBx
    insts[pc] = i;
  }

// todo: rename?
  void fixEndPC(String name, int delta) {
    for (int i = locVars.length - 1; i >= 0; i--) {
      LocVarInfo locVar = locVars[i];
      if (locVar.name != name) {
        locVar.endPC = delta + locVar.endPC;
        return;
      }
    }
  }

  void emitABC(int line, OpCodeKind opcode, int a, int b, int c) {
    int i = b << 23 | c << 14 | a << 6 | opcode.index;
    insts.add(i);
    lineNums.add(line);
  }

  void emitABx(int line, OpCodeKind opcode, int a, int bx) {
    int i = bx << 14 | a << 6 | opcode.index;
    insts.add(i);
    lineNums.add(line);
  }

  void emitAsBx(int line, OpCodeKind opcode, int a, int sBx) {
    int i = LuaMath.toInt32((sBx + Instruction.maxArgSbx) << 14) |
    a << 6 | opcode.index;
    insts.add(i);
    lineNums.add(line);
  }

  void emitAx(int line, OpCodeKind opcode, int ax) {
    int i = ax << 6 | opcode.index;
    insts.add(i);
    lineNums.add(line);
  }

// r[a] = r[b]
  void emitMove(int line, int a, int b) {
    emitABC(line, OpCodeKind.move, a, b, 0);
  }

// r[a], r[a+1], ..., r[a+b] = nil
  void emitLoadNil(int line, int a, int n) {
    emitABC(line, OpCodeKind.loadNil, a, n - 1, 0);
  }

// r[a] = (bool)b; if (c) pc++
  void emitLoadBool(int line, int a, int b, int c) {
    emitABC(line, OpCodeKind.loadBool, a, b, c);
  }

// r[a] = kst[bx]
  void emitLoadK(int line, int? a, Object? k) {
    int idx = indexOfConstant(k);
    if (idx < (1 << 18)) {
      emitABx(line, OpCodeKind.loadK, a!, idx);
    } else {
      emitABx(line, OpCodeKind.loadKx, a!, 0);
      emitAx(line, OpCodeKind.extraArg, idx);
    }
  }

// r[a], r[a+1], ..., r[a+b-2] = vararg
  void emitVararg(int line, int a, int n) {
    emitABC(line, OpCodeKind.varArg, a, n + 1, 0);
  }

// r[a] = emitClosure(proto[bx])
  void emitClosure(int line, int a, int bx) {
    emitABx(line, OpCodeKind.closure, a, bx);
  }

// r[a] = {}
  void emitNewTable(int line, int a, int nArr, int nRec) {
    emitABC(line, OpCodeKind.newTable, a, FPB.int2fb(nArr), FPB.int2fb(nRec));
  }

// r[a][(c-1)*FPF+i] = r[a+i], 1 <= i <= b
  void emitSetList(int line, int a, int b, int c) {
    emitABC(line, OpCodeKind.setList, a, b, c);
  }

// r[a] = r[b][rk(c)]
  void emitGetTable(int line, int a, int b, int c) {
    emitABC(line, OpCodeKind.getTable, a, b, c);
  }

// r[a][rk(b)] = rk(c)
  void emitSetTable(int line, int a, int b, int c) {
    emitABC(line, OpCodeKind.setTable, a, b, c);
  }

// r[a] = upval[b]
  void emitGetUpval(int line, int a, int b) {
    emitABC(line, OpCodeKind.getUpVal, a, b, 0);
  }

// upval[b] = r[a]
  void emitSetUpval(int line, int a, int b) {
    emitABC(line, OpCodeKind.setUpVal, a, b, 0);
  }

// r[a] = upval[b][rk(c)]
  void emitGetTabUp(int line, int a, int b, int c) {
    emitABC(line, OpCodeKind.getTabUp, a, b, c);
  }

// upval[a][rk(b)] = rk(c)
  void emitSetTabUp(int line, int a, int b, int c) {
    emitABC(line, OpCodeKind.setTabUp, a, b, c);
  }

// r[a], ..., r[a+c-2] = r[a](r[a+1], ..., r[a+b-1])
  void emitCall(int line, int a, int nArgs, int nRet) {
    emitABC(line, OpCodeKind.call, a, nArgs + 1, nRet + 1);
  }

// return r[a](r[a+1], ... ,r[a+b-1])
  void emitTailCall(int line, int a, int nArgs) {
    emitABC(line, OpCodeKind.tailCall, a, nArgs + 1, 0);
  }

// return r[a], ... ,r[a+b-2]
  void emitReturn(int line, int a, int n) {
    emitABC(line, OpCodeKind.opReturn, a, n + 1, 0);
  }

// r[a+1] = r[b]; r[a] = r[b][rk(c)]
  void emitSelf(int line, int a, int b, int c) {
    emitABC(line, OpCodeKind.self, a, b, c);
  }

// pc+=sBx; if (a) close all upvalues >= r[a - 1]
  int emitJmp(int line, int a, int sBx) {
    emitAsBx(line, OpCodeKind.jmp, a, sBx);
    return insts.length - 1;
  }

// if not (r[a] <=> c) then pc++
  void emitTest(int line, int a, int c) {
    emitABC(line, OpCodeKind.test, a, 0, c);
  }

// if (r[b] <=> c) then r[a] = r[b] else pc++
  void emitTestSet(int line, int a, int b, int c) {
    emitABC(line, OpCodeKind.testSet, a, b, c);
  }

  int emitForPrep(int line, int a, int sBx) {
    emitAsBx(line, OpCodeKind.forPrep, a, sBx);
    return insts.length - 1;
  }

  int emitForLoop(int line, int a, int sBx) {
    emitAsBx(line, OpCodeKind.forLoop, a, sBx);
    return insts.length - 1;
  }

  void emitTForCall(int line, int a, int c) {
    emitABC(line, OpCodeKind.tForCall, a, 0, c);
  }

  void emitTForLoop(int line, int a, int sBx) {
    emitAsBx(line, OpCodeKind.tForLoop, a, sBx);
  }

// r[a] = op r[b]
  void emitUnaryOp(int line, TokenKind op, int? a, int? b) {
    switch (op) {
      case TokenKind.opNot:
        emitABC(line, OpCodeKind.not, a!, b!, 0);
        break;
      case TokenKind.opBNot:
        emitABC(line, OpCodeKind.bNot, a!, b!, 0);
        break;
      case TokenKind.opLen:
        emitABC(line, OpCodeKind.len, a!, b!, 0);
        break;
      case TokenKind.opUnm:
        emitABC(line, OpCodeKind.unm, a!, b!, 0);
        break;
      default:
    }
  }

// r[a] = rk[b] op rk[c]
// arith & bitwise & relational
  void emitBinaryOp(int line, TokenKind op, int? a, int? b, int? c) {
    if (arithAndBitwiseBinops.containsKey(op)) {
      emitABC(line, arithAndBitwiseBinops[op]!, a!, b!, c!);
    } else {
      switch (op) {
        case TokenKind.opEq:
          emitABC(line, OpCodeKind.eq, 1, b!, c!);
          break;
        case TokenKind.opNe:
          emitABC(line, OpCodeKind.eq, 0, b!, c!);
          break;
        case TokenKind.opLt:
          emitABC(line, OpCodeKind.lt, 1, b!, c!);
          break;
        case TokenKind.opGt:
          emitABC(line, OpCodeKind.lt, 1, c!, b!);
          break;
        case TokenKind.opLe:
          emitABC(line, OpCodeKind.le, 1, b!, c!);
          break;
        case TokenKind.opGe:
          emitABC(line, OpCodeKind.le, 1, c!, b!);
          break;
        default:
      }
      emitJmp(line, 0, 1);
      emitLoadBool(line, a!, 0, 1);
      emitLoadBool(line, a, 1, 0);
    }
  }
}
