# Cusco Limpio Pro v3 — GPS y cámara ciudadana

## Cambios
- Nuevo reporte ciudadano con foto real mediante cámara o galería; imagen copiada al almacenamiento privado de la app.
- En Mapa y Nuevo reporte: tarjeta con **Mi ubicación**, **Activar GPS** y **Permisos de app** (abre ajustes Android).
- Nuevos permisos de cámara y ubicación declarados durante preparación del proyecto.
- Reportes con fotos existentes permanecen compatibles; los nuevos pueden usar fotos locales.

## Instalación
1. Extrae ZIP en otra carpeta y ejecuta `powershell -ExecutionPolicy Bypass -File .\PREPARAR_ANDROID.ps1` en Windows.
2. Abre la carpeta raíz en Android Studio y ejecuta en tu teléfono Android, **no Windows**.
3. Si ya tienes un proyecto Android con `android/` creado, conserva su configuración y agrega permisos ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION, INTERNET y CAMERA en `android/app/src/main/AndroidManifest.xml`, fuera de `<application>`.
4. `flutter pub get`, `flutter analyze`, `flutter run -d <id>`.
5. La app solicita acceso al GPS al tocar **Mi ubicación**; Cámara se solicita al tomar una foto si el sistema lo requiere.

## Nota importante
Es una demostración local, no producción. La foto se guarda en el directorio privado de la app. No hay almacenamiento compartido, roles verificados en servidor ni sincronización entre dispositivos. Puntos de recolección demostrativos, no oficiales.
