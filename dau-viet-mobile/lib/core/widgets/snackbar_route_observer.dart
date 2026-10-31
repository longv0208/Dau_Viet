import 'package:flutter/material.dart';

final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
final snackBarRouteObserver = SnackBarRouteObserver(rootScaffoldMessengerKey);

/// Ẩn SnackBar khi đổi route — tránh thông báo đảo/học còn treo sang tab khác.
class SnackBarRouteObserver extends NavigatorObserver {
  SnackBarRouteObserver(this.messengerKey);

  final GlobalKey<ScaffoldMessengerState> messengerKey;

  void _dismiss() {
    messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..clearSnackBars();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _dismiss();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _dismiss();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _dismiss();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _dismiss();
}
