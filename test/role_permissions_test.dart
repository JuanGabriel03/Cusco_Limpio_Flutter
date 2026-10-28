import 'package:flutter_test/flutter_test.dart';
import 'package:cusco_limpio_flutter/main.dart';

void main() {
 test('Los reportes serializados conservan el ciudadano que los registró', () {
  final r=demoReports().first;
  final restored=CleanReport.fromJson(r.toJson());
  expect(restored.id,r.id);
  expect(restored.createdBy,r.createdBy);
  expect(restored.createdAt,r.createdAt);
 });
 test('Todos los roles son distintos', () {
  expect(UserRole.values.length,4);
  expect(roleName(UserRole.admin),isNot(roleName(UserRole.municipal)));
  expect(roleName(UserRole.citizen),'Ciudadano');
 });
 test('La ruta enlaza incidencias pendientes de la brigada', () {
  for(final route in demonstrationRoutes){
   final line=routeWithReports(route,demoReports());
   for(final r in demoReports().where((r)=>r.collector==route.brigade&&r.status!='Solucionado')){
    expect(line.any((p)=>p.latitude==r.lat&&p.longitude==r.lng),isTrue);
   }
  }
 });
}
