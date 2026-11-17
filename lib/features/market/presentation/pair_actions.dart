import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/market.dart';

/// What other features offer on a pair (the watchlist's toggle, the alerts'
/// "Alert"), shown in the bottom bar of the analysis screen; composed in
/// `main.dart` so the features do not depend on each other.
typedef PairActionsBuilder =
    Widget Function(BuildContext context, MarketPair pair);

final pairActionsProvider = Provider<PairActionsBuilder?>((ref) => null);

/// The location of a pair's analysis screen (SCR-10 Spot, SCR-11 Futures).
String analysisLocation(Market market, String symbol) =>
    '/analysis/${market.path}/$symbol';

/// SRS 3.3.2 / 3.3.3: selecting a pair on SCR-09, SCR-12 or SCR-08 opens its
/// analysis.
void openPairAnalysis(BuildContext context, MarketPair pair) =>
    unawaited(context.push(analysisLocation(pair.market, pair.symbol)));
