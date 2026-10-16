import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // run 用于启动Flutter UI，GuitarPalApp是整颗界面树的根。
  // ProviderScope 是Riverpod的状态管理容器，类似一个带自动刷新能力的依赖注入容器
  // const表示对象内容在编译时确定，可以减少不必要对象创建。提升性能。
  runApp(const ProviderScope(child: GuitarPalApp()));
}
