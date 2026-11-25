# Diseño: Escáner de Código de Barras (Open Food Facts) y Optimización de IA

**Fecha:** 2026-11-25
**Proyecto:** `cal_scanner` (Flutter)

---

## 1. Propósito y Motivación

Reducir el consumo innecesario de llamadas a Gemini y aumentar la precisión nutricional separando claramente el flujo de **productos envasados** del flujo de **platillos**:

- Los productos con código de barras se resuelven con **0 llamadas de IA** usando caché local y **Open Food Facts** (gratuita y sin clave API extra).
- Gemini queda reservado para **platillos** (comidas preparadas), **lectura literal de tablas nutricionales** cuando un código no exista en la base de datos, y **productos sin código de barras** (apoyados por cruce híbrido con Open Food Facts).

---

## 2. Objetivos, No-Objetivos y Anti-Objetivos

### Objetivos
- **Menú `+` en abanico radial (3 opciones):** *Barcode*, *Camera* y *Manual*. Al pulsar *Camera*, las otras opciones se repliegan suavemente y el mismo abanico muestra *Take a Photo* y *Select a Photo*.
- **Escáner de código de barras en vivo** (`mobile_scanner`) conectado a:
  1. Caché local de productos por código EAN/UPC (instantáneo y offline).
  2. Open Food Facts API v2 (sin API key).
- **Respaldo sin fricción cuando un código no existe o tiene macros incompletos:** tarjeta sobre el escáner con *"Escanear tabla nutricional (IA)"* (prompt especializado solo en transcripción literal de etiquetas) y *"Ingresar manualmente"*. El resultado confirmado se guarda automáticamente en la caché local vinculado a ese código de barras.
- **Cruce híbrido para productos sin código de barras:** si en *Camera* Gemini identifica un producto comercial sin tabla nutricional visible (`is_packaged: true`, `label_visible: false`), la app realiza una búsqueda rápida (timeout ~3 s) en Open Food Facts por `brand + name` para sustituir la estimación por datos reales del fabricante si hay coincidencia válida.
- **Trazabilidad visual de origen:** mostrar en `ScanResultScreen` (y opcionalmente en el detalle) una etiqueta clara según la fuente: *Verified (Barcode)*, *Verified (Database Match)*, *Nutrition Label (AI)* o *Estimated (AI)*.

### No-Objetivos
- No pedir ni gestionar ninguna API key adicional (no se incluye USDA en esta fase).
- No incrustar bases de datos offline masivas dentro del APK.
- No reescribir `OnboardingScreen` ni `SettingsScreen` en esta fase.

### Anti-Objetivos
- Nunca dejar al usuario en un callejón sin salida si un código de barras no existe en Open Food Facts.
- Nunca añadir latencia al escaneo de platillos por culpa de búsquedas de productos envasados.
- No romper ninguno de los 12 tests unitarios actuales en `test/widget_test.dart`.

---

## 3. Enfoques Considerados

| Enfoque | Descripción | Pros | Contras | Decisión |
|---|---|---|---|---|
| **Enfoque 1: Separación directa** | Código de barras → OFF + Caché; Cámara → solo Gemini mejorado. | Muy simple y rápido (1 llamada por flujo). | Si se fotografía el frente de un producto sin código ni tabla visible, depende 100 % de la estimación de Gemini. | Descartado |
| **Enfoque 2: Híbrido inteligente** | Todo lo del Enfoque 1 + cruce rápido con Open Food Facts Search cuando Gemini detecta un producto comercial sin tabla visible. | Máxima precisión en los 3 escenarios (código, envase sin código y platillo), sin claves extra y sin afectar latencia en platillos. | Añade una pequeña capa de búsqueda por texto en OFF (~1–2 s solo en envases frontales sin etiqueta). | **Seleccionado** |

---

## 4. Diseño Detallado

### 4.1. Menú `+` en abanico radial (`HomeScreen`)
- Se sustituye la pila vertical actual por un **abanico radial animado** sobre el botón `+` central:
  - **Nivel 1 (3 botones en arco):**
    - Izquierda: **Barcode** (`Icons.qr_code_scanner_rounded`) → abre `BarcodeScannerScreen`.
    - Centro arriba: **Camera** (`CupertinoIcons.camera_fill`) → transiciona al Nivel 2.
    - Derecha: **Manual** (`Icons.edit_note_rounded`) → abre `ManualMealScreen`.
  - **Nivel 2 (al pulsar *Camera*):**
    - Las opciones *Barcode* y *Manual* se repliegan suavemente (`ScaleTransition` + `FadeTransition` + desplazamiento).
    - En el mismo abanico emergen **Take a Photo** y **Select a Photo** (eliminando el `showModalBottomSheet` separado).
    - Pulsar el botón central (`×`) o el fondo atenuado cierra el menú y resetea al Nivel 1.

