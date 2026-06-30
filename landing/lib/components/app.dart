import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import 'features.dart';
import 'footer.dart';
import 'hero.dart';

class App extends StatelessComponent {
  const App({super.key});

  @override
  Component build(BuildContext context) {
    return main_(classes: 'landing', [
      const Hero(),
      const Features(),
      const SiteFooter(),
    ]);
  }
}
