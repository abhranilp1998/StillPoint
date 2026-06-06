import 'dart:io';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/models.dart';

class ExportResult {
  const ExportResult({required this.path, required this.format});

  final String path;
  final String format;
}

class ExportService {
  static final _fileStamp = DateFormat('yyyyMMdd_HHmm');

  static Future<ExportResult> exportCsv(AppState state) async {
    final directory = await getTemporaryDirectory();
    final path =
        '${directory.path}/stillpoint_${_fileStamp.format(DateTime.now())}.csv';
    final rows = _rows(state);
    final csvText = csv.encode(rows);
    await File(path).writeAsString(csvText);
    return ExportResult(path: path, format: 'CSV');
  }

  static Future<ExportResult> exportXlsx(AppState state) async {
    final directory = await getTemporaryDirectory();
    final path =
        '${directory.path}/stillpoint_${_fileStamp.format(DateTime.now())}.xlsx';
    final excel = Excel.createExcel();
    const sheetName = 'Logs';
    excel.rename('Sheet1', sheetName);

    for (final row in _rows(state)) {
      excel.appendRow(sheetName, [
        for (final value in row)
          if (value is num)
            DoubleCellValue(value.toDouble())
          else
            TextCellValue(value.toString()),
      ]);
    }

    final bytes = excel.save();
    if (bytes == null) {
      throw StateError('Could not create export file.');
    }
    await File(path).writeAsBytes(bytes, flush: true);
    return ExportResult(path: path, format: 'XLSX');
  }

  static Future<void> shareExport(ExportResult result) {
    return SharePlus.instance.share(
      ShareParams(
        text: 'Stillpoint export (${result.format})',
        files: [XFile(result.path)],
      ),
    );
  }

  static List<List<Object?>> _rows(AppState state) {
    final habitsById = {for (final habit in state.habits) habit.id: habit};
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    final rows = <List<Object?>>[
      [
        'Logged at',
        'Habit',
        'Category',
        'Quantity',
        'Unit',
        'Mood',
        'Craving',
        'Stress',
        'Trigger',
        'Note',
      ],
    ];

    final entries = [...state.entries]
      ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
    for (final entry in entries) {
      final habit = habitsById[entry.habitId];
      rows.add([
        dateFormat.format(entry.loggedAt),
        habit?.name ?? 'Unknown',
        habit?.category.label ?? 'Unknown',
        entry.quantity,
        habit?.unit ?? 'units',
        moodLabel(entry.mood),
        intensityLabel(entry.craving),
        intensityLabel(entry.stress),
        entry.trigger ?? '',
        entry.note ?? '',
      ]);
    }
    return rows;
  }
}