### 4.2. Capa de Datos y Dominio

#### Entidad `Food` (`lib/features/calories/domain/entities/food.dart`) y `MealRecord` / `FoodModel`
Añadir campos opcionales retrocompatibles (con valores por defecto seguros para registros ya guardados):
- `String? barcode`: código EAN/UPC si el registro vino de un escáner.
- `String source`: `'barcode'` | `'database_match'` | `'ai_label'` | `'ai_estimate'` | `'manual'` (default `'manual'` o `'ai_estimate'`).

#### Caché local de códigos de barras en SQLite (`BarcodeCacheDataSource`)
- Base de datos SQLite local (`cal_scanner_barcodes.db`) mediante `sqflite` + `path`, con tabla `barcode_products` (`barcode TEXT PRIMARY KEY`, `payload TEXT`, `updated_at INTEGER`).
- Interfaz `BarcodeCacheDataSource` con implementación `SqliteBarcodeCacheDataSource` (y soporte para implementación en memoria en tests unitarios):
  - `Future<Food?> getProduct(String barcode)`
  - `Future<void> saveProduct(String barcode, Food product)`
- Sin límite práctico de 200 productos: soporta miles de productos con búsquedas instantáneas por clave primaria (`WHERE barcode = ?`).

#### Nuevo datasource `OpenFoodFactsDataSource` (`lib/features/calories/data/datasources/open_food_facts_datasource.dart`)
- Usa el mismo `http.Client` inyectado vía `GetIt` (fácil de mockear en tests).
- Incluye cabecera `User-Agent: CalScanner/1.0 (Flutter)` requerida por las guías de Open Food Facts.
- **Método 1 — `getProductByBarcode(String barcode)`:**
  - `GET https://world.openfoodfacts.org/api/v2/product/{barcode}.json?fields=product_name,product_name_es,product_name_en,brands,quantity,product_quantity,product_quantity_unit,serving_size,nutriments,image_front_small_url`
  - Timeout: 8 segundos.
  - Valida que `status == 1` y que existan valores numéricos de `energy-kcal_100g` (o `energy_100g / 4.184`).
  - Calcula las calorías y macros para el peso neto del envase (`product_quantity` + `product_quantity_unit`, o `100 g` por defecto) usando la misma fórmula `amount / 100.0` que ya usa la app, y construye 1 `FoodIngredient` para que el usuario pueda ajustar los gramos/ml en `ScanResultScreen` exactamente igual que hoy.
  - Si el producto existe pero no tiene macros, devuelve un resultado distinguible (p. ej. `ProductNotFound` con el `partialName` si lo hubiera) para prellenar el flujo de respaldo.
- **Método 2 — `searchProductByName(String query, {String? brand})`:**
  - `GET https://world.openfoodfacts.org/cgi/search.pl?search_terms=...&search_simple=1&action=process&json=1&page_size=5&fields=product_name,brands,nutriments,product_quantity,product_quantity_unit`
  - Timeout corto: 3.5 segundos.
  - Solo acepta una coincidencia si tiene `energy-kcal_100g` válido y el nombre/marca coincide razonablemente con lo detectado por Gemini; si falla o expira el timeout, devuelve `null` silenciosamente (nunca bloquea el flujo).

#### Optimización de `FoodRemoteDataSource` (Gemini)
- **Separación de intención en el prompt de imagen:**
  - Añadir un parámetro opcional `bool labelOnlyMode = false` en `detectFoodAndCalories(File imageFile, {String? userHint, bool labelOnlyMode = false})`.
  - Cuando `labelOnlyMode == true` (respaldo desde el escáner de código de barras): prompt ultra-enfocado en transcribir literalmente la tabla nutricional por 100 g / 100 ml y el peso neto del envase.
  - En modo normal (`labelOnlyMode == false`): añadir en el JSON de respuesta `"is_packaged": boolean` y `"brand": string or null` junto al `"label_visible": boolean` existente, y propagar `source` (`'ai_label'` si `label_visible == true`, `'ai_estimate'` si `false`).
