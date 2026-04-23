import 'package:flutter/material.dart';

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

class LearningScreen extends StatelessWidget {
  const LearningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('학습')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '기본 문자표',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '일본어 문자와 한국어 발음을 순서대로 볼 수 있습니다.',
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
      ),
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
