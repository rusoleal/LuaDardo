
import 'lua_table.dart';

class Userdata<T>{

  final List<T?> _data = List.filled(1,null);
  LuaTable? metatable;

  T? get data => _data.first;

  set data(T? data)=> _data.first = data;

  bool hasMetafield(String fieldName) {
    return metatable != null && metatable!.get(fieldName) != null;
  }

}