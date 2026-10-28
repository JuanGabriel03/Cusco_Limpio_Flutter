import 'package:flutter_test/flutter_test.dart';
import 'package:cusco_limpio_flutter/main.dart';
void main(){test('Los reportes iniciales son demostrativos',(){expect(demoReports().length,7);expect(demoReports().first.id,'CUS-00254');});}
