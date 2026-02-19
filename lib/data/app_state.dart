import 'package:flutter/material.dart';

import '../models/church.dart';
import '../models/feast.dart';
import '../models/user.dart';
import 'mock_data.dart';

class AppState extends ChangeNotifier {
  AppState() : _user = User.demo();

  User? _user;
  String? _previousRoute;

  User? get user => _user;
  String? get previousRoute => _previousRoute;

  bool get isDemoUser => _user?.tier == UserTier.demo;
  bool get isNormalUser => _user?.tier == UserTier.normal;
  bool get isFamiliarUser => _user?.tier == UserTier.familiar;
  bool get hasPaidAccess => isNormalUser || isFamiliarUser;

  void setUser(User user) {
    _user = user;
    notifyListeners();
  }

  void clearUser() {
    _user = null;
    notifyListeners();
  }

  void switchToDemo() {
    _user = User.demo();
    notifyListeners();
  }

  void setPreviousRoute(String? route) {
    _previousRoute = route;
    notifyListeners();
  }

  List<Feast> get todaysFeasts => List<Feast>.unmodifiable(mockFeasts);

  List<Church> get nearbyChurches => mockChurches
      .where((church) => church.distance <= 3)
      .toList(growable: false);

  List<Feast> visibleFeasts() {
    if (!isDemoUser) return todaysFeasts;
    return todaysFeasts.take(1).toList();
  }

  List<Church> visibleChurches() {
    if (!isDemoUser) return nearbyChurches;
    return nearbyChurches.take(2).toList();
  }

  Feast feastById(String id) =>
      todaysFeasts.firstWhere((feast) => feast.id == id);

  Church churchById(String id) =>
      nearbyChurches.firstWhere((church) => church.id == id);

  List<Church> churchesForFeast(Feast feast) => feast.churches
      .map((id) => mockChurches.firstWhere((church) => church.id == id))
      .toList();

  List<Feast> feastsForChurch(Church church) => church.feasts
      .map((id) => mockFeasts.firstWhere((feast) => feast.id == id))
      .toList();
}
