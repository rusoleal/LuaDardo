import '../api/lua_type.dart';
import '../binchunk/binary_chunk.dart';
import 'upvalue_holder.dart';

class Closure {

  final Prototype? proto;
  final DartFunction? dartFunc;
  final List<UpvalueHolder?> upvals;

  Closure(Prototype this.proto) :
        dartFunc = null,
        upvals = List<UpvalueHolder?>.filled(proto.upvalues.length,null);

  Closure.DartFunc(this.dartFunc, int nUpvals) :
        proto = null,
        upvals = List<UpvalueHolder?>.filled(nUpvals,null);

}