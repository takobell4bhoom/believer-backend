import '../models/mosque_model.dart';

class MosqueDetailRouteArgs {
  const MosqueDetailRouteArgs({
    required this.mosqueId,
    this.initialMosque,
  });

  final String mosqueId;
  final MosqueModel? initialMosque;

  factory MosqueDetailRouteArgs.fromMosque(MosqueModel mosque) {
    return MosqueDetailRouteArgs(
      mosqueId: mosque.id,
      initialMosque: mosque,
    );
  }
}
