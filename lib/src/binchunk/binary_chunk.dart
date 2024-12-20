import 'dart:convert';
import 'dart:typed_data';

import 'buffer.dart';

const luaSignature = [0x1b,0x4c,0x75,0x61];
const luacVersion = 0x53;
const luacFormat = 0;
const luacData = [0x19, 0x93, 0x0d, 0x0a, 0x1a, 0x0a];
const cintSize = 4;
const csizetSize = 8;
const instructionSize = 4;
const luaIntegerSize = 8;
const luaNumberSize = 8;
const luacInt = 0x5678;
const luacNum = 370.5;

/// 常量类型
const tagNil = 0x00;
const tagBoolean = 0x01;
const tagNumber = 0x03;
const tagInteger = 0x13;
const tagShortStr = 0x04;
const tagLongStr = 0x14;

/*class _Header {
  /// 签名。二进制文件的魔数:0x1B4C7561
  Uint8List signature = Uint8List(4);

  /// 版本号。值为大版本号乘以16加小版本号
  int? version;

  /// 格式号
  int? format;

  /// 前两个字节是0x1993，是Lua 1.0发布的年份；
  /// 后四个字节依次是回车符（0x0D）、换行符（0x0A）、
  /// 替换符（0x1A）和另一个换行符
  Uint8List luacData = Uint8List(6);

  /// 分别记录cint、size_t、Lua虚拟机指令、
  /// Lua整数和Lua浮点数5种数据类型在二进制的字节长度
  int? cintSize;
  int? sizetSize;
  int? instructionSize;
  int? luaIntegerSize;
  int? luaNumberSize;

  /// 存放Lua整数值0x5678
  int? luacInt;

  /// 存放Lua浮点数370.5
  double? luacNum;
}*/

class Prototype {
  /// 源文件名
  String? source;

  /// 起始行号
  int? lineDefined;

  /// 终止行号
  int? lastLineDefined;

  /// 函数固定参数个数
  int? numParams;

  /// 是否有变长参数
  int? isVararg;

  /// 寄存器数量
  late int maxStackSize;

  /// 指令表
  late Uint32List code;

  /// 常量表
  late List<Object?> constants;

  /// Upvalue表
  late List<Upvalue?> upvalues;

  /// 子函数原型表
  late List<Prototype?> protos;

  /// 行号表
  late Uint32List lineInfo;

  /// 局部变量表
  late List<LocVar?> locVars;

  /// Upvalue名字列表
  late List<String?> upvalueNames;

  Prototype();

  Prototype.from(ByteDataReader data, String parentSource) {
    source = BinaryChunk.getLuaString(data);
    if (source!.isEmpty) {
      source = parentSource;
    }

    lineDefined = data.readUint32();
    lastLineDefined = data.readUint32();
    numParams = data.readUint8();
    isVararg = data.readUint8();
    maxStackSize = data.readUint8();
    var len = data.readUint32();

    code = Uint32List(len);
    for(var i = 0;i<len;i++){
      code[i] = data.readUint32();
    }

    len = data.readUint32();
    constants = List.filled(len, null);
    for (var i = 0; i < len; i++) {
      var kind = data.readUint8();
      switch (kind) {
        case tagNil:
          constants[i] = null;
          break;
        case tagBoolean:
          constants[i] = data.readUint8() != 0;
          break;
        case tagInteger:
          constants[i] = data.readUint64();
          break;
        case tagNumber:
          constants[i] = data.readFloat64();
          break;
        case tagShortStr:
        case tagLongStr:
          constants[i] = BinaryChunk.getLuaString(data);
          break;
        default:
          throw Exception("corrupted!");
      }
    }

    len = data.readUint32();
    upvalues = List.filled(len, null);
    for (var i = 0; i < len; i++) {
      upvalues[i] = Upvalue.from(data);
    }

    len = data.readUint32();
    protos = List.filled(len, null);
    for (var i = 0; i < len; i++) {
      protos[i] = Prototype.from(data, parentSource);
    }

    len = data.readUint32();
    lineInfo = Uint32List(len);
    for(var i = 0;i<len;i++){
      lineInfo[i] = data.readUint32();
    }

    len = data.readUint32();
    locVars = List.filled(len, null);
    for (var i = 0; i < len; i++) {
      locVars[i] = LocVar.from(data);
    }

    len = data.readUint32();

    upvalueNames = List.filled(len, null);
    for (var i = 0; i < len; i++) {
      upvalueNames[i] = BinaryChunk.getLuaString(data);
    }
  }
}

class Upvalue {
  int? instack;
  int? idx;

  Upvalue();

  Upvalue.from(ByteDataReader blob) {
    instack = blob.readUint8();
    idx = blob.readUint8();
  }
}

class LocVar {
  String? varName;
  int? startPC;
  int? endPC;

  LocVar();
  LocVar.from(ByteDataReader blob){
    varName = BinaryChunk.getLuaString(blob);
    startPC = blob.readUint32();
    endPC = blob.readUint32();
  }
}

class BinaryChunk {
  //_Header? header;

  /// 解析二进制
  static Prototype unDump(Uint8List data) {
    var byteReader = ByteDataReader(endian:Endian.little)
      ..add(data);
    _checkHead(byteReader);
    byteReader.readUint8();// 跳过 size_upvalues
    return Prototype.from(byteReader, "");
  }

  static void _checkHead(ByteDataReader blob) {
    var magicNum = blob.read(4);

    for (var i = 0; i < 4; i++) {
      if (luaSignature[i] != magicNum[i]) {
        throw Exception("not a precompiled chunk!");
      }
    }

    if (luacVersion != blob.readUint8()) {
      throw Exception("version mismatch!");
    }

    if (luacFormat != blob.readUint8()) {
      throw Exception("format mismatch!");
    }

    var data = blob.read(6);
    for (var i = 0; i < 6; i++) {
      if (data[i] != luacData[i]) {
        throw Exception("LUAC_DATA corrupted!");
      }
    }

    if (cintSize != blob.readUint8()) {
      throw Exception("int size mismatch!");
    }

    if (csizetSize != blob.readUint8()) {
      throw Exception("size_t size mismatch!");
    }

    if (instructionSize != blob.readUint8()) {
      throw Exception("instruction size mismatch!");
    }

    if (luaIntegerSize != blob.readUint8()) {
      throw Exception("lua_Integer size mismatch!");
    }

    if (luaNumberSize != blob.readUint8()) {
      throw Exception("lua_Number size mismatch!");
    }

    if (luacInt != blob.readUint64()) {
      throw Exception("endianness mismatch!");
    }

    if (luacNum != blob.readFloat64()) {
      throw Exception("float format mismatch!");
    }
  }

  static String getLuaString(ByteDataReader blob) {
    int size = blob.readUint8();
    if (size == 0) {
      return "";
    }
    if (size == 0xFF) {
      size = blob.readUint64(); // size_t
    }

    var strBytes = blob.read(size - 1);
    return utf8.decode(strBytes);
  }

  static bool isBinaryChunk(Uint8List data) {
    if (data.length < 4) {
      return false;
    }
    for (int i = 0; i < 4; i++) {
      if (data[i] != luaSignature[i]) {
        return false;
      }
    }
    return true;
  }
}
