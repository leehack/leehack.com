import 'package:jaspr/jaspr.dart';

import 'site_interactions_stub.dart' if (dart.library.js_interop) 'site_interactions_web.dart';

@client
class SiteInteractions extends StatefulComponent {
  const SiteInteractions({super.key});

  @override
  State<SiteInteractions> createState() => _SiteInteractionsState();
}

class _SiteInteractionsState extends State<SiteInteractions> {
  late final void Function() _disposeInteractions;

  @override
  void initState() {
    super.initState();
    _disposeInteractions = mountSiteInteractions();
  }

  @override
  void dispose() {
    _disposeInteractions();
    super.dispose();
  }

  @override
  Component build(BuildContext context) => const Component.fragment([]);
}
