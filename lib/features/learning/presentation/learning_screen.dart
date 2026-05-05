import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

class _KanaCell {
  const _KanaCell(this.jp, this.ko);

  final String jp;
  final String ko;
}

class _KanaLine {
  const _KanaLine(this.rowLabel, this.cells);

  final String rowLabel;
  final List<_KanaCell?> cells;
}

class _LearningRow {
  const _LearningRow({
    required this.type,
    required this.jp,
    required this.hiragana,
    required this.kor,
    required this.korPronunciation,
    required this.hiraganaDisplay,
  });

  final String type;
  final String jp;
  final String hiragana;
  final String kor;
  final String korPronunciation;
  final bool hiraganaDisplay;
}

enum _LearningKind {
  kana,
  number,
  counter,
  date,
  time,
}

const Map<_LearningKind, String> _kindLabels = {
  _LearningKind.kana: '기본문자표',
  _LearningKind.number: '숫자표',
  _LearningKind.counter: '세기표',
  _LearningKind.date: '날짜표',
  _LearningKind.time: '시간표',
};

const Map<_LearningKind, List<String>> _kindTypes = {
  _LearningKind.kana: ['kana'],
  _LearningKind.number: ['number'],
  _LearningKind.counter: ['conter_age', 'conter_person'],
  _LearningKind.date: ['date_week', 'date_year', 'date_month', 'date_day'],
  _LearningKind.time: ['time_hour', 'time_min'],
};

const Map<String, String> _typeLabels = {
  'kana': '기본문자',
  'number': '숫자',
  'conter_age': '나이 세기',
  'conter_person': '사람 수 세기',
  'date_week': '요일',
  'date_year': '연도',
  'date_month': '월',
  'date_day': '일',
  'time_hour': '시',
  'time_min': '분',
};

const List<_KanaLine> _hiraganaRows = [
  _KanaLine('아행', [ _KanaCell('あ', '아'), _KanaCell('い', '이'), _KanaCell('う', '우'), _KanaCell('え', '에'), _KanaCell('お', '오') ]),
  _KanaLine('카행', [ _KanaCell('か', '카'), _KanaCell('き', '키'), _KanaCell('く', '쿠'), _KanaCell('け', '케'), _KanaCell('こ', '코') ]),
  _KanaLine('사행', [ _KanaCell('さ', '사'), _KanaCell('し', '시'), _KanaCell('す', '스'), _KanaCell('せ', '세'), _KanaCell('そ', '소') ]),
  _KanaLine('타행', [ _KanaCell('た', '타'), _KanaCell('ち', '치'), _KanaCell('つ', '츠'), _KanaCell('て', '테'), _KanaCell('と', '토') ]),
  _KanaLine('나행', [ _KanaCell('な', '나'), _KanaCell('に', '니'), _KanaCell('ぬ', '누'), _KanaCell('ね', '네'), _KanaCell('の', '노') ]),
  _KanaLine('하행', [ _KanaCell('は', '하'), _KanaCell('ひ', '히'), _KanaCell('ふ', '후'), _KanaCell('へ', '헤'), _KanaCell('ほ', '호') ]),
  _KanaLine('마행', [ _KanaCell('ま', '마'), _KanaCell('み', '미'), _KanaCell('む', '무'), _KanaCell('め', '메'), _KanaCell('も', '모') ]),
  _KanaLine('야행', [ _KanaCell('や', '야'), null, _KanaCell('ゆ', '유'), null, _KanaCell('よ', '요') ]),
  _KanaLine('라행', [ _KanaCell('ら', '라'), _KanaCell('り', '리'), _KanaCell('る', '루'), _KanaCell('れ', '레'), _KanaCell('ろ', '로') ]),
  _KanaLine('와행', [ _KanaCell('わ', '와'), null, null, null, _KanaCell('を', '오(조사)') ]),
  _KanaLine('응행', [ null, null, _KanaCell('ん', '응/ㄴ'), null, null ]),
];

