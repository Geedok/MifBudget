import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../models/category.dart';
import '../../models/operation.dart';
import '../../models/wallet.dart';
import '../../state/budget_store.dart';
import '../../theme.dart';

const categoryIcons = <String, IconData>{
  'alimentation': Icons.shopping_basket_outlined,
  'logement': Icons.home_outlined,
  'transport': Icons.directions_car_outlined,
  'communication': Icons.phone_android_outlined,
  'sante': Icons.medical_services_outlined,
  'enfants': Icons.school_outlined,
  'dettes': Icons.credit_card_outlined,
  'frais': Icons.receipt_long_outlined,
  'famille': Icons.groups_outlined,
  'dons': Icons.volunteer_activism_outlined,
  'maison': Icons.chair_outlined,
  'habillement': Icons.checkroom_outlined,
  'loisirs': Icons.local_activity_outlined,
  'argent_personnel': Icons.person_outline,
  'divers': Icons.more_horiz,
  'salaires': Icons.work_outline,
  'activites': Icons.storefront_outlined,
  'autres_revenus': Icons.payments_outlined,
  // Icônes supplémentaires pour les catégories créées par le foyer.
  'restaurant': Icons.restaurant_outlined,
  'carburant': Icons.local_gas_station_outlined,
  'electricite': Icons.bolt_outlined,
  'eau': Icons.water_drop_outlined,
  'internet': Icons.wifi,
  'abonnement': Icons.subscriptions_outlined,
  'loyer': Icons.key_outlined,
  'travaux': Icons.build_outlined,
  'bebe': Icons.child_friendly_outlined,
  'animaux': Icons.pets_outlined,
  'sport': Icons.fitness_center_outlined,
  'beaute': Icons.spa_outlined,
  'cadeau': Icons.card_giftcard_outlined,
  'eglise': Icons.church_outlined,
  'voyage': Icons.flight_outlined,
  'agriculture': Icons.agriculture_outlined,
  'placement': Icons.trending_up,
  'portefeuille': Icons.account_balance_wallet_outlined,
};

/// Noms lus par le lecteur d'écran pour chaque icône de catégorie.
const categoryIconLabels = <String, String>{
  'alimentation': 'Panier',
  'logement': 'Maison',
  'transport': 'Voiture',
  'communication': 'Téléphone',
  'sante': 'Santé',
  'enfants': 'École',
  'dettes': 'Carte bancaire',
  'frais': 'Reçu',
  'famille': 'Famille',
  'dons': 'Don',
  'maison': 'Fauteuil',
  'habillement': 'Vêtements',
  'loisirs': 'Loisirs',
  'argent_personnel': 'Personne',
  'divers': 'Divers',
  'salaires': 'Travail',
  'activites': 'Commerce',
  'autres_revenus': 'Billets',
  'restaurant': 'Restaurant',
  'carburant': 'Carburant',
  'electricite': 'Électricité',
  'eau': 'Eau',
  'internet': 'Internet',
  'abonnement': 'Abonnement',
  'loyer': 'Clé',
  'travaux': 'Travaux',
  'bebe': 'Bébé',
  'animaux': 'Animaux',
  'sport': 'Sport',
  'beaute': 'Beauté',
  'cadeau': 'Cadeau',
  'eglise': 'Église',
  'voyage': 'Voyage',
  'agriculture': 'Agriculture',
  'placement': 'Placement',
  'portefeuille': 'Portefeuille',
};

/// Couleurs proposées pour les catégories (celles des catégories par
/// défaut, lisibles sur les deux thèmes en pastille).
const categoryColors = <int>[
  0xFF2E7D5B,
  0xFF1F6B4F,
  0xFF3A7D7C,
  0xFF2F6690,
  0xFF5B5EA6,
  0xFF6B4E71,
  0xFFA4508B,
  0xFFB23A48,
  0xFFB4531A,
  0xFFC27C0E,
  0xFF8A5A2B,
  0xFF7A6C2E,
  0xFF4F6D7A,
  0xFF6E7A74,
];

/// Icônes proposées pour les objectifs d'épargne.
const goalIcons = <String, IconData>{
  'epargne': Icons.savings_outlined,
  'surete': Icons.shield_outlined,
  'construction': Icons.foundation,
  'maison': Icons.home_work_outlined,
  'ecole': Icons.school_outlined,
  'vehicule': Icons.directions_car_outlined,
  'voyage': Icons.flight_outlined,
  'fete': Icons.celebration_outlined,
};

IconData goalIcon(String? key) => goalIcons[key] ?? Icons.savings_outlined;

/// « Banque · Épargne · Personnel, privé ».
String walletDescription(Wallet w) => [
  w.type.label,
  if (w.isSavings) 'Épargne',
  if (!w.shared) w.private ? 'Personnel, privé' : 'Personnel, visible',
].join(' · ');

IconData walletIcon(WalletType type) => switch (type) {
  WalletType.cash => Icons.payments_outlined,
  WalletType.bank => Icons.account_balance_outlined,
  WalletType.mobileMoney => Icons.smartphone_outlined,
};

