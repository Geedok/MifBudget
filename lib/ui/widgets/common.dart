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
};

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

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: context.mif.card,
      borderRadius: BorderRadius.circular(16),
    ),
    padding: padding ?? const EdgeInsets.all(16),
    child: child,
  );
}

/// Libellé principal d'une opération : sous-catégorie, catégorie ou
/// « Transfert ».
String operationTitle(BudgetStore store, Operation op) {
  if (op.type == OperationType.transfer) return 'Transfert';
  if (op.type.isSavings) {
    return store.goal(op.savingsGoalId)?.name ?? op.type.label;
  }
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
    final parts = <String>[];
    final cat = store.category(op.categoryId);
    if (cat != null && cat.isSub) {
      final parent = store.category(cat.parentId);
      if (parent != null) parts.add(parent.name);
    }
    if (op.type.isSavings) {
      parts.add(
        op.type == OperationType.savingsDeposit ? 'Mis de côté' : 'Retiré',
      );
      final w = store.wallet(op.sourceWalletId ?? op.targetWalletId);
      if (w != null) parts.add(w.name);
    } else if (isTransfer) {
      parts.add(
        '${store.wallet(op.sourceWalletId)?.name ?? '?'} → ${store.wallet(op.targetWalletId)?.name ?? '?'}',
      );
    } else {
      final w = store.wallet(
        op.type == OperationType.income ? op.targetWalletId : op.sourceWalletId,
      );
      if (w != null) parts.add(w.name);
    }
    if (showDate) parts.add(dayLabel(op.date, now: store.now()).toLowerCase());
    if (op.note.isNotEmpty) parts.add(op.note);

    // Transferts et épargne ne sont ni des revenus ni des dépenses.
    final neutral = isTransfer || op.type.isSavings;
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
              category: isTransfer || op.type.isSavings
                  ? null
                  : store.topCategory(op.categoryId),
              icon: op.type.isSavings
                  ? goalIcon(store.goal(op.savingsGoalId)?.icon)
                  : null,
              color: op.type.isSavings ? mif.green : null,
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
