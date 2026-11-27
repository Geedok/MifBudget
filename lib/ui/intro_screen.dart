import 'package:material_ui/material_ui.dart';

import '../theme.dart';
import 'widgets/logo.dart';

/// Présentation en 3 écrans : saisir une dépense, les 5 onglets, à deux.
/// Montrée une fois par téléphone, puis depuis Réglages → Présentation.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key, required this.onDone});

  /// Appelé par « C'est parti » ou « Passer ».
  final VoidCallback onDone;

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) =>
          IntroScreen(onDone: () => Navigator.of(context).pop()),
    ),
  );

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final _pages = PageController();
  int _page = 0;

  static const _count = 3;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mif = context.mif;
    final last = _page == _count - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 8, 0),
                child: Visibility(
                  visible: !last,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: TextButton(
                    onPressed: widget.onDone,
                    child: const Text('Passer'),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (i) => setState(() => _page = i),
                children: const [_EntryPage(), _TabsPage(), _TogetherPage()],
              ),
            ),
            Semantics(
              label: 'Écran ${_page + 1} sur $_count',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _count; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: i == _page ? 22 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: i == _page ? mif.green : mif.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: FilledButton(
                onPressed: last
                    ? widget.onDone
                    : () => _pages.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      ),
                child: Text(last ? "C'est parti" : 'Suivant'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mise en page commune : illustration, titre, texte.
class _Page extends StatelessWidget {
  const _Page({
    required this.picture,
    required this.title,
    required this.text,
    this.extra,
  });

  final Widget picture;
  final String title;
  final String text;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final mif = context.mif;
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 16),
      children: [
        Center(child: picture),
        const SizedBox(height: 28),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: mif.text,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, height: 1.4, color: mif.textSecondary),
        ),
        if (extra != null) ...[const SizedBox(height: 20), extra!],
      ],
    );
  }
}

class _EntryPage extends StatelessWidget {
  const _EntryPage();

  @override
  Widget build(BuildContext context) {
    final mif = context.mif;
    return _Page(
      picture: Stack(
        clipBehavior: Clip.none,
        children: [
          const MifLogo(size: 120),
          Positioned(
            right: -18,
            bottom: -18,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: mif.terracotta,
                shape: BoxShape.circle,
                border: Border.all(color: mif.background, width: 4),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 32),
            ),
          ),
        ],
      ),
      title: 'Une dépense en quelques secondes',
      text:
          'Touchez le bouton + en bas à droite, tapez le montant, choisissez '
          "la catégorie : c'est enregistré. Le bouton + est là sur tous les "
          'écrans.',
    );
  }
}

class _TabsPage extends StatelessWidget {
  const _TabsPage();

  @override
  Widget build(BuildContext context) {
    final mif = context.mif;
    Widget row(IconData icon, String name, String what) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: mif.greenSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: mif.green, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$name\n',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: mif.text,
                    ),
                  ),
                  TextSpan(text: what),
                ],
              ),
              style: TextStyle(fontSize: 14, color: mif.textSecondary),
            ),
          ),
        ],
      ),
    );
    return _Page(
      picture: Icon(Icons.explore_outlined, size: 72, color: mif.green),
      title: 'Cinq onglets, en bas',
      text: 'Chaque onglet répond à une question.',
      extra: Column(
        children: [
          row(Icons.home_outlined, 'Accueil', 'Où en est le mois ?'),
          row(
            Icons.receipt_long_outlined,
            'Opérations',
            "Qu'a-t-on saisi ? Touchez une ligne pour la corriger.",
          ),
          row(
            Icons.pie_chart_outline,
            'Budgets',
            'Combien reste-t-il pour chaque catégorie ?',
          ),
          row(
            Icons.savings_outlined,
            'Épargnes',
            'Où en sont nos objectifs et nos projets ?',
          ),
          row(Icons.bar_chart, 'Rapports', 'Comment évoluent nos finances ?'),
        ],
      ),
    );
  }
}

class _TogetherPage extends StatelessWidget {
  const _TogetherPage();

  @override
  Widget build(BuildContext context) {
    final mif = context.mif;
    return _Page(
      picture: Icon(Icons.people_outline, size: 80, color: mif.green),
      title: 'À deux, chacun son téléphone',
      text:
          'Ce que vous saisissez apparaît chez votre conjoint. Votre argent '
          'personnel reste à vous : vos dépenses privées ne sont visibles '
          "que par vous.\n\nComptes, catégories, partage et code : tout est "
          "dans les Réglages, la roue en haut de l'Accueil.",
    );
  }
}
