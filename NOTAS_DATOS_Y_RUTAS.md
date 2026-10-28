# Datos y rutas: alcance real

- Los registros de fechas históricas y reportes precargados son datos de ejemplo, no datos públicos ni registros oficiales.
- Las tres rutas se ampliaron a 17–18 puntos de dibujo y ocho paradas por brigada. Son trazos aproximados conectados por segmentos; no siguen necesariamente calles ni sustituyen a un motor de enrutamiento.
- La app usa OpenStreetMap para obtener teselas del mapa, geolocator para posición del dispositivo, image_picker para fotografías, SharedPreferences para persistencia local.
- No existe backend ni sincronización multiusuario, navegación vial, ni seguimiento de vehículos en vivo.
- Para cargar datos iniciales nuevamente, ingresar como municipalidad y pulsar «Restablecer datos iniciales» (se pierden cambios locales).
- Se quitaron carteles extensos y repetitivos del interior de las pantallas. La naturaleza de los recorridos se conserva en una leyenda discreta, y sus limitaciones se explican aquí.
- Las pruebas automáticas agregadas requieren validación en un entorno con Flutter SDK (`flutter test`).