/// Pastille ronde avec l'icône de la catégorie.
class CategoryBadge extends StatelessWidget {
  const CategoryBadge({
    super.key,
    required this.category,
    this.size = 40,
    this.icon,
    this.color,
  });

  final Category? category;
  final double size;

  /// Couleur à utiliser à la place de celle de la catégorie.
  final Color? color;

  /// Icône à afficher à la place de celle de la catégorie.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final mif = context.mif;
    final color =
        this.color ??
        (category == null ? mif.textSecondary : Color(category!.color));
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.28 : 0.14),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon != null
            ? icon!
            : category == null
            ? Icons.swap_horiz
            : categoryIcons[category!.icon] ?? Icons.more_horiz,
        size: size * 0.5,
        color: dark ? Color.lerp(color, Colors.white, 0.45) : color,
      ),
    );
  }
}

/// Carte blanche arrondie de la charte.
class MifCard extends StatelessWidget {
  const MifCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  // Un Material (et non un simple fond coloré) pour que les lignes de liste
  // et les boutons à l'intérieur gardent leur effet au toucher.
  @override
  Widget build(BuildContext context) => Material(
    color: context.mif.card,
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: padding ?? const EdgeInsets.all(16), child: child),
  );
}

/// Libellé principal d'une opération : sous-catégorie, catégorie, objectif
/// d'épargne, « Épargne », « Retrait d'épargne » ou « Transfert ».
String operationTitle(BudgetStore store, Operation op) {
  final direction = store.savingsDirection(op);
  if (direction != 0 || op.type.isSavings) {
    final goal = store.goal(op.savingsGoalId);
    if (goal != null) return goal.name;
    return direction < 0 || op.type == OperationType.savingsWithdrawal
        ? "Retrait d'épargne"
        : 'Épargne';
  }
  if (op.type == OperationType.transfer) return 'Transfert';
  return store.category(op.categoryId)?.name ?? op.type.label;
}

/// Montant signé selon le point de vue du foyer (le transfert ne change pas
/// le total).
int signedAmount(Operation op) => switch (op.type) {
  OperationType.income || OperationType.savingsWithdrawal => op.amount,
  OperationType.expense || OperationType.savingsDeposit => -op.amount,
  OperationType.transfer => 0,
};

/// Ligne d'opération dans une liste.
class OperationTile extends StatelessWidget {
  const OperationTile({
    super.key,
    required this.operation,
    this.onTap,
    this.showDate = false,
  });

  final Operation operation;
  final VoidCallback? onTap;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final mif = context.mif;
    final op = operation;
    final isTransfer = op.type == OperationType.transfer;
    // Une seule ligne sous le titre : qui (si c'est l'autre), avec quel
    // compte, et quand (dans les listes sans en-tête de jour).
    final parts = <String>[];
    final author = store.memberName(op.authorId);
    if (author != null) parts.add(author);
    final direction = store.savingsDirection(op);
    final savings = direction != 0 || op.type.isSavings;
    String walletName(String? id) =>
        store.wallet(id)?.name ?? 'Portefeuille personnel';
    if (savings) {
      final out = direction < 0 || op.type == OperationType.savingsWithdrawal;
      parts.add(out ? 'Retiré' : 'Mis de côté');
    } else if (isTransfer ||
        (op.type == OperationType.expense && op.targetWalletId != null)) {
      // Transfert, ou versement d'argent personnel vers un portefeuille.
      parts.add(
        '${walletName(op.sourceWalletId)} → ${walletName(op.targetWalletId)}',
      );
    } else {
      final w = store.wallet(
        op.type == OperationType.income ? op.targetWalletId : op.sourceWalletId,
      );
      if (w != null) parts.add(w.name);
    }
    if (showDate) parts.add(dayLabel(op.date, now: store.now()).toLowerCase());

    // Transferts et épargne ne sont ni des revenus ni des dépenses.
    final neutral = isTransfer || savings;
    final amountText = neutral
        ? formatAmount(op.amount)
        : formatSigned(signedAmount(op));
    final amountColor = op.type == OperationType.income
        ? mif.income
        : neutral
        ? mif.textSecondary
        : mif.text;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            CategoryBadge(
              category: isTransfer || savings
                  ? null
                  : store.topCategory(op.categoryId),
              icon: savings
                  ? goalIcon(store.goal(op.savingsGoalId)?.icon)
                  : null,
              color: savings ? mif.green : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    operationTitle(store, op),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: mif.text,
                    ),
                  ),
                  if (parts.isNotEmpty)
                    Text(
                      parts.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: mif.textSecondary),
                    ),
                ],
              ),
            ),
            if (op.personal) ...[
              const SizedBox(width: 8),
              Icon(
                op.visibleToPartner ? Icons.person_outline : Icons.lock_outline,
                size: 16,
                semanticLabel: op.visibleToPartner
                    ? 'Dépense perso, visible'
                    : 'Dépense perso, privée',
                color: mif.textSecondary,
              ),
            ],
            const SizedBox(width: 12),
            Text(
              amountText,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: amountColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grand titre de section.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: context.mif.text,
          ),
        ),
      ),
      ?trailing,
    ],
  );
}
