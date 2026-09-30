# GastoClaro

GastoClaro es una aplicación web de **gestión de gastos familiares** hecha con Ruby on Rails. Cada grupo familiar registra sus ingresos y gastos (con detalle por ítem, comercio y canal de compra), define metas de ahorro, controla compras en cuotas y arma su lista de compras. Incluye un back-office web para administrar todo y una API JSON (v1) pensada para clientes externos, por ejemplo una app móvil.

**Stack:** Ruby 3.4.10, Rails 8.1, SQLite, Puma, Hotwire (Turbo + Stimulus) e importmap.

## Índice

1. [Requisitos e instalación](#requisitos-e-instalación)
2. [Back-office (panel de administración)](#back-office-panel-de-administración)
3. [API v1](#api-v1)
4. [Modelo de datos](#modelo-de-datos)
5. [Calidad y tests](#calidad-y-tests)
6. [Evolución futura](#evolución-futura)

## Requisitos e instalación

**Requisitos:** Git y [mise](https://mise.jdx.dev/) para manejar la versión de Ruby. El proyecto declara `ruby-3.4.10` en `.ruby-version`. SQLite viene incluido a través de la gema `sqlite3`.

```bash
git clone https://github.com/norali84g-wq/gastoclaro.git
cd gastoclaro

mise install ruby@3.4.10      # instala la versión de Ruby del proyecto
bundle install                # instala las gemas
bin/rails db:setup            # crea la base, carga el esquema y ejecuta los seeds
```

Si ya tenés la base creada y solo querés ponerla al día, usá `bin/rails db:prepare`.

Si `ruby -v` no muestra 3.4.10 en tu terminal, ejecutá los comandos con `mise exec -- <comando>` (por ejemplo `mise exec -- bin/rails server`) o activá mise en tu shell (`eval "$(mise activate bash)"`).

**Levantar el servidor de desarrollo:**

```bash
bin/rails server
```

La app queda en <http://localhost:3000>. En desarrollo, los mails que envía la app (por ejemplo el de felicitación al cumplir una meta de ahorro) se pueden ver en <http://localhost:3000/letter_opener>.

## Back-office (panel de administración)

- **URL de acceso:** <http://localhost:3000/admin/login>
- **Usuario de prueba** (lo crea `db/seeds.rb`, junto con el grupo familiar "Familia Gorosito"):

  | Usuario | Contraseña |
  |---------|------------|
  | `admin` | `admin1234` |

> **Solo para desarrollo.** Esta credencial está en el repositorio. No la uses en un entorno real: cambiá la contraseña o eliminá el usuario antes de publicar.

Solo pueden ingresar los usuarios con el flag `admin`. Una vez dentro, el back-office ofrece estas secciones (rutas bajo `/admin`): panel principal, gastos, ingresos, categorías, compras en cuotas, comercios (vendors), metas de ahorro, usuarios, lista de compras (con carga por lote), ahorro y estadísticas.

## API v1

La API devuelve y recibe JSON. Todas las rutas cuelgan de `/api/v1` y, salvo el login, requieren un token.

### Autenticación

1. Hacé `POST /api/v1/login` con `user` y `password`. La respuesta trae el `token` del usuario.
2. En cada request siguiente enviá el token en el header `Authorization`:

   ```
   Authorization: Bearer <TOKEN>
   ```

Sin token, o con un token inválido, la API responde `401` con `{ "error": "No autorizado" }`.

El token se genera una sola vez, cuando se crea el usuario, y **no vence ni se renueva**. Cada usuario tiene el suyo.

### Resumen de endpoints

| Método | Ruta | Requiere token | Descripción |
|--------|------|:--------------:|-------------|
| `POST` | `/api/v1/login` | No | Devuelve el token del usuario |
| `GET`  | `/api/v1/dashboard` | Sí | Resumen del mes actual y ahorro de los últimos 6 meses |
| `POST` | `/api/v1/incomes` | Sí | Registra un ingreso |
| `GET`  | `/api/v1/categories` | Sí | Lista las categorías |
| `GET`  | `/api/v1/expenses` | Sí | Lista los gastos del grupo familiar |
| `POST` | `/api/v1/expenses` | Sí | Registra un gasto |

Los ejemplos de abajo son respuestas reales, capturadas contra una instancia local con datos de prueba. El token que aparece es el de esa instancia descartable. En los ejemplos con `curl`, `<TOKEN>` es el valor que devolvió el login.

> **Formato de números:** los montos (`amount`, `unit_price`, `subtotal`, `ingreso`, etc.) se devuelven como **strings** decimales (por ejemplo `"450000.0"`), no como números JSON.

### `POST /api/v1/login`

Parámetros: `user`, `password`.

```bash
curl -X POST http://localhost:3000/api/v1/login \
  -H "Content-Type: application/json" \
  -d '{"user":"admin","password":"admin1234"}'
```

Respuesta `200`:

```json
{
  "token": "137c6fba817ace5f220542ca39382f7e5f912594",
  "user": "admin"
}
```

Con credenciales incorrectas, `401`:

```json
{ "error": "Usuario o contraseña incorrectos" }
```

### `GET /api/v1/dashboard`

Devuelve el resumen del **mes en curso** para el grupo familiar del usuario: ingresos, consumo, ahorro, consumo por categoría y la evolución de los últimos 6 meses con el ahorro acumulado. `meta_ahorro_porcentaje` es el porcentaje de ahorro definido para el grupo.

```bash
curl http://localhost:3000/api/v1/dashboard -H "Authorization: Bearer <TOKEN>"
```

Respuesta `200`:

```json
{
  "periodo": "2026-09",
  "ingreso": "450000.0",
  "consumo": "38101.0",
  "ahorro": "411899.0",
  "meta_ahorro_porcentaje": 10,
  "ingresos": [
    { "id": 1, "usuario": "admin", "amount": "450000.0", "date": "2026-09-01" }
  ],
  "consumo_por_categoria": [
    { "categoria": "Servicios", "total": "25000.0" },
    { "categoria": "Supermercado", "total": "13101.0" }
  ],
  "ahorro_mensual": [
    { "mes": "2026-04", "ingreso": "0.0", "consumo": "0.0", "ahorro": "0.0", "acumulado": "0.0" },
    { "mes": "2026-05", "ingreso": "0.0", "consumo": "0.0", "ahorro": "0.0", "acumulado": "0.0" },
    { "mes": "2026-06", "ingreso": "0.0", "consumo": "0.0", "ahorro": "0.0", "acumulado": "0.0" },
    { "mes": "2026-07", "ingreso": "0.0", "consumo": "0.0", "ahorro": "0.0", "acumulado": "0.0" },
    { "mes": "2026-08", "ingreso": "0.0", "consumo": "0.0", "ahorro": "0.0", "acumulado": "0.0" },
    { "mes": "2026-09", "ingreso": "450000.0", "consumo": "38101.0", "ahorro": "411899.0", "acumulado": "411899.0" }
  ]
}
```

### `POST /api/v1/incomes`

Parámetros: `amount` (mayor a 0) y `date`. El ingreso queda siempre a nombre del usuario autenticado; cualquier `user_id` que se envíe se ignora.

```bash
curl -X POST http://localhost:3000/api/v1/incomes \
  -H "Authorization: Bearer <TOKEN>" -H "Content-Type: application/json" \
  -d '{"amount":450000,"date":"2026-09-01"}'
```

Respuesta `201`:

```json
{ "id": 1, "amount": "450000.0", "date": "2026-09-01" }
```

Con datos inválidos (por ejemplo `amount: 0`), `422`:

```json
{ "errors": ["Amount must be greater than 0"] }
```

### `GET /api/v1/categories`

Lista todas las categorías ordenadas por nombre. Las categorías son globales, no dependen del grupo familiar.

```bash
curl http://localhost:3000/api/v1/categories -H "Authorization: Bearer <TOKEN>"
```

Respuesta `200`:

```json
[
  { "id": 3, "name": "Servicios",    "parent_id": null, "tracks_installments": null },
  { "id": 1, "name": "Supermercado", "parent_id": null, "tracks_installments": null },
  { "id": 2, "name": "Transporte",   "parent_id": null, "tracks_installments": null }
]
```

### `GET /api/v1/expenses`

Lista los gastos de **todo el grupo familiar** del usuario, del más reciente al más antiguo, con su categoría e ítems.

```bash
curl http://localhost:3000/api/v1/expenses -H "Authorization: Bearer <TOKEN>"
```

Respuesta `200`:

```json
[
  {
    "id": 2,
    "amount": "13101.0",
    "date": "2026-09-12",
    "description": "Compra semanal",
    "is_fixed": false,
    "purchase_channel": "presencial",
    "user_id": 1,
    "vendor_id": 1,
    "category": { "id": 1, "name": "Supermercado" },
    "expense_items": [
      { "id": 1, "name": "Leche", "quantity": 2, "unit": "unidad", "unit_price": "1800.5", "subtotal": "3601.0" },
      { "id": 2, "name": "Carne", "quantity": 1, "unit": "kg", "unit_price": "9500.0", "subtotal": "9500.0" }
    ]
  },
  {
    "id": 1,
    "amount": "25000.0",
    "date": "2026-09-05",
    "description": "Luz",
    "is_fixed": true,
    "purchase_channel": "presencial",
    "user_id": 1,
    "vendor_id": null,
    "category": { "id": 3, "name": "Servicios" },
    "expense_items": []
  }
]
```

### `POST /api/v1/expenses`

Parámetros: `date` y `category_id` son obligatorios, y `amount` es obligatorio si no se envían ítems. Opcionales: `description`, `vendor_id`, `is_fixed`, `purchase_channel` (`presencial`, `delivery` o `retiro`; por defecto `presencial`) y `expense_items_attributes` (lista de ítems con `name`, `quantity`, `unit` y `unit_price`). La unidad (`unit`) puede ser `unidad`, `kg` o `g`. El gasto queda a nombre del usuario autenticado y de su grupo familiar.

**Si se envían ítems, el monto del gasto se calcula como la suma de `quantity × unit_price`** y reemplaza al `amount` enviado.

Gasto simple:

```bash
curl -X POST http://localhost:3000/api/v1/expenses \
  -H "Authorization: Bearer <TOKEN>" -H "Content-Type: application/json" \
  -d '{"amount":25000,"date":"2026-09-05","category_id":3,"description":"Luz","is_fixed":true}'
```

Respuesta `201`:

```json
{
  "id": 1,
  "amount": "25000.0",
  "date": "2026-09-05",
  "description": "Luz",
  "is_fixed": true,
  "purchase_channel": "presencial",
  "user_id": 1,
  "vendor_id": null,
  "category": { "id": 3, "name": "Servicios" },
  "expense_items": []
}
```

Gasto con ítems y comercio (sin `amount`, se calcula solo):

```bash
curl -X POST http://localhost:3000/api/v1/expenses \
  -H "Authorization: Bearer <TOKEN>" -H "Content-Type: application/json" \
  -d '{"date":"2026-09-12","category_id":1,"vendor_id":1,"description":"Compra semanal","purchase_channel":"presencial","expense_items_attributes":[{"name":"Leche","quantity":2,"unit":"unidad","unit_price":1800.5},{"name":"Carne","quantity":1,"unit":"kg","unit_price":9500}]}'
```

Respuesta `201`: el gasto `id: 2` que aparece en el listado de `GET /api/v1/expenses`, con `amount: "13101.0"`.

Con datos inválidos (por ejemplo un `purchase_channel` que no existe), `422`:

```json
{ "errors": ["Purchase channel no es válido"] }
```

Un `vendor_id` inexistente también devuelve `422`.

### Notas sobre la API

- Los mensajes de validación vienen del modelo y hoy mezclan español e inglés (por ejemplo `"Amount must be greater than 0"`).
- Cuando el `purchase_channel` o el `vendor_id` son inválidos, la API responde solo ese error y no valida el resto de los campos en la misma respuesta.
- Las categorías son globales; los gastos y el dashboard se limitan al grupo familiar del usuario.

## Modelo de datos

Un **grupo familiar** (`FamilyGroup`) es la unidad principal: agrupa usuarios, gastos, metas de ahorro y compras en cuotas.

```
FamilyGroup ──< User ──< Income
     │            └────< Expense >── Category (con padre/subcategorías)
     │                    │  └────── Vendor (opcional)
     │                    └──< ExpenseItem
     ├──< Expense            (el gasto también pertenece al grupo)
     ├──< SavingsGoal
     ├──< InstallmentPurchase >── Category, Vendor (opcional)
     └──< ShoppingListItem >── Category

FinancialTip, ReferenceIndex: tablas independientes, sin relaciones.
```

| Modelo | Qué representa |
|--------|----------------|
| `FamilyGroup` | Grupo familiar, con su porcentaje de ahorro objetivo (0 a 100) |
| `User` | Usuario del grupo. Tiene contraseña con `has_secure_password`, un `auth_token` para la API y el flag `admin` para el back-office |
| `Income` | Ingreso de un usuario (monto mayor a 0 y fecha) |
| `Expense` | Gasto con categoría, comercio opcional, canal de compra (`presencial`, `delivery`, `retiro`), indicador de gasto fijo y una imagen de comprobante adjuntable (Active Storage) |
| `ExpenseItem` | Ítem de un gasto: nombre, cantidad, unidad (`unidad`, `kg`, `g`) y precio unitario |
| `Category` | Categoría de gasto, con categoría padre opcional |
| `Vendor` | Comercio donde se compra, con un indicador de compra online |
| `SavingsGoal` | Meta de ahorro: monto objetivo, monto ahorrado y fecha límite. Calcula el progreso y cuánto ahorrar por mes |
| `InstallmentPurchase` | Compra en cuotas (de 1 a 48): calcula el monto por cuota, los períodos y las cuotas restantes |
| `ShoppingListItem` | Ítem de la lista de compras de un período, con precio unitario estimado |
| `FinancialTip` | Consejo financiero, con un indicador para mostrarlo junto a las alertas |
| `ReferenceIndex` | Índice de referencia (nombre, período y valor) |

## Calidad y tests

Para correr la suite completa:

```bash
bin/rails test
```

Estado verificado al 2026-09-30: **65 tests, 250 assertions, 0 fallas, 0 errores, 0 omitidos.**

| Área | Tests | Qué cubre |
|------|------:|-----------|
| API v1 | 29 | Login (3), dashboard (6), ingresos (5), categorías (5) y gastos (10). Incluye autenticación por token (401 sin token), validaciones (422), aislamiento entre grupos familiares y que la API ignore el `user_id` enviado |
| Modelos | 23 | `SavingsGoal` (8), `InstallmentPurchase` (7), `Expense` (7) y `User` (1) |
| Back-office | 11 | Categorías (6) y metas de ahorro (5) |
| Mailers | 2 | Mail de felicitación al cumplir una meta de ahorro |

Análisis estático:

```bash
bin/rubocop      # estilo
bin/brakeman     # seguridad
```

- **Rubocop:** 91 archivos inspeccionados, **0 ofensas**.
- **Brakeman:** **0 warnings**. Hay 2 advertencias ignoradas a propósito, ambas falsos positivos de mass assignment en `Admin::UsersController`, documentados en `config/brakeman.ignore`. Esa pantalla solo es accesible para administradores logueados y existe justamente para que un admin cree usuarios y los marque como administradores.

**Lo que hoy no está cubierto por tests:** las pantallas del back-office de gastos, ingresos, usuarios, comercios, compras en cuotas, lista de compras, ahorro y estadísticas, y no hay tests de sistema (navegador).

## Evolución futura

Estas funcionalidades **quedaron fuera del alcance de esta entrega** y son una **idea planeada a futuro**. Hoy no están implementadas.

- **Lectura automática de tickets y facturas (OCR):** sacar una foto del comprobante y que la app cargue sola el comercio, la fecha y los ítems del gasto. El modelo de gastos ya admite adjuntar una imagen de comprobante y guardar ítems con precio unitario, que serían la base para esto.
- **Comparación de precios entre comercios:** con los precios por ítem y el comercio de cada compra, comparar cuánto cuesta el mismo producto en distintos lugares y ayudar a elegir dónde comprar.
