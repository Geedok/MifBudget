import '../models/category.dart';
import '../models/wallet.dart';

/// Identifiants fixes des catégories et portefeuilles créés à l'installation,
/// pour qu'ils restent les mêmes une fois le foyer synchronisé.
class DefaultIds {
  static const walletCash = 'portefeuille-especes';
  static const walletBank = 'portefeuille-banque';
  static const walletMobileMoney = 'portefeuille-mobile-money';
}

class _Def {
  const _Def(
    this.key,
    this.name,
    this.icon,
    this.color, {
    this.group,
    this.subs = const [],
  });
  final String key;
  final String name;
  final String icon;
  final int color;
  final CategoryGroup? group;
  final List<String> subs;
}

const _expenses = <_Def>[
  _Def(
    'alimentation',
    'Alimentation',
    'alimentation',
    0xFF2E7D5B,
    group: CategoryGroup.essential,
    subs: ['Marché', 'Supermarché', 'Repas dehors'],
  ),
  _Def(
    'logement',
    'Logement',
    'logement',
    0xFF8A5A2B,
    group: CategoryGroup.essential,
    subs: ['Loyer', 'Électricité', 'Eau', 'Gaz'],
  ),
  _Def(
    'transport',
    'Transport',
    'transport',
    0xFF2F6690,
    group: CategoryGroup.essential,
    subs: ['Carburant', 'Taxi et moto', 'Entretien véhicule'],
  ),
  _Def(
    'communication',
    'Communication',
    'communication',
    0xFF5B5EA6,
    group: CategoryGroup.essential,
    subs: ['Crédit téléphone', 'Internet'],
  ),
  _Def(
    'sante',
    'Santé',
    'sante',
    0xFFB23A48,
    group: CategoryGroup.essential,
    subs: ['Pharmacie', 'Consultation', 'Assurance santé'],
  ),
  _Def(
    'enfants',
    'Enfants et école',
    'enfants',
    0xFFC27C0E,
    group: CategoryGroup.essential,
    subs: ['Scolarité', 'Fournitures', 'Garde'],
  ),
  _Def(
    'dettes',
    'Dettes et crédits',
    'dettes',
    0xFF6B4E71,
    group: CategoryGroup.essential,
    subs: ['Remboursement', 'Intérêts'],
  ),
  _Def(
    'frais',
    'Frais financiers',
    'frais',
    0xFF4F6D7A,
    group: CategoryGroup.essential,
    subs: ['Frais Mobile Money', 'Frais bancaires'],
  ),
  _Def(
    'famille',
    'Famille et solidarité',
    'famille',
    0xFFB4531A,
    group: CategoryGroup.comfort,
    subs: ['Cérémonies', 'Aide à la famille'],
  ),
  _Def(
    'dons',
    'Dons et religion',
    'dons',
    0xFF7A6C2E,
    group: CategoryGroup.comfort,
    subs: ['Offrandes', 'Dons'],
  ),
  _Def(
    'maison',
    'Maison et équipement',
    'maison',
    0xFF8C6D46,
    group: CategoryGroup.comfort,
    subs: ['Équipement', 'Entretien', 'Produits ménagers'],
  ),
  _Def(
    'habillement',
    'Habillement et soins',
    'habillement',
    0xFFA4508B,
    group: CategoryGroup.comfort,
    subs: ['Vêtements', 'Coiffure et soins'],
  ),
  _Def(
    'loisirs',
    'Loisirs',
    'loisirs',
    0xFF3A7D7C,
    group: CategoryGroup.comfort,
    subs: ['Sorties', 'Abonnements', 'Voyages'],
  ),
  _Def(
    'argent-personnel',
    'Argent personnel',
    'argent_personnel',
    0xFF55606A,
    group: CategoryGroup.comfort,
  ),
  _Def('divers', 'Divers', 'divers', 0xFF6E7A74, group: CategoryGroup.comfort),
];

const _incomes = <_Def>[
  _Def('salaires', 'Salaires', 'salaires', 0xFF1F6B4F),
  _Def('activites-annexes', 'Activités annexes', 'activites', 0xFF2F6690),
  _Def('autres-revenus', 'Autres revenus', 'autres_revenus', 0xFF7A6C2E),
];

String _slug(String s) {
  const accents = {
    'à': 'a',
    'â': 'a',
    'ç': 'c',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'î': 'i',
    'ï': 'i',
    'ô': 'o',
    'ù': 'u',
    'û': 'u',
    'É': 'e',
  };
  final lower = s.toLowerCase().split('').map((c) => accents[c] ?? c).join();
  return lower
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
}

List<Category> defaultCategories(DateTime now) {
  final result = <Category>[];
  void add(List<_Def> defs, CategoryKind kind) {
    for (var i = 0; i < defs.length; i++) {
      final d = defs[i];
      final id = 'cat-${d.key}';
      result.add(
        Category(
          id: id,
          name: d.name,
          kind: kind,
          group: d.group,
          icon: d.icon,
          color: d.color,
          sortOrder: i,
          updatedAt: now,
        ),
      );
      for (var j = 0; j < d.subs.length; j++) {
        result.add(
          Category(
            id: '$id-${_slug(d.subs[j])}',
            name: d.subs[j],
            kind: kind,
            group: d.group,
            parentId: id,
            icon: d.icon,
            color: d.color,
            sortOrder: j,
            updatedAt: now,
          ),
        );
      }
    }
  }

  add(_expenses, CategoryKind.expense);
  add(_incomes, CategoryKind.income);
  return result;
}

List<Wallet> defaultWallets(
  DateTime now, {
  int cash = 0,
  int bank = 0,
  int mobileMoney = 0,
}) => [
  Wallet(
    id: DefaultIds.walletCash,
    name: 'Espèces',
    type: WalletType.cash,
    openingBalance: cash,
    sortOrder: 0,
    updatedAt: now,
  ),
  Wallet(
    id: DefaultIds.walletBank,
    name: 'Banque',
    type: WalletType.bank,
    openingBalance: bank,
    sortOrder: 1,
    updatedAt: now,
  ),
  Wallet(
    id: DefaultIds.walletMobileMoney,
    name: 'Mobile Money',
    type: WalletType.mobileMoney,
    openingBalance: mobileMoney,
    sortOrder: 2,
    updatedAt: now,
  ),
];
