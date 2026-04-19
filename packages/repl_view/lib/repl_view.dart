/// Generic REPL-style scroll view for Flutter.
///
/// Input lines pin as sticky section headers; response lines scroll as
/// leaves within each section. Repeated identical responses coalesce
/// upstream and arrive with a [ConsoleEntry.count] greater than 1.
library;

export 'src/console_entry.dart';
export 'src/repl_view.dart';
