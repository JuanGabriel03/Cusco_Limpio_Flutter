# Cusco Limpio — Perfiles diferenciados

## Corrección principal
Antes, la cuenta `admin@demo.pe` utilizaba internamente el perfil municipal. Ahora `UserRole.admin` es independiente y presenta pantallas exclusivas.

| Cuenta | Inicio | Última pestaña | Acciones |
| --- | --- | --- | --- |
| `ana@demo.pe` | Bienvenida ciudadana | Mi cuenta | Registrar incidencias y fotos |
| `municipal@demo.pe` | Centro de operaciones | Gestión | Asignar brigadas, actualizar estados y restablecer información local |
| `recolector@demo.pe` | Mi jornada de recolección | Mis puntos | Consultar asignaciones y marcar atención |
| `admin@demo.pe` | Centro de supervisión (azul) | Supervisión | Consultar estados, indicadores y cobertura por brigada, sin alterar asignaciones |

Contraseña de prueba de las cuentas: `Demo2026!`.

## Diferencia de responsabilidades
- **Administrador** audita y supervisa; su panel es de lectura y no incluye formularios para cambiar brigadas o estados.
- **Municipalidad** opera incidencias y asignaciones; sus cambios continúan en almacenamiento local.
- **Recolector** atiende tareas de su brigada.
- **Ciudadano** puede enviar reportes y consultar su cuenta.

El código de la separación está en `lib/main.dart`: `UserRole`, `AppShell`, `AdminHome`, `AdminDashboard`, `ManagementView`, `CollectorView`, `AccountView`.

## Validación recomendada
Desde Android Studio:
```
flutter pub get
flutter analyze
flutter test
flutter run
```
Inicia sesión por separado con las cuatro cuentas; verifica que el Administrador vea **Supervisión** y Municipalidad vea **Gestión**. Si alteras asignaciones como Municipalidad, regresa al Administrador y comprueba la actualización de sus indicadores.

**Límite importante:** la autenticación y el almacenamiento son locales de práctica. No representan autorización segura del lado del servidor. Los recorridos y datos iniciales no son oficiales y no se calculan siguiendo calles reales.
