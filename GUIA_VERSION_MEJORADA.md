# Cusco Limpio — edición mejorada de demostración

## Qué se incorporó
- Nueva pestaña **Rutas** para Ciudadano, Municipalidad y Recolector, con tres corredores ilustrativos, brigadas, días, horas, paradas numeradas y puntos de incidencias asignadas.
- Historial de **reportes fechados** con siete registros ficticios del 12 al 24 de octubre de 2026. Los reportes nuevos registran fecha y hora actuales.
- Tarjeta de actividad reciente en Inicio y fechas en el listado/detalle de reportes.
- Conservación de sesión local, registro, roles, fotografía, geolocalización, asignación de brigadas, seguimiento y almacenamiento del prototipo original.
- Un método de datos retrocompatible: los reportes guardados antes de la mejora, que no tenían fecha, reciben una fecha de referencia claramente demostrativa.
- Fotografías codificadas para la web cuando se usa un navegador (sujeto a restricciones de compatibilidad del proyecto con dart:io; no hay garantía de compilación web).

## Importante para exponer
**TODOS LOS DATOS DE MUESTRA, FECHAS, HORARIOS Y RECORRIDOS SON SIMULADOS**. Los recorridos se dibujan mediante coordenadas de referencia y NO se ajustan a calles usando un motor de rutas, ni han sido validados con el municipio. No son aptos para guiar vehículos reales. Para eso se requiere un motor de enrutamiento vial, validación de restricciones de tránsito y datos oficiales.

## Instalación Android Studio
1. Crea un proyecto nuevo Flutter llamado `cusco_limpio` o usa tu proyecto actual.
2. Copia `lib/`, `assets/`, `test/` y `pubspec.yaml` a tu proyecto. Reemplaza los archivos correspondientes, conservando la carpeta `android/` generada por Flutter.
3. Revisa `configuracion_android/PERMISOS.xml` e incorpora los permisos necesarios antes de `<application>` en `android/app/src/main/AndroidManifest.xml`; no reemplaces el Manifest completo.
4. En terminal: `flutter pub get`, `flutter analyze`, `flutter run`.
5. Si no se ven los datos demostrativos después de instalar, accede como Municipalidad y usa **Restaurar demostración**. Esto BORRA los cambios locales; hazlo únicamente si no necesitas conservar los reportes anteriores.

## Accesos de demostración
Consulta `lib/auth.dart` y el README original para cuentas demo. No uses datos reales ni las credenciales demo para producción.

## Limitaciones conocidas
- Persistencia exclusiva en SharedPreferences del dispositivo; sin BD remota ni sincronización entre teléfonos.
- Sin notificaciones push, seguimiento GPS continuo, optimización por calles ni verificación real de rutas.
- Las coordenadas/rutas de ejemplo son aproximadas. El mapa necesita internet.
- `dart:io` se utiliza en el código original de las fotos Android y podría impedir compilar web; se necesita una refactorización de la capa de archivos para soporte web garantizado.
- No se dispone de la rúbrica exacta del docente para certificar puntuaciones o criterios específicos.
- No se ejecutaron `flutter analyze` ni pruebas en este entorno (SDK Flutter no instalado). Validar al abrir en Android Studio.


**Actualización visual:** se eliminó el aviso amarillo repetitivo; se extendieron las tres rutas a ocho paradas cada una. Ver NOTAS_DATOS_Y_RUTAS.md para limitaciones.
