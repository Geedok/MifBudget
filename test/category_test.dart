import 'package:flutter_test/flutter_test.dart';
import 'package:mifbudget/data/defaults.dart';
import 'package:mifbudget/data/repository.dart';
import 'package:mifbudget/models/category.dart';
import 'package:mifbudget/models/operation.dart';
import 'package:mifbudget/state/budget_store.dart';

void main() {
  final clock = DateTime(2026, 11, 26, 10);

  Future<BudgetStore> newStore() async {
    final store = await BudgetStore.open(
      MemoryRepository(),
      clock: () => clock,
    );
    await store.completeSetup(memberName: 'Eudokia', cash: 100000);
    return store;
  }

  test('créer une catégorie et une sous-catégorie', () async {
    final store = await newStore();
    final animaux = await store.addCategory(
      name: '  Animaux ',
      kind: CategoryKind.expense,
      group: CategoryGroup.comfort,
      icon: 'animaux',
      color: 0xFF5B5EA6,
    );
    expect(animaux.name, 'Animaux');
    expect(store.topCategories(CategoryKind.expense).last.id, animaux.id);

    final croquettes = await store.addCategory(
      name: 'Croquettes',
      kind: CategoryKind.income, // ignoré : le type vient de la parente
      parentId: animaux.id,
    );
    expect(croquettes.kind, CategoryKind.expense);
    expect(croquettes.group, CategoryGroup.comfort);
    expect(croquettes.icon, 'animaux');
    expect(store.subcategories(animaux.id).single.name, 'Croquettes');
    expect(store.topCategory(croquettes.id)!.id, animaux.id);
  });

  test('noms en double refusés au même niveau seulement', () async {
    final store = await newStore();
    expect(
      store.categoryNameTaken('alimentation ', kind: CategoryKind.expense),
      isTrue,
    );
    expect(
      store.categoryNameTaken('Alimentation', kind: CategoryKind.income),
      isFalse,
    );
    expect(
      store.categoryNameTaken(
        'Marché',
        kind: CategoryKind.expense,
        parentId: 'cat-alimentation',
      ),
      isTrue,
    );
    expect(
      store.categoryNameTaken(
        'Alimentation',
        kind: CategoryKind.expense,
        exceptId: 'cat-alimentation',
      ),
      isFalse,
    );
  });

  test(
    'changer de groupe ou d\'icône se reporte sur les sous-catégories',
    () async {
      final store = await newStore();
      final food = store.category('cat-alimentation')!;
      await store.updateCategory(
        food.copyWith(
          name: 'Alimentation et marché',
          group: () => CategoryGroup.comfort,
          icon: 'restaurant',
        ),
      );
      expect(
        store.category('cat-alimentation')!.name,
        'Alimentation et marché',
      );
      final marche = store.category('cat-alimentation-marche')!;
      expect(marche.group, CategoryGroup.comfort);
      expect(marche.icon, 'restaurant');
      expect(marche.name, 'Marché');
    },
  );

  test(
    'archiver puis restaurer, les opérations gardent leur catégorie',
    () async {
      final store = await newStore();
      await store.addOperation(
        type: OperationType.expense,
        amount: 5000,
        date: clock,
        categoryId: 'cat-loisirs-sorties',
        sourceWalletId: DefaultIds.walletCash,
      );
      expect(store.categoryUsage('cat-loisirs'), 1);
      final loisirs = store.category('cat-loisirs')!;
      await store.updateCategory(loisirs.copyWith(archived: true));
      expect(
        store.topCategories(CategoryKind.expense).map((c) => c.id),
        isNot(contains('cat-loisirs')),
      );
      expect(
        store.frequentCategories(CategoryKind.expense).map((c) => c.id),
        isNot(contains('cat-loisirs')),
      );
      expect(
        store.archivedTopCategories(CategoryKind.expense).single.id,
        'cat-loisirs',
      );
      // L'opération reste rattachée et comptée.
      expect(store.operations.single.categoryId, 'cat-loisirs-sorties');
      expect(store.monthSummary(clock).expense, 5000);
      // Un nom archivé peut être réutilisé.
      expect(
        store.categoryNameTaken('Loisirs', kind: CategoryKind.expense),
        isFalse,
      );

      await store.updateCategory(
        store.category('cat-loisirs')!.copyWith(archived: false),
      );
      expect(store.archivedTopCategories(CategoryKind.expense), isEmpty);

      // Sous-catégorie archivée seule.
      final sorties = store.category('cat-loisirs-sorties')!;
      await store.updateCategory(sorties.copyWith(archived: true));
      expect(
        store.subcategories('cat-loisirs').map((c) => c.name),
        isNot(contains('Sorties')),
      );
      expect(store.archivedSubcategories('cat-loisirs').single.name, 'Sorties');
    },
  );
}
