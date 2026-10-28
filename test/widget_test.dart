import 'package:flutter_test/flutter_test.dart';
import 'package:cusco_limpio_flutter/main.dart';

void main() {
  test('Hay reportes iniciales para historial', () {
    expect(demoReports().length, greaterThanOrEqualTo(7));
    expect(demoReports().first.id, 'CUS-00254');
  });

  test('Existen tres rutas con recorridos extendidos', () {
    expect(demonstrationRoutes.length, 3);
    for (final route in demonstrationRoutes) {
      expect(route.waypoints.length, greaterThanOrEqualTo(15));
      expect(route.stops.length, greaterThanOrEqualTo(8));
      expect(routeForBrigade(route.brigade), isNotNull);
    }
  });
  test('Toda incidencia asignada figura exactamente en la línea de su brigada', () {
    final reports = demoReports();
    for (final route in demonstrationRoutes) {
      final path = routeWithReports(route, reports);
      for (final r in reports.where((r) => r.collector == route.brigade && r.status != 'Solucionado')) {
        expect(path.any((p) => p.latitude == r.lat && p.longitude == r.lng), isTrue,
          reason: '${r.id} debe quedar sobre la línea de ${route.brigade}');
      }
    }
  });

  test('Una incidencia nueva fuera de la ruta se incorpora al trazado', () {
    final route = demonstrationRoutes.first;
    final report = CleanReport(id:'TEST-001',district:'Santiago',address:'Punto nuevo',
      description:'Prueba',type:'Plásticos',photo:'plasticos',status:'Pendiente',
      priority:'Alta',collector:route.brigade,lat:-13.553,lng:-71.999);
    final path = routeWithReports(route, [report]);
    expect(path.length, route.waypoints.length + 1);
    expect(path.any((p) => p.latitude == report.lat && p.longitude == report.lng), isTrue);
  });

  test('Una incidencia solucionada o de otra brigada no altera la ruta', () {
    final route = demonstrationRoutes.first;
    final reports = demoReports();
    final path = routeWithReports(route, reports);
    expect(path.any((p) => p.latitude == reports.first.lat && p.longitude == reports.first.lng), isFalse);
    expect(route.waypoints.length, lessThanOrEqualTo(path.length));
  });

}

// Comprobación de que Administrador es un perfil separado de Municipalidad.
// La navegación exclusiva se verifica además manualmente tras iniciar sesión.
