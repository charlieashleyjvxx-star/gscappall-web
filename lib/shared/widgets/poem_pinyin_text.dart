import 'package:flutter/material.dart';

import '../../domain/poem.dart';

enum PoemPinyinTextVariant { detail, study, preview, list }

class PoemPinyinText extends StatelessWidget {
  const PoemPinyinText({
    super.key,
    required this.poem,
    this.lineIndices,
    this.textStyle,
    this.pinyinStyle,
    this.lineSpacing = 12,
    this.characterSpacing = 2,
    this.alignment = Alignment.center,
    this.showPinyin = true,
    this.compact = false,
    this.maxVisibleLines,
    this.variant = PoemPinyinTextVariant.study,
  });

  final Poem poem;
  final List<int>? lineIndices;
  final TextStyle? textStyle;
  final TextStyle? pinyinStyle;
  final double lineSpacing;
  final double characterSpacing;
  final AlignmentGeometry alignment;
  final bool showPinyin;
  final bool compact;
  final int? maxVisibleLines;
  final PoemPinyinTextVariant variant;

  @override
  Widget build(BuildContext context) {
    final segments = _buildDisplaySegments(poem, lineIndices);
    final visibleSegments =
        maxVisibleLines == null
            ? segments
            : segments
                .take(maxVisibleLines!.clamp(0, segments.length))
                .toList(growable: false);

    final typography = _PoemTypography.resolve(
      poem: poem,
      segments: segments,
      variant: variant,
      compact: compact,
    );
    final effectiveTextStyle =
        textStyle ??
        Theme.of(context).textTheme.titleLarge?.copyWith(
          fontSize: typography.textFontSize,
          height: typography.textHeight,
          fontWeight: typography.fontWeight,
        );
    final effectivePinyinStyle =
        pinyinStyle ??
        Theme.of(context).textTheme.labelSmall?.copyWith(
          color: const Color(0xFF8A6A31),
          height: 1,
          fontSize: typography.pinyinFontSize,
          letterSpacing: 0,
          fontWeight: FontWeight.w600,
        );
    final effectiveLineSpacing =
        lineSpacing == 12
            ? typography.lineSpacing
            : (compact ? lineSpacing.clamp(4.0, 8.0) : lineSpacing);
    final effectiveCharacterSpacing =
        characterSpacing == 2
            ? typography.characterSpacing
            : (compact ? characterSpacing.clamp(0.0, 1.0) : characterSpacing);
    final scaleLinesToFit = variant != PoemPinyinTextVariant.list;

    return Semantics(
      container: true,
      readOnly: true,
      label: visibleSegments.map((segment) => segment.text).join(' '),
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final uniformScale =
                scaleLinesToFit
                    ? _uniformLineScale(
                      maxWidth: constraints.maxWidth,
                      segments: visibleSegments,
                      textStyle: effectiveTextStyle,
                      characterSpacing: effectiveCharacterSpacing,
                      compact: compact,
                    )
                    : 1.0;
            final scaledTextStyle = _scaledStyle(
              effectiveTextStyle,
              uniformScale,
            );
            final scaledPinyinStyle = _scaledStyle(
              effectivePinyinStyle,
              uniformScale,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (
                  var visibleIndex = 0;
                  visibleIndex < visibleSegments.length;
                  visibleIndex++
                )
                  Padding(
                    padding: EdgeInsets.only(
                      bottom:
                          visibleIndex == visibleSegments.length - 1
                              ? 0
                              : effectiveLineSpacing,
                    ),
                    child: Align(
                      alignment: alignment,
                      child: _PinyinLine(
                        text: visibleSegments[visibleIndex].text,
                        pinyin: visibleSegments[visibleIndex].pinyin,
                        showPinyin: showPinyin,
                        textStyle: scaledTextStyle,
                        pinyinStyle: scaledPinyinStyle,
                        characterSpacing:
                            effectiveCharacterSpacing * uniformScale,
                        compact: compact,
                        alignment: alignment,
                        scaleToFit: scaleLinesToFit,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<_PoemLineSegment> _buildDisplaySegments(
    Poem poem,
    List<int>? selectedLineIndices,
  ) {
    final lines = poem.lines;
    final sourceIndices =
        selectedLineIndices ??
        List<int>.generate(lines.length, (index) => index, growable: false);
    final textParts = <String>[];
    for (final lineIndex in sourceIndices) {
      if (lineIndex < 0 || lineIndex >= lines.length) {
        continue;
      }
      textParts.addAll(_splitTextByPunctuation(lines[lineIndex], variant));
    }
    if (textParts.isEmpty) {
      return [const _PoemLineSegment(text: '', pinyin: '')];
    }

    final tokens = _pinyinTokensFor(poem, sourceIndices);
    var tokenIndex = 0;
    return textParts
        .map((part) {
          final count = _cjkCount(part);
          final partTokens = tokens
              .skip(tokenIndex)
              .take(count)
              .toList(growable: false);
          tokenIndex = (tokenIndex + count).clamp(0, tokens.length);
          return _PoemLineSegment(text: part, pinyin: partTokens.join(' '));
        })
        .toList(growable: false);
  }

  List<String> _splitTextByPunctuation(
    String line,
    PoemPinyinTextVariant variant,
  ) {
    final trimmedLine = line.trim();
    if (variant == PoemPinyinTextVariant.list || _cjkCount(trimmedLine) <= 4) {
      return trimmedLine.isEmpty ? const <String>[] : <String>[trimmedLine];
    }

    final textParts = <String>[];
    final buffer = StringBuffer();
    for (final rune in line.runes) {
      buffer.write(String.fromCharCode(rune));
      if (_isLineBreakPunctuation(rune)) {
        final part = buffer.toString().trim();
        if (part.isNotEmpty) {
          textParts.add(part);
        }
        buffer.clear();
      }
    }
    final tail = buffer.toString().trim();
    if (tail.isNotEmpty) {
      textParts.add(tail);
    }
    return textParts;
  }

  List<String> _pinyinTokensFor(Poem poem, List<int> sourceIndices) {
    final lines = poem.lines;
    final pinyinLines = poem.pinyinLines;
    final selectedPinyinLines =
        pinyinLines.length == lines.length
            ? [
              for (final lineIndex in sourceIndices)
                if (lineIndex >= 0 && lineIndex < pinyinLines.length)
                  pinyinLines[lineIndex],
            ]
            : pinyinLines;
    return selectedPinyinLines
        .join(' ')
        .split(RegExp(r'\s+'))
        .where((token) => token.trim().isNotEmpty)
        .toList(growable: false);
  }

  int _cjkCount(String text) {
    return text.runes.where(_isCjkRune).length;
  }

  bool _isLineBreakPunctuation(int rune) {
    return const {
      0xFF0C, // ，
      0x3002, // 。
      0xFF1F, // ？
      0xFF01, // ！
      0xFF1B, // ；
      0xFF1A, // ：
      0x002C, // ,
      0x002E, // .
      0x003F, // ?
      0x0021, // !
      0x003B, // ;
      0x003A, // :
    }.contains(rune);
  }

  double _uniformLineScale({
    required double maxWidth,
    required List<_PoemLineSegment> segments,
    required TextStyle? textStyle,
    required double characterSpacing,
    required bool compact,
  }) {
    if (maxWidth.isInfinite || segments.isEmpty) {
      return 1;
    }

    final fontSize = textStyle?.fontSize ?? 22;
    final cellWidth = _characterCellWidthFor(fontSize, compact);
    var widestLine = 0.0;
    for (final segment in segments) {
      final slotCount = segment.text.runes.length;
      if (slotCount == 0) {
        continue;
      }
      final lineWidth =
          slotCount * cellWidth + (slotCount - 1) * characterSpacing;
      if (lineWidth > widestLine) {
        widestLine = lineWidth;
      }
    }
    if (widestLine <= 0 || widestLine <= maxWidth) {
      return 1;
    }
    return maxWidth / widestLine;
  }

  TextStyle? _scaledStyle(TextStyle? style, double scale) {
    if (style == null || scale == 1) {
      return style;
    }
    final fontSize = style.fontSize;
    if (fontSize == null) {
      return style;
    }
    return style.copyWith(fontSize: fontSize * scale);
  }
}

class _PoemLineSegment {
  const _PoemLineSegment({required this.text, required this.pinyin});

  final String text;
  final String pinyin;
}

class _PoemTypography {
  const _PoemTypography({
    required this.textFontSize,
    required this.pinyinFontSize,
    required this.lineSpacing,
    required this.characterSpacing,
    required this.textHeight,
    required this.fontWeight,
  });

  final double textFontSize;
  final double pinyinFontSize;
  final double lineSpacing;
  final double characterSpacing;
  final double textHeight;
  final FontWeight fontWeight;

  static _PoemTypography resolve({
    required Poem poem,
    required List<_PoemLineSegment> segments,
    required PoemPinyinTextVariant variant,
    required bool compact,
  }) {
    final effectiveVariant = compact ? PoemPinyinTextVariant.preview : variant;
    final isLyricLike = _isLyricLike(poem, segments);

    switch (effectiveVariant) {
      case PoemPinyinTextVariant.detail:
        return _PoemTypography(
          textFontSize: isLyricLike ? 23 : 28,
          pinyinFontSize: isLyricLike ? 11.5 : 12.5,
          lineSpacing: isLyricLike ? 14 : 18,
          characterSpacing: isLyricLike ? 1 : 2,
          textHeight: 1.22,
          fontWeight: FontWeight.w700,
        );
      case PoemPinyinTextVariant.study:
        return _PoemTypography(
          textFontSize: isLyricLike ? 22 : 26,
          pinyinFontSize: isLyricLike ? 11 : 12,
          lineSpacing: isLyricLike ? 12 : 16,
          characterSpacing: isLyricLike ? 1 : 2,
          textHeight: 1.2,
          fontWeight: FontWeight.w700,
        );
      case PoemPinyinTextVariant.preview:
        return _PoemTypography(
          textFontSize: isLyricLike ? 18 : 20,
          pinyinFontSize: 10.5,
          lineSpacing: 7,
          characterSpacing: 0,
          textHeight: 1.15,
          fontWeight: FontWeight.w600,
        );
      case PoemPinyinTextVariant.list:
        return _PoemTypography(
          textFontSize: 16,
          pinyinFontSize: 10,
          lineSpacing: 6,
          characterSpacing: 0,
          textHeight: 1.15,
          fontWeight: FontWeight.w600,
        );
    }
  }

  static bool _isLyricLike(Poem poem, List<_PoemLineSegment> segments) {
    if (poem.title.contains('·') || poem.lines.length > 4) {
      return true;
    }
    return segments.any((segment) => _cjkRuneCount(segment.text) > 9);
  }
}

class _PinyinLine extends StatelessWidget {
  const _PinyinLine({
    required this.text,
    required this.pinyin,
    required this.showPinyin,
    required this.textStyle,
    required this.pinyinStyle,
    required this.characterSpacing,
    required this.compact,
    required this.alignment,
    required this.scaleToFit,
  });

  final String text;
  final String pinyin;
  final bool showPinyin;
  final TextStyle? textStyle;
  final TextStyle? pinyinStyle;
  final double characterSpacing;
  final bool compact;
  final AlignmentGeometry alignment;
  final bool scaleToFit;

  @override
  Widget build(BuildContext context) {
    if (!showPinyin) {
      return LayoutBuilder(
        builder:
            (context, constraints) => _LineViewport(
              alignment: alignment,
              maxWidth: constraints.maxWidth,
              scaleToFit: scaleToFit,
              child: Text(
                text,
                style: textStyle,
                textAlign: _textAlignFor(context),
                softWrap: false,
              ),
            ),
      );
    }

    final tokens = pinyin
        .split(RegExp(r'\s+'))
        .where((token) => token.trim().isNotEmpty)
        .toList(growable: false);
    var tokenIndex = 0;
    final characters = [
      for (final rune in text.runes)
        _PinyinCharacter(
          character: String.fromCharCode(rune),
          pinyin:
              _isCjk(rune) && tokenIndex < tokens.length
                  ? _normalizePinyinToken(tokens[tokenIndex++])
                  : '',
          textStyle: textStyle,
          pinyinStyle: pinyinStyle,
          width: _characterCellWidth(context),
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        return _LineViewport(
          alignment: alignment,
          maxWidth: constraints.maxWidth,
          scaleToFit: scaleToFit,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var index = 0; index < characters.length; index++) ...[
                if (index > 0) SizedBox(width: characterSpacing),
                characters[index],
              ],
            ],
          ),
        );
      },
    );
  }

  TextAlign _textAlignFor(BuildContext context) {
    final value = alignment.resolve(Directionality.of(context));
    if (value.x <= -0.5) {
      return TextAlign.start;
    }
    if (value.x >= 0.5) {
      return TextAlign.end;
    }
    return TextAlign.center;
  }

  bool _isCjk(int rune) {
    return _isCjkRune(rune);
  }

  String _normalizePinyinToken(String token) {
    return token == 'é' ? 'e' : token;
  }

  double _characterCellWidth(BuildContext context) {
    final textFontSize =
        textStyle?.fontSize ??
        Theme.of(context).textTheme.titleLarge?.fontSize ??
        22;
    return _characterCellWidthFor(textFontSize, compact);
  }
}

double _characterCellWidthFor(double textFontSize, bool compact) {
  final multiplier = compact ? 1.85 : 2.25;
  final minimumWidth = compact ? 30.0 : 36.0;
  final maximumWidth = compact ? 46.0 : 60.0;
  return (textFontSize * multiplier).clamp(minimumWidth, maximumWidth);
}

bool _isCjkRune(int rune) {
  return (rune >= 0x4E00 && rune <= 0x9FFF) ||
      (rune >= 0x3400 && rune <= 0x4DBF);
}

int _cjkRuneCount(String text) {
  return text.runes.where(_isCjkRune).length;
}

class _LineViewport extends StatelessWidget {
  const _LineViewport({
    required this.child,
    required this.alignment,
    required this.maxWidth,
    required this.scaleToFit,
  });

  final Widget child;
  final AlignmentGeometry alignment;
  final double maxWidth;
  final bool scaleToFit;

  @override
  Widget build(BuildContext context) {
    final resolved = alignment.resolve(Directionality.of(context));
    final align = Alignment(resolved.x, resolved.y);
    if (!scaleToFit) {
      if (maxWidth.isInfinite) {
        return Align(alignment: align, child: child);
      }
      return SizedBox(
        width: maxWidth,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: child,
        ),
      );
    }
    if (maxWidth.isInfinite) {
      return FittedBox(fit: BoxFit.scaleDown, alignment: align, child: child);
    }
    return SizedBox(
      width: maxWidth,
      child: Align(
        alignment: align,
        child: FittedBox(fit: BoxFit.scaleDown, alignment: align, child: child),
      ),
    );
  }
}

class _PinyinCharacter extends StatelessWidget {
  const _PinyinCharacter({
    required this.character,
    required this.pinyin,
    required this.textStyle,
    required this.pinyinStyle,
    required this.width,
  });

  final String character;
  final String pinyin;
  final TextStyle? textStyle;
  final TextStyle? pinyinStyle;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: _pinyinHeight(context),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  pinyin,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  style: pinyinStyle,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          Text(character, style: textStyle, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  double _pinyinHeight(BuildContext context) {
    final fontSize =
        pinyinStyle?.fontSize ??
        Theme.of(context).textTheme.labelSmall?.fontSize ??
        12;
    return fontSize + 6;
  }
}
