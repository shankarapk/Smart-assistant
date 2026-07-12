import '../../core/constants/tamil_strings.dart';

enum Store { zepto, blinkit, instamart, bigbasket }

extension StoreX on Store {
  String get label {
    switch (this) {
      case Store.zepto:
        return TS.zepto;
      case Store.blinkit:
        return TS.blinkit;
      case Store.instamart:
        return TS.instamart;
      case Store.bigbasket:
        return TS.bigbasket;
    }
  }

  String get key => toString().split('.').last;

  static Store fromKey(String key) =>
      Store.values.firstWhere((s) => s.key == key, orElse: () => Store.zepto);
}
