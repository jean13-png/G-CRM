import 'package:csv/csv.dart';

void main() {
  const encoder = CsvEncoder(fieldDelimiter: ';');
  print(encoder.convert([['hello', 'world']]));
}
