import '../models/mosque_model.dart';
import '../models/prayer_timings.dart';

List<String> listedPrayerSummaryParts(MosqueModel mosque) {
  return <String>[
    if (mosque.hasDhuhrTime) 'Dhuhr ${mosque.duhrTime}',
    if (mosque.hasAsrTime) 'Asr ${mosque.asarTime}',
  ];
}

String buildMosqueListingPrayerSummary(MosqueModel mosque) {
  final parts = listedPrayerSummaryParts(mosque);
  if (parts.isEmpty) {
    return 'Prayer times not published yet';
  }

  return 'Listed: ${parts.join('  •  ')}';
}

String buildMosqueListingPrayerSubtitle(MosqueModel mosque) {
  if (listedPrayerSummaryParts(mosque).isEmpty) {
    return 'Live prayer timings have not been published for this mosque yet.';
  }

  return 'Using the prayer times currently published on this mosque listing.';
}

String buildMosqueListingPrayerStatus(MosqueModel mosque) {
  if (listedPrayerSummaryParts(mosque).isEmpty) {
    return 'Prayer timings not published';
  }

  return 'Listing summary only';
}

String buildMosquePrayerSummaryLabel(
  PrayerTimings? prayerTimings,
  MosqueModel mosque,
) {
  final liveAsr = prayerTimings?.timeFor('asr').trim() ?? '';
  if (liveAsr.isNotEmpty) {
    return 'Asr $liveAsr';
  }

  if (mosque.hasAsrTime) {
    return 'Listed Asr ${mosque.asarTime}';
  }

  if (mosque.hasDhuhrTime) {
    return 'Listed Dhuhr ${mosque.duhrTime}';
  }

  return 'Prayer times pending';
}
