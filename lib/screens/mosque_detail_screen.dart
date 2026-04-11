import 'package:flutter/material.dart';

import '../navigation/mosque_detail_route_args.dart';
import '../services/bookmark_service.dart';
import '../services/mosque_service.dart';
import '../services/outbound_action_service.dart';
import 'mosque_page.dart';

class MosqueDetailScreen extends StatelessWidget {
  const MosqueDetailScreen({
    super.key,
    required this.args,
    this.mosqueService,
    this.bookmarkService,
    this.outboundActionService = const OutboundActionService(),
  });

  final MosqueDetailRouteArgs args;
  final MosqueService? mosqueService;
  final BookmarkService? bookmarkService;
  final OutboundActionService outboundActionService;

  @override
  Widget build(BuildContext context) {
    // Legacy compatibility entry point. The routed detail source of truth now
    // lives in MosquePage so direct old-screen callers stay aligned.
    return MosquePage(
      args: args,
      mosqueService: mosqueService,
      bookmarkService: bookmarkService,
      outboundActionService: outboundActionService,
    );
  }
}
