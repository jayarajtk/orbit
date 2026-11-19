import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Current time, injectable so time-based rules can be tested.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
