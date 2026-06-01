import 'package:flutter_test/flutter_test.dart';
import 'package:d22/grid_state.dart';

void main() {
  group('GridState Tests', () {
    test('Initialization generates 48 cells with correct structure', () {
      final state = GridState();
      expect(state.cells.length, 48);

      // Verify coordinate ranges
      for (final cell in state.cells) {
        expect(cell.currentCol, inInclusiveRange(0, 5));
        expect(cell.currentRow, inInclusiveRange(0, 7));
        expect(cell.codeText.length, 6);
        expect(cell.secretLetter.length, 1);
      }
    });

    test('Cell Swapping works correctly and coordinates are swapped', () {
      final state = GridState();

      final cellA = state.getCellAt(0, 0)!;
      final cellB = state.getCellAt(1, 1)!;
      final idA = cellA.id;
      final idB = cellB.id;

      state.swapCells(idA, idB);

      final newCellA = state.cells.firstWhere((c) => c.id == idA);
      final newCellB = state.cells.firstWhere((c) => c.id == idB);

      expect(newCellA.currentCol, 1);
      expect(newCellA.currentRow, 1);
      expect(newCellB.currentCol, 0);
      expect(newCellB.currentRow, 0);
    });

    test('Row Swapping swaps coordinates of all cells in target rows', () {
      final state = GridState();

      // Store initial ids in row 0 and row 1
      final row0Ids = List.generate(6, (c) => state.getCellAt(c, 0)!.id);
      final row1Ids = List.generate(6, (c) => state.getCellAt(c, 1)!.id);

      state.swapRows(0, 1);

      // Verify row 0 cells now have row 1 coordinates
      for (final id in row0Ids) {
        final cell = state.cells.firstWhere((c) => c.id == id);
        expect(cell.currentRow, 1);
      }

      // Verify row 1 cells now have row 0 coordinates
      for (final id in row1Ids) {
        final cell = state.cells.firstWhere((c) => c.id == id);
        expect(cell.currentRow, 0);
      }
    });

    test('Column Swapping swaps coordinates of all cells in target columns', () {
      final state = GridState();

      final col0Ids = List.generate(8, (r) => state.getCellAt(0, r)!.id);
      final col1Ids = List.generate(8, (r) => state.getCellAt(1, r)!.id);

      state.swapCols(0, 1);

      for (final id in col0Ids) {
        final cell = state.cells.firstWhere((c) => c.id == id);
        expect(cell.currentCol, 1);
      }

      for (final id in col1Ids) {
        final cell = state.cells.firstWhere((c) => c.id == id);
        expect(cell.currentCol, 0);
      }
    });

    test('Character Mode prevents any swapping operations', () {
      final state = GridState();
      state.toggleCharacterMode(); // Enable character mode

      final cellA = state.getCellAt(0, 0)!;
      final cellB = state.getCellAt(1, 1)!;

      state.swapCells(cellA.id, cellB.id);
      
      // Values should remain unchanged
      expect(state.getCellAt(0, 0)!.id, cellA.id);
      expect(state.getCellAt(1, 1)!.id, cellB.id);

      state.swapRows(0, 1);
      expect(state.getCellAt(0, 0)!.id, cellA.id);

      state.swapCols(0, 1);
      expect(state.getCellAt(0, 0)!.id, cellA.id);
    });

    test('Tap to swap updates selection and performs swap when second cell tapped', () {
      final state = GridState();

      final cellA = state.getCellAt(0, 0)!;
      final cellB = state.getCellAt(1, 1)!;

      state.handleCellTap(cellA.id);
      expect(state.selectedCellId, cellA.id);

      state.handleCellTap(cellB.id);
      expect(state.selectedCellId, isNull);

      // Coordinates must be swapped
      expect(state.getCellAt(1, 1)!.id, cellA.id);
      expect(state.getCellAt(0, 0)!.id, cellB.id);
    });
  });
}
