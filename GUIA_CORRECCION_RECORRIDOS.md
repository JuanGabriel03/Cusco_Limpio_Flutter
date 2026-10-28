# Corrección: marcadores fuera del recorrido

## Causa
En la versión anterior la línea de cada brigada utilizaba una lista fija de coordenadas y los marcadores de reportes utilizaban coordenadas independientes. Las asignaciones nuevas podían verse fuera de la línea.

## Solución
La función `routeWithReports(route, reports)` incorpora las coordenadas **exactas** de todos los reportes activos asignados a la brigada dentro de su polilínea. Se usa tanto en `CollectorView` como en `RoutesView`. Si Gestión municipal reasigna un reporte, se recalcula el trazado a partir de los datos actualizados. Los reportes solucionados no se muestran como pendientes de recorrido.

En **Mis puntos**, pulsa **Ver ruta completa** para que el mapa encuadre el recorrido y todas las incidencias. En **Rutas**, utiliza **Ajustar recorrido**.

## Alcance y límites
Las líneas conectan paradas mediante segmentos aproximados y no son instrucciones de navegación calle por calle. Para rutas viales fiables debe añadirse un proveedor de cálculo de rutas sobre red de calles y verificar restricciones vehiculares. Los datos precargados son ejemplos, no reportes oficiales.

## Validación

```powershell
flutter clean
flutter pub get
flutter analyze
flutter test
flutter run
```

Se agregaron pruebas en `test/widget_test.dart` para comprobar que cada reporte activo de una brigada está en la polilínea, que los reportes nuevos se incorporan y que los resueltos no se insertan.

### Si el teléfono conserva datos anteriores
Los reportes se almacenan con SharedPreferences. Las asignaciones existentes seguirán guardadas y la ruta las incorporará automáticamente. No hace falta borrar los reportes.

## Ajuste de los datos iniciales
Se trasladó la incidencia de Santiago (`CUS-00259`) a Brigada 03, que recorre ese sector, y se asignó la incidencia del Centro Histórico (`CUS-00260`) a Brigada 01. Las instalaciones que ya tienen reportes guardados conservan sus asignaciones y aun así incorporan sus puntos a la línea verde. Para usar las nuevas asignaciones iniciales, restaura los datos desde Gestión municipal (esto borra cambios locales).
