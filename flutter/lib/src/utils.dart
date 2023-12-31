import 'dart:convert';

import 'package:stack_trace/stack_trace.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'illuminare_trace.dart';

final _obfuscatedStackTraceLineRegExp =
    RegExp(r'^(\s*#\d{2} abs )([\da-f]+)((?: virt [\da-f]+)?(?: .*)?)$');

/// Matches a stacktrace line as generated on Android/iOS devices.
/// For example:
/// #1      Logger.log (package:logger/src/logger.dart:115:29)
// ignore: unused_element
final _deviceStackTraceRegExp = RegExp(r'#[0-9]+[\s]+(.+) \(([^\s]+)\)');

/// Matches a stacktrace line as generated by Flutter web.
/// For example:
/// packages/logger/src/printers/pretty_printer.dart 91:37
final _webStackTraceRegExp = RegExp(
    r'^(?:(packages|dart-sdk)\/((?:\/?[^\s]+)+.dart))\s+(?:(\d+):(\d+))\s+([^\s]+)');

/// Matches a stacktrace line as generated by browser Dart.
/// For example:
/// dart:sdk_internal
/// package:logger/src/logger.dart
// ignore: unused_element
final _browserStackTraceRegExp = RegExp(r'^(?:package:)?(dart:[^\s]+|[^\s]+)');

/// Returns a [List] containing detailed output of each line in a stack trace.
List<IlluminareTrace> getStackTraceElements(StackTrace stackTrace) {
  final List<IlluminareTrace> elements = <IlluminareTrace>[];

  final Trace trace = Trace.parseVM(stackTrace.toString()).terse;

  for (final Frame frame in trace.frames) {
    if (frame is UnparsedFrame) {
      if (kIsWeb) {
        if (_webStackTraceRegExp.hasMatch(frame.member)) {
          final RegExpMatch match =
              _webStackTraceRegExp.firstMatch(frame.member)!;
          final element = IlluminareTrace(
            file:
                "${match.group(1)! == "packages" ? "package" : "dart"}:${match.group(2)}",
            line: int.tryParse(match.group(3)!),
            column: int.tryParse(match.group(4)!),
            method: match.group(5),
          );
          elements.add(element);
        }
      } else {
        if (_obfuscatedStackTraceLineRegExp.hasMatch(frame.member)) {
          final String method = frame.member.replaceFirstMapped(
              _obfuscatedStackTraceLineRegExp,
              (match) => '${match.group(1)}0${match.group(3)}');
          elements.add(IlluminareTrace(file: "", line: 0, method: method));
        }
      }
    } else {
      final IlluminareTrace element = IlluminareTrace(
        file: frame.library,
        line: frame.line ?? 0,
        column: frame.column ?? 0,
      );

      final String member = frame.member ?? '<fn>';
      final List<String> members = member.split('.');
      if (members.length > 1) {
        element.method = members.sublist(1).join('.');
        element.className = members.first;
      } else {
        element.method = member;
      }
      elements.add(element);
    }
  }

  return elements;
}

String stringifyMessage(dynamic message) {
  final finalMessage = message is Function ? message() : message;
  if (finalMessage is Map || finalMessage is Iterable) {
    const encoder = JsonEncoder.withIndent('  ', toEncodableFallback);
    return encoder.convert(finalMessage);
  } else {
    return finalMessage.toString();
  }
}

// Handles any object that is causing JsonEncoder() problems
Object toEncodableFallback(dynamic object) {
  return object.toString();
}