const List<_KanaLine> _katakanaRows = [
  _KanaLine('아행', [ _KanaCell('ア', '아'), _KanaCell('イ', '이'), _KanaCell('ウ', '우'), _KanaCell('エ', '에'), _KanaCell('オ', '오') ]),
  _KanaLine('카행', [ _KanaCell('カ', '카'), _KanaCell('キ', '키'), _KanaCell('ク', '쿠'), _KanaCell('ケ', '케'), _KanaCell('コ', '코') ]),
  _KanaLine('사행', [ _KanaCell('サ', '사'), _KanaCell('シ', '시'), _KanaCell('ス', '스'), _KanaCell('セ', '세'), _KanaCell('ソ', '소') ]),
  _KanaLine('타행', [ _KanaCell('タ', '타'), _KanaCell('チ', '치'), _KanaCell('ツ', '츠'), _KanaCell('テ', '테'), _KanaCell('ト', '토') ]),
  _KanaLine('나행', [ _KanaCell('ナ', '나'), _KanaCell('ニ', '니'), _KanaCell('ヌ', '누'), _KanaCell('ネ', '네'), _KanaCell('ノ', '노') ]),
  _KanaLine('하행', [ _KanaCell('ハ', '하'), _KanaCell('ヒ', '히'), _KanaCell('フ', '후'), _KanaCell('ヘ', '헤'), _KanaCell('ホ', '호') ]),
  _KanaLine('마행', [ _KanaCell('マ', '마'), _KanaCell('ミ', '미'), _KanaCell('ム', '무'), _KanaCell('メ', '메'), _KanaCell('モ', '모') ]),
  _KanaLine('야행', [ _KanaCell('ヤ', '야'), null, _KanaCell('ユ', '유'), null, _KanaCell('ヨ', '요') ]),
  _KanaLine('라행', [ _KanaCell('ラ', '라'), _KanaCell('リ', '리'), _KanaCell('ル', '루'), _KanaCell('レ', '레'), _KanaCell('ロ', '로') ]),
  _KanaLine('와행', [ _KanaCell('ワ', '와'), null, null, null, _KanaCell('ヲ', '오(조사)') ]),
  _KanaLine('응행', [ null, null, _KanaCell('ン', '응/ㄴ'), null, null ]),
];

class LearningScreen extends StatefulWidget {
  const LearningScreen({super.key});

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> {
  static const String _learningCsvPath = 'assets/questions/basic_learning.csv';

  late final Future<List<_LearningRow>> _learningFuture;
  final _kindScrollController = ScrollController();
  final _kindButtonKeys = <_LearningKind, GlobalKey>{
    for (final kind in _LearningKind.values) kind: GlobalKey(),
  };
  _LearningKind _selectedKind = _LearningKind.kana;

  @override
  void initState() {
    super.initState();
    _learningFuture = _loadLearningRows();
  }

  Future<List<_LearningRow>> _loadLearningRows() async {
    final raw = await rootBundle.loadString(_learningCsvPath);
    final rows = const CsvToListConverter(eol: '\n').convert(raw);
    if (rows.length < 2) return const [];
    final header = rows.first.map((e) => '$e'.trim().toLowerCase()).toList();
    final typeIdx = header.indexOf('type');
    final jpIdx = header.indexOf('jp');
    final hiraIdx = header.indexOf('hiragana');
    final korIdx = header.indexOf('kor');
    final korPronIdx = header.indexOf('kor_pronunciation');
    final hiraDisplayIdx = header.indexOf('hiragana_display');
    if (typeIdx < 0 ||
        jpIdx < 0 ||
        hiraIdx < 0 ||
        korIdx < 0 ||
        korPronIdx < 0 ||
        hiraDisplayIdx < 0) {
      throw const FormatException(
        'basic_learning.csv 헤더에 type, jp, hiragana, kor, kor_pronunciation, hiragana_display가 필요합니다.',
      );
    }

    final out = <_LearningRow>[];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      String valueAt(int idx) => idx < row.length ? '${row[idx]}'.trim() : '';
      final type = valueAt(typeIdx);
      final jp = valueAt(jpIdx);
      final kor = valueAt(korIdx);
      if (type.isEmpty || jp.isEmpty || kor.isEmpty) continue;
      final hiraDisplayRaw = valueAt(hiraDisplayIdx).toLowerCase();
      out.add(
        _LearningRow(
          type: type,
          jp: jp,
          hiragana: valueAt(hiraIdx),
          kor: kor,
          korPronunciation: valueAt(korPronIdx),
          hiraganaDisplay: hiraDisplayRaw == 'true',
        ),
      );
    }
    return out;
  }

  @override
  void dispose() {
    _kindScrollController.dispose();
    super.dispose();
  }

