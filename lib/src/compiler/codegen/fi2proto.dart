import 'dart:typed_data';

import '../../binchunk/binary_chunk.dart';
import 'funcinfo.dart';


class Fi2Proto {

  static Prototype toProto(FuncInfo fi) {
    Prototype proto = Prototype();
    proto.lineDefined = fi.line;
    proto.lastLineDefined = fi.lastLine;
    proto.numParams = fi.numParams;
    proto.maxStackSize = fi.maxRegs;
    proto.code = Uint32List.fromList(fi.insts);
    proto.constants = getConstants(fi);
    proto.upvalues = getUpvalues(fi);
    proto.protos = toProtos(fi.subFuncs);
    proto.lineInfo = Uint32List.fromList(fi.lineNums);
    proto.locVars = getLocVars(fi);
    proto.upvalueNames = getUpvalueNames(fi);

    if (fi.line == 0) {
      proto.lastLineDefined = 0;
    }
    if (proto.maxStackSize < 2) {
      proto.maxStackSize = 2; // todo
    }
    if (fi.isVararg!) {
      proto.isVararg = 1; // todo
    }

    return proto;
  }

  static List<Prototype> toProtos(List<FuncInfo> fis) {
    return fis.map(toProto).toList();
  }

  static List<Object?> getConstants(FuncInfo fi) {
    var consts = List<Object?>.filled(fi.constants.length, null);
    fi.constants.forEach((c, idx) => consts[idx] = c);
    return consts;
  }

  static List<LocVar> getLocVars(FuncInfo fi) {
    return fi.locVars.map((locVarInfo){
    LocVar varValue = LocVar();
    varValue.varName = locVarInfo.name;
    varValue.startPC = locVarInfo.startPC;
    varValue.endPC = locVarInfo.endPC;
    return varValue;
    }).toList();
  }

  static List<Upvalue?> getUpvalues(FuncInfo fi) {
    var upvals = List<Upvalue?>.filled(fi.upvalues.length, null);

    for (UpvalInfo uvInfo in fi.upvalues.values) {
      Upvalue upval = Upvalue();
      upvals[uvInfo.index] = upval;
      if (uvInfo.locVarSlot>= 0) { // instack
        upval.instack = 1;
        upval.idx = uvInfo.locVarSlot;
      } else {
        upval.instack = 0;
        upval.idx = uvInfo.upvalIndex;
      }
    }

    return upvals;
  }

  static List<String?> getUpvalueNames(FuncInfo fi) {
    var names = List<String?>.filled(fi.upvalues.length, null);
    fi.upvalues.forEach((name, uvInfo) => names[uvInfo.index] = name);
    return names;
  }

}