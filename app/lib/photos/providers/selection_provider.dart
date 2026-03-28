import 'package:flutter_riverpod/flutter_riverpod.dart';

final selectionModeProvider = StateProvider<bool>((ref) => false);
final selectedPhotoIdsProvider = StateProvider<Set<String>>((ref) => {});
