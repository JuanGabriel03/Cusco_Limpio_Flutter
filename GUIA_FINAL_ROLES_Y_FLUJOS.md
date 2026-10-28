# CUSCO LIMPIO — Roles y flujos operativos (octubre de 2026)

## Distribución de responsabilidades

**Ciudadano**: crea su cuenta, inicia sesión, registra incidencia con fotografía, descripción y coordenadas, consulta mapa y el estado de los reportes personales. En la lista personal se incluyen los registros históricos precargados como referencia académica. No asigna trabajadores, no modifica estados ni gestiona otros usuarios.

**Administrador del sistema**: abre el panel azul, revisa indicadores y auditoría, busca cuentas, cambia el rol de una cuenta existente, asigna cada usuario recolector a una brigada y habilita/deshabilita cuentas. Se impide quitar el propio acceso administrativo o desactivarse. No modifica directamente prioridades o asignaciones de incidencias.

**Municipalidad / coordinación de limpieza pública**: realiza triaje operativo, asigna brigada por reporte, establece prioridad, cambia el estado y escribe notas de atención. Consulta rutas, reportes y ubicación. No crea ni desactiva usuarios.

**Recolector**: consulta exclusivamente los reportes asignados a su brigada, visualiza el recorrido con los marcadores en la línea, consulta GPS y marca el punto como atendido. Al atender, el reporte pasa a «En verificación»: la Municipalidad decide si se cierra como «Solucionado». No cambia la brigada de otros equipos ni las prioridades.

## Flujo completo de ejemplo

1. Ciudadano entra y crea un reporte con foto + coordenadas.
2. Municipalidad revisa el reporte sin brigada, establece prioridad, escribe observaciones y asigna una brigada.
3. El recolector de esa brigada ve el punto dentro de su ruta y lo marca atendido.
4. El estado cambia a «En verificación» y Municipalidad puede marcarlo «Solucionado» después de revisar.
5. Administrador consulta la bitácora y revisa/actualiza las cuentas locales.

## Persistencia y arquitectura

`lib/auth.dart`: cuentas, hash de contraseña para ejercicio local, gestión de usuarios y perfiles.
`lib/main.dart`: reportes, persistencia, pantallas y mapas, gestión municipal, auditoría, panel administrativo y recolector.
`test/widget_test.dart`: pruebas de datos y rutas.
`test/role_permissions_test.dart`: pruebas de serialización, nomenclatura de roles y conexión de incidencias con recorrido.
`.github/workflows/flutter_ci.yml`: CI para análisis y pruebas tras cada push o pull request.

**Limitaciones relevantes**: No hay servidor ni base central; los cambios no se sincronizan entre teléfonos. Cambiar el rol o deshabilitar una cuenta es una operación de demostración dentro del mismo dispositivo. No sustituye autorización del lado del servidor. Las rutas conectan puntos, pero no siguen obligatoriamente calles transitables. Para una operación oficial se requiere backend, permisos seguros, registros de auditoría en servidor, verificación municipal, georrutas viales y protección de información personal.

## Cómo instalar en el proyecto Android Studio existente

1. Hacer copia de seguridad del proyecto y guardar o exportar los reportes que necesites.
2. Descomprimir el ZIP. Copiar `lib`, `assets`, `test`, `.github` y `pubspec.yaml` sobre el proyecto Flutter existente. Conservar `android`, `ios` y otros proyectos de plataforma generados por Android Studio.
3. Ejecutar `flutter pub get`, `flutter analyze`, `flutter test`, `flutter run`.
4. Iniciar sesión con cada rol para demostrar su menú y permisos.
5. Para Git: `git status`, `git add -A`, `git commit -m "Paneles y roles operativos completos"`, `git push origin main`.

## Aclaración de calidad

El código fue inspeccionado y el ZIP fue verificado. Aquí no se dispone de un SDK Flutter para compilar ni ejecutar la aplicación y la ejecución exitosa de GitHub Actions no está garantizada hasta que se suba al repositorio.
