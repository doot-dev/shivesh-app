import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/client_api_provider.dart';
import '../data/models/user_profile.dart';

final userProfileProvider = FutureProvider<UserProfile>((ref) {
  return ref.read(clientApiProvider).getProfile();
});