  void _focusSelectedKindChip(_LearningKind kind) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final key = _kindButtonKeys[kind];
      final targetContext = key?.currentContext;
      if (targetContext == null) return;
      Scrollable.ensureVisible(
        targetContext,
        alignment: 0.5,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Widget _buildKindSelector(ThemeData theme) {
    return SingleChildScrollView(
      controller: _kindScrollController,
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _LearningKind.values.map((k) {
          final selected = k == _selectedKind;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              key: _kindButtonKeys[k],
              selected: selected,
              label: Text(_kindLabels[k]!),
              labelStyle: theme.textTheme.labelLarge?.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected
                    ? theme.colorScheme.onSecondaryContainer
                    : theme.colorScheme.onSurface,
              ),
              selectedColor: theme.colorScheme.secondaryContainer,
              side: BorderSide(
                color: selected
                    ? theme.colorScheme.secondary.withValues(alpha: 0.55)
                    : theme.colorScheme.outline.withValues(alpha: 0.35),
              ),
              onSelected: (_) {
                if (k == _selectedKind) {
                  _focusSelectedKindChip(k);
                  return;
                }
                setState(() => _selectedKind = k);
                _focusSelectedKindChip(k);
              },
            ),
          );
        }).toList(growable: false),
      ),
    );
  }

  Widget _buildKanaSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '기본 문자표',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '히라가나와 가타카나를 행별로 확인할 수 있습니다.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
          ),
        ),
        const SizedBox(height: 12),
        _KanaTableCard(
          title: '히라가나',
          rows: _hiraganaRows,
        ),
        const SizedBox(height: 12),
        _KanaTableCard(
          title: '가타카나',
          rows: _katakanaRows,
        ),
      ],
    );
  }

  Widget _buildLearningSections(ThemeData theme, List<_LearningRow> allRows) {
    if (_selectedKind == _LearningKind.kana) {
      return _buildKanaSection(theme);
    }
    final types = _kindTypes[_selectedKind]!;
    final sections = types
        .map((t) => MapEntry(t, allRows.where((r) => r.type == t).toList()))
        .where((e) => e.value.isNotEmpty)
        .toList(growable: false);
    if (sections.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '해당 학습 데이터가 없습니다.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _kindLabels[_selectedKind]!,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        ...sections.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _LearningTableCard(
              title: _typeLabels[e.key] ?? e.key,
              rows: e.value,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book, color: theme.colorScheme.onSurface),
            const SizedBox(width: 8),
            const Text('학습'),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          _buildKindSelector(theme),
          const SizedBox(height: 14),
          FutureBuilder<List<_LearningRow>>(
            future: _learningFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '학습 데이터를 불러오지 못했습니다.\n${snapshot.error}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                );
              }
              final rows = snapshot.data ?? const <_LearningRow>[];
              return _buildLearningSections(theme, rows);
            },
          ),
        ],
      ),
    );
  }
}

class _LearningTableCard extends StatelessWidget {
  const _LearningTableCard({
    required this.title,
    required this.rows,
  });

  final String title;
  final List<_LearningRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Table(
              border: TableBorder.all(
                color: theme.dividerColor.withValues(alpha: 0.6),
                width: 0.7,
              ),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              columnWidths: const {
                0: FlexColumnWidth(1.2),
                1: FlexColumnWidth(1.2),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.4,
                    ),
                  ),
                  children: const [
                    _TableCellText('일본어', bold: true),
                    _TableCellText('뜻 / 발음', bold: true),
                  ],
                ),
                ...rows.map((row) => _learningRow(context, row)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  TableRow _learningRow(BuildContext context, _LearningRow row) {
    final showHira = row.hiraganaDisplay && row.hiragana.trim().isNotEmpty;
    final jpValue = showHira ? '${row.jp}\n${row.hiragana}' : row.jp;
    final korPron = row.korPronunciation.trim();
    final korValue = korPron.isEmpty ? row.kor : '${row.kor}\n$korPron';
    return TableRow(
      children: [
        _TableCellText(jpValue),
        _TableCellText(korValue),
      ],
    );
  }
}

class _KanaTableCard extends StatelessWidget {
  const _KanaTableCard({
    required this.title,
    required this.rows,
  });

  final String title;
  final List<_KanaLine> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Table(
              border: TableBorder.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.6),
                width: 0.7,
              ),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              columnWidths: const {
                0: FixedColumnWidth(44),
                1: FlexColumnWidth(),
                2: FlexColumnWidth(),
                3: FlexColumnWidth(),
                4: FlexColumnWidth(),
                5: FlexColumnWidth(),
              },
              children: [
                _headerRow(context),
                ...rows.map((line) => _bodyRow(context, line)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  TableRow _headerRow(BuildContext context) {
    return TableRow(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      ),
      children: const [
        _TableCellText('행', bold: true),
        _TableCellText('아', bold: true),
        _TableCellText('이', bold: true),
        _TableCellText('우', bold: true),
        _TableCellText('에', bold: true),
        _TableCellText('오', bold: true),
      ],
    );
  }

  TableRow _bodyRow(BuildContext context, _KanaLine line) {
    return TableRow(
      children: [
        _TableCellText(line.rowLabel, bold: true),
        ...line.cells.map(
          (cell) => _TableCellText(
            cell == null ? '-' : '${cell.jp}\n${cell.ko}',
          ),
        ),
      ],
    );
  }
}

class _TableCellText extends StatelessWidget {
  const _TableCellText(this.value, {this.bold = false});

  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              height: 1.15,
              fontSize: 12,
            ),
      ),
    );
  }
}