- **Cruce híbrido en `FoodRepositoryImpl`:**
  - `lookupFoodByBarcode(String barcode)`: consulta `LocalStorageService` (caché) → `OpenFoodFactsDataSource.getProductByBarcode`. Si OFF responde con éxito, lo guarda en caché local y lo devuelve con `source: 'barcode'`.
  - `detectFoodFromImage(File image, {String? userHint, bool labelOnlyMode = false})`: llama a `FoodRemoteDataSource`. Si el resultado es un producto envasado sin tabla visible (`isPackaged && !labelVisible`), intenta `OpenFoodFactsDataSource.searchProductByName` (3.5 s máximo). Si encuentra macros reales por 100 g/ml, sustituye los valores por los de OFF (escalados al `amount` detectado) y marca `source: 'database_match'`.

### 4.3. Nueva pantalla `BarcodeScannerScreen` y reutilización de `ScanResultScreen`
- **`BarcodeScannerScreen` (`lib/features/calories/presentation/screens/barcode_scanner_screen.dart`):**
  - Vista de cámara a pantalla completa con `MobileScanner`, marco guía centrado, botón de linterna y botón atrás.
  - Debounce/bloqueo tras detectar un código (evita múltiples llamadas simultáneas por frame).
  - Mientras busca: indicador de carga compacto.
  - **Si encuentra producto:** navega a `ScanResultScreen` en modo pre-cargado (`initialFood: food`) para que el usuario ajuste la cantidad consumida (ej. 150 ml de un brick de 330 ml) y pulse *Log Meal*.
  - **Si NO encuentra producto (o falta información nutricional):** muestra una tarjeta modal limpia sobre el escáner con:
    - **"Scan Nutrition Label (AI)"** → abre cámara (`image_picker`, `1600×1600`, calidad `85`), lanza `ScanResultScreen` con `labelOnlyMode: true` y `associateBarcode: code`. Al confirmar/detectar el producto, lo guarda en la caché local bajo ese `barcode`.
    - **"Enter Manually"** → abre `ManualMealScreen` (con `initialName` y `associateBarcode: code` para cachearlo al guardar).
    - **"Scan Another"** → reactiva la lectura del escáner.
- **`ScanResultScreen`:**
  - Soporta recibir `Food? initialFood` (cuando viene de código de barras, sin disparar llamada a Gemini) además de `File? imageFile` (flujo actual de cámara).
  - Muestra una pequeña insignia de origen debajo del nombre del alimento (*Verified • Barcode*, *Verified • Open Food Facts*, *Nutrition Label • AI*, *Estimated • AI*).
  - Si `source == 'ai_estimate'` y es un producto sin tabla visible, muestra una nota sutil en la tarjeta de pista sugiriendo fotografiar la tabla nutricional para mayor exactitud.

### 4.4. Configuración Nativa y Dependencias
- **`pubspec.yaml`:** añadir `mobile_scanner`, `sqflite` y `path`.
- **`android/app/src/main/AndroidManifest.xml`:** añadir `<uses-permission android:name="android.permission.CAMERA" />`.
- **`android/app/build.gradle.kts`:** asegurar `minSdk = maxOf(flutter.minSdkVersion, 21)` compatible con `mobile_scanner`.

---

## 5. Decisiones tomadas por defecto (para tu revisión)
- Usar **`mobile_scanner`** como librería de escaneo (estándar actual en Flutter, soporta EAN-13/EAN-8/UPC-A/UPC-E, sin configuración de claves).
- Usar **SQLite (`sqflite` + `path`)** para la caché local de códigos de barras (sin tope de productos y con búsqueda indexada), manteniendo `UserProfile` y `meal_records` en `SharedPreferences` por ahora.
- Reutilizar **`ScanResultScreen`** para confirmar y ajustar la porción tanto de productos escaneados por código de barras como de fotos con IA, manteniendo una experiencia visual uniforme.

---

## 6. Verificación y Tests
- Mantener pasando los 12 tests existentes en `test/widget_test.dart`.
- Añadir tests unitarios para:
  - Parseo de respuesta válida e incompleta de `OpenFoodFactsDataSource`.
  - Flujo de caché local de códigos de barras (acierto en caché sin llamada HTTP).
  - Cruce híbrido (`is_packaged && !label_visible` → consulta a OFF Search y fallback seguro a Gemini si falla o tarda).
