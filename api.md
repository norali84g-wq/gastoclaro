# Contrato de la API — GastoClaro (TP2)

**Versión:** 0.2 · **Autora:** Norali · **Base URL:** `/api/v1` · **Formato:** JSON

Este documento es el acuerdo entre el back-end (Rails) y el front-end (React). Lo que está acá es lo que el front puede usar. Si hay que cambiar algo, se cambia acá primero y se avisa por Trello.

## Estado de cada endpoint

| Estado | Significado |
|--------|-------------|
| `existe` | Ya funciona hoy en `main` con esta forma |
| `cambia` | Existe, pero la respuesta o los errores cambian (PR pendiente) |
| `falta` | Todavía no existe, está planificado. Su ejemplo muestra la forma acordada |

## Qué falta todavía en `main`

Esto describe el contrato final. Estas piezas todavía no están en `main`; hasta que entren, la API se comporta distinto:

| Pieza | Hoy en `main` | Cuando entre |
|-------|---------------|--------------|
| `422` si un ítem de gasto llega sin `name` (en `POST` y `PATCH`) | el ítem se descarta en silencio | PR aparte |
| `422` si `quantity` de un ítem no es entero | se recorta sin error (`1.5` → `1`, `0.5` → `0`) | mismo PR de validación de ítems |
| `400` si el JSON está mal formado | Rails responde con su propio formato | sin PR todavía |

Además, los endpoints de [Endpoints planificados](#endpoints-planificados) todavía no existen.

## Convenciones

- **Alcance:** los datos son personales. Cada usuario ve y modifica solo lo suyo. El usuario `admin` ve los de todos y puede usar los endpoints marcados "solo admin".
- **Nombres:** rutas y campos en inglés, `snake_case`.
- **URL base:** `<API_URL>/api/v1`. En desarrollo, `http://localhost:3000/api/v1`. En el front, esta URL va en una variable de entorno, nunca escrita en el código.
- **`Content-Type: application/json`:** es **obligatorio** en todos los `POST` y `PATCH`. En los `GET` y `DELETE` no hace falta.
- **Autenticación:** JWT. Se obtiene con `POST /login` o `POST /register` y se envía en cada pedido protegido:

  ```
  Authorization: Bearer <TOKEN>
  ```

  El token **vence a las 24 horas**. `POST /login` y `POST /register` devuelven `expires_at` (ISO 8601, en UTC: por ejemplo `2026-10-27T06:14:00Z`) para avisar al usuario antes de que se caiga la sesión. `DELETE /logout` lo invalida antes. Aun así, el front tiene que manejar un `401` en cualquier pedido: el token puede dejar de servir antes, por ejemplo si se cierra la sesión desde otro dispositivo.
- **Parámetro de ruta `:id`:** siempre es un entero positivo. Un `:id` que no existe o es de otro usuario devuelve `404`.
- **Montos:** se devuelven como **string decimal** (por ejemplo `"450000.0"`). Al enviar, se aceptan números.
- **Fechas:** solo se admite `YYYY-MM-DD`. Los períodos, `YYYY-MM`. Una fecha que no existe (`2026-02-30`) devuelve `422` con `field` `date` y el mensaje "no puede estar en blanco": la API no distingue entre una fecha vacía y una inexistente. Con otros formatos (por ejemplo `05/09/2026`) el resultado **no está garantizado**: Rails puede interpretarlos y guardar otra fecha sin dar error, así que el front siempre envía el formato ISO.
- **Recurso de otro usuario:** devuelve `404`, no `403`, para no revelar que existe.
- **Valores cerrados:** `purchase_channel` es `presencial`, `delivery` o `retiro`. `unit` (en los ítems de un gasto) es `unidad`, `kg` o `g`. La API devuelve estos códigos tal cual; el front los traduce para mostrarlos.
- **CORS:** la API acepta pedidos del origen configurado en la variable de entorno `FRONTEND_URL` (en desarrollo, `http://localhost:5173`) y acepta el header `Authorization`. El origen se nombra siempre de forma explícita, nunca con `*`.
- **Alcance del TP2:** el comercio (`vendor_id`) no se usa: el front lo ignora y no hay endpoint para listar comercios (puede traer valor si el gasto se cargó desde el panel admin). Las categorías son planas (`parent_id` y `tracks_installments` valen siempre `null`) y el front los ignora.

## Cómo reproducir los ejemplos

Los ejemplos usan marcadores entre `<>` que hay que reemplazar. Los `id` que aparecen en las respuestas son solo ilustrativos: dependen del orden en que se crearon los datos.

| Marcador | Qué poner |
|----------|-----------|
| `<TOKEN>` | el `token` que devuelve `POST /login` |
| `<CATEGORY_ID>` | un `id` de `GET /categories` (en el JSON va como número, sin comillas) |
| `<EXPENSE_ID>` / `<INCOME_ID>` | el `id` que devolvió el `POST` correspondiente |

Con una base nueva (`bin/rails db:setup`), el seed (`db/seeds.rb`) crea el usuario `admin`, las dos categorías de ejemplo (Supermercado y Limpieza) y, fuera de producción, un usuario de demostración (`demo`) con ingresos y gastos. Las credenciales están en el README. Si la base ya existe, alcanza con `bin/rails db:seed`: se puede correr más de una vez sin duplicar datos. La API no tiene endpoint para crear categorías: las nuevas se cargan desde el panel web `/admin/categories` (con el usuario admin) o con `bin/rails console`.

## Formato de errores

Todos los errores usan la misma forma, igual que el contrato del TFI. `field` es el campo con el problema, o `"base"` si el error es general. `message` está en español y se puede mostrar al usuario:

```json
{ "errors": [ { "field": "amount", "message": "debe ser mayor a 0" } ] }
```

El front usa `field` para marcar el campo del formulario con error. Si `field` es `"base"`, muestra el mensaje como aviso general.

Reglas:

- El `field` se llama igual que el campo que el front envió (por ejemplo `category_id`, no `category`).
- Un `422` trae **todos** los errores de validación juntos, no solo el primero.
- Excepción conocida: los errores de los ítems de un gasto llegan como `expense_items.name`, no como `expense_items_attributes[0][name]`. El error **no dice de qué ítem viene**: el front no puede saber cuál de la lista tiene el problema y tiene que mostrar el mensaje de forma general.

| HTTP | Cuándo ocurre | Ejemplo de `field` y `message` |
|:----:|---------------|-------------------------------|
| 400 | El cuerpo no es un JSON válido (`falta`) | `base` — "JSON mal formado" |
| 401 | Falta el token, es inválido, venció o se cerró la sesión | `base` — "No autorizado" |
| 401 | Usuario o contraseña incorrectos en el login | `base` — "Usuario o contraseña incorrectos" |
| 403 | El usuario no tiene permiso (por ejemplo, no es admin) | `base` — "Acceso denegado" |
| 404 | El recurso no existe o es de otro usuario | `base` — "No encontrado" |
| 422 | Datos de entrada inválidos | el campo y su problema, por ejemplo `amount` — "debe ser mayor a 0" |

El `404` de cualquier endpoint con `:id` responde:

```json
{ "errors": [ { "field": "base", "message": "No encontrado" } ] }
```

## Resumen de endpoints

| Método | Ruta | Protegido | Permiso | Estado |
|--------|------|:---------:|---------|:------:|
| POST | `/login` | No | — | existe |
| DELETE | `/logout` | Sí | cualquier usuario | existe |
| POST | `/register` | No | — | existe |
| GET | `/me` | Sí | cualquier usuario | existe |
| GET | `/dashboard` | Sí | cualquier usuario | existe |
| GET | `/savings` | Sí | cualquier usuario | existe |
| GET | `/categories` | Sí | cualquier usuario | existe |
| POST | `/categories` | Sí | solo admin | existe |
| PATCH | `/categories/:id` | Sí | solo admin | existe |
| GET | `/expenses` | Sí | cualquier usuario | existe |
| POST | `/expenses` | Sí | cualquier usuario | existe |
| PATCH | `/expenses/:id` | Sí | dueño del gasto o admin | existe |
| DELETE | `/expenses/:id` | Sí | dueño del gasto o admin | existe |
| GET | `/incomes` | Sí | cualquier usuario | existe |
| POST | `/incomes` | Sí | cualquier usuario | existe |
| PATCH | `/incomes/:id` | Sí | dueño del ingreso o admin | existe |
| DELETE | `/incomes/:id` | Sí | dueño del ingreso o admin | existe |
| GET | `/savings_goals` | Sí | cualquier usuario | existe |
| POST | `/savings_goals` | Sí | cualquier usuario | existe |
| PATCH | `/savings_goals/:id` | Sí | mismo grupo familiar o admin | existe |
| DELETE | `/savings_goals/:id` | Sí | mismo grupo familiar o admin | existe |
| GET | `/installment_purchases` | Sí | cualquier usuario | existe |
| POST | `/installment_purchases` | Sí | cualquier usuario | existe |
| PATCH | `/installment_purchases/:id` | Sí | mismo grupo familiar o admin | existe |
| DELETE | `/installment_purchases/:id` | Sí | mismo grupo familiar o admin | existe |
| GET | `/shopping_list_items` | Sí | cualquier usuario | existe |
| POST | `/shopping_list_items` | Sí | cualquier usuario | existe |
| PATCH | `/shopping_list_items/:id` | Sí | mismo grupo familiar o admin | existe |
| DELETE | `/shopping_list_items/:id` | Sí | mismo grupo familiar o admin | existe |
| GET | `/users` | Sí | solo admin | existe |

Esta tabla lista solo lo que existe hoy. Los endpoints que todavía no existen están en [Endpoints planificados](#endpoints-planificados).

## Formas de las respuestas

Cada recurso se define una sola vez acá; los endpoints lo referencian por su nombre. La columna **Puede ser `null`** indica si el front tiene que contemplar ese valor.

### Usuario

| Campo | Tipo | Puede ser `null` | Qué es |
|-------|------|:----------------:|--------|
| `id` | integer | No | identificador |
| `user` | string | No | nombre de usuario |
| `email` | string | **Sí** | el admin del seed no tiene email |
| `admin` | boolean | No | `true` si es administrador. Sirve solo para decidir qué mostrar; los permisos los controla siempre la API |

### Categoría

| Campo | Tipo | Puede ser `null` | Qué es |
|-------|------|:----------------:|--------|
| `id` | integer | No | identificador |
| `name` | string | No | nombre |
| `parent_id` | integer | **Sí** | id de la categoría padre; `null` si es una categoría principal |
| `tracks_installments` | boolean | **Sí** | `null` si no se indicó |

### Gasto

| Campo | Tipo | Puede ser `null` | Qué es |
|-------|------|:----------------:|--------|
| `id` | integer | No | identificador |
| `amount` | string decimal | No | monto total. Si hay ítems, es la suma de sus `subtotal` |
| `date` | string `YYYY-MM-DD` | No | fecha del gasto |
| `description` | string | **Sí** | texto libre |
| `is_fixed` | boolean | No | `true` si es un gasto fijo |
| `purchase_channel` | string | No | `presencial`, `delivery` o `retiro` |
| `user` | objeto `{ id, user }` | No | a quién pertenece |
| `vendor_id` | integer | **Sí** | el front lo ignora. Puede traer valor si el gasto se cargó desde el panel admin |
| `category` | objeto `{ id, name }` | No | categoría |
| `expense_items` | array de Ítem | No | puede venir vacío (`[]`) |

### Ítem de gasto

| Campo | Tipo | Puede ser `null` | Qué es |
|-------|------|:----------------:|--------|
| `id` | integer | No | identificador |
| `name` | string | No | nombre del producto |
| `quantity` | integer | No | cantidad, entera y mayor a 0 |
| `unit` | string | No | `unidad`, `kg` o `g` |
| `unit_price` | string decimal | No | precio por unidad, mayor o igual a 0 |
| `subtotal` | string decimal | No | `quantity × unit_price` |

### Ingreso

| Campo | Tipo | Puede ser `null` | Qué es |
|-------|------|:----------------:|--------|
| `id` | integer | No | identificador |
| `amount` | string decimal | No | monto |
| `date` | string `YYYY-MM-DD` | No | fecha del ingreso |
| `user` | objeto `{ id, user }` | No | a quién pertenece. Importa para el admin, que ve los de todos. Lo traen todos los endpoints de ingresos y `incomes` dentro de `GET /dashboard` |

### Meta de ahorro

| Campo | Tipo | Puede ser `null` | Qué es |
|-------|------|:----------------:|--------|
| `id` | integer | No | identificador |
| `name` | string | No | nombre de la meta |
| `target_amount` | string decimal | No | monto que se quiere juntar |
| `saved_amount` | string decimal | No | monto ahorrado hasta ahora |
| `deadline` | string `YYYY-MM-DD` | **Sí** | fecha límite, si la hay |
| `progress_percentage` | integer | No | **calculado, no se guarda**: `saved_amount / target_amount × 100`, redondeado. Puede superar `100` si se ahorró más que el objetivo |

### Ítem de la lista de gastos fijos

| Campo | Tipo | Puede ser `null` | Qué es |
|-------|------|:----------------:|--------|
| `id` | integer | No | identificador |
| `name` | string | No | qué se planifica comprar o pagar |
| `period` | string `YYYY-MM` | No | mes al que corresponde |
| `quantity` | string decimal | **Sí** | cantidad |
| `estimated_unit_price` | string decimal | No | precio unitario estimado |
| `subtotal` | string decimal | No | **calculado, no se guarda**: `quantity × estimated_unit_price` (`0` si no hay cantidad) |
| `category` | objeto `{ id, name }` | No | categoría del ítem |

### Compra en cuotas

| Campo | Tipo | Puede ser `null` | Qué es |
|-------|------|:----------------:|--------|
| `id` | integer | No | identificador |
| `description` | string | No | qué se compró |
| `total_amount` | string decimal | No | monto total de la compra |
| `installments_count` | integer | No | cantidad de cuotas, de 1 a 48 |
| `first_period` | string `YYYY-MM` | No | mes de la primera cuota |
| `category_id` | integer | No | categoría |
| `vendor_id` | integer | **Sí** | comercio, si se informó |
| `installment_amount` | string decimal | No | **calculado**: `total_amount / installments_count`, redondeado a 2 decimales |
| `remaining_installments` | integer | No | **calculado**: cuotas que faltan hasta el mes actual (nunca menos de `0`) |

---

## Autenticación

### `POST /login`

Público. Devuelve el token, cuándo vence y los datos del usuario (la misma forma que `GET /me`).

| Campo | Tipo | Obligatorio | Validación |
|-------|------|:-----------:|------------|
| `user` | string | Sí | nombre de usuario |
| `password` | string | Sí | — |

```bash
curl -X POST http://localhost:3000/api/v1/login \
  -H "Content-Type: application/json" \
  -d '{"user":"admin","password":"admin1234"}'
```

`200`:

```json
{
  "token": "eyJhbGciOiJIUzI1NiJ9...",
  "expires_at": "2026-10-27T06:14:00Z",
  "user": { "id": 1, "user": "admin", "email": null, "admin": true }
}
```

`401` con credenciales incorrectas:

```json
{ "errors": [ { "field": "base", "message": "Usuario o contraseña incorrectos" } ] }
```

### `POST /register`

Público. Crea una cuenta de usuario común y devuelve su token. Si el pedido incluye `admin` o `family_group_id`, se ignoran.

| Campo | Tipo | Obligatorio | Validación |
|-------|------|:-----------:|------------|
| `user` | string | Sí | único |
| `email` | string | Sí | formato válido, único (sin distinguir mayúsculas) |
| `password` | string | Sí | mínimo 8 caracteres |
| `password_confirmation` | string | Sí | igual a `password` |

```bash
curl -X POST http://localhost:3000/api/v1/register \
  -H "Content-Type: application/json" \
  -d '{"user":"prueba1","email":"prueba1@example.com","password":"clave1234","password_confirmation":"clave1234"}'
```

`201`:

```json
{
  "token": "eyJhbGciOiJIUzI1NiJ9...",
  "expires_at": "2026-10-27T06:14:00Z",
  "user": { "id": 5, "user": "prueba1", "email": "prueba1@example.com", "admin": false }
}
```

`422` con datos inválidos:

```json
{
  "errors": [
    { "field": "user", "message": "ya está en uso" },
    { "field": "email", "message": "ya está en uso" }
  ]
}
```

### `DELETE /logout`

Protegido. Invalida el token usado y cualquier otro emitido antes para ese usuario. Cierra la sesión en todos los dispositivos, a propósito: si alguien copió un token, el logout lo invalida igual.

```bash
curl -X DELETE http://localhost:3000/api/v1/logout -H "Authorization: Bearer <TOKEN>"
```

`204`, sin cuerpo. Si se reutiliza el token, `401`:

```json
{ "errors": [ { "field": "base", "message": "No autorizado" } ] }
```

### `GET /me`

Protegido. Devuelve el usuario del token. Sirve para que el front sepa quién está logueado y si es admin al recargar la página.

```bash
curl http://localhost:3000/api/v1/me -H "Authorization: Bearer <TOKEN>"
```

`200` (forma **Usuario**):

```json
{ "id": 5, "user": "prueba1", "email": "prueba1@example.com", "admin": false }
```

---

## Dashboard

### `GET /dashboard`

Protegido. Resumen del **mes en curso** del usuario (el admin ve el de todos). Se cumple siempre: `income = consumption + savings`.

```bash
curl http://localhost:3000/api/v1/dashboard -H "Authorization: Bearer <TOKEN>"
```

`200`:

```json
{
  "period": "2026-09",
  "income": "450000.0",
  "consumption": "38101.0",
  "savings": "411899.0",
  "savings_goal_percentage": 10,
  "incomes": [
    { "id": 1, "user": { "id": 1, "user": "admin" }, "amount": "450000.0", "date": "2026-09-01" }
  ],
  "consumption_by_category": [
    { "category": "Limpieza", "total": "25000.0", "planned": "30000.0" },
    { "category": "Supermercado", "total": "13101.0", "planned": "0.0" }
  ],
  "monthly_savings": [
    { "month": "2026-09", "income": "450000.0", "consumption": "38101.0", "savings": "411899.0", "accumulated": "411899.0" }
  ]
}
```

| Campo | Qué es |
|-------|--------|
| `period` | el mes en curso, `YYYY-MM` |
| `income`, `consumption`, `savings` | totales del mes. `savings = income - consumption`; puede ser negativo si se gastó más de lo que se ganó |
| `savings_goal_percentage` | entero de 0 a 100, nunca `null`. Para un usuario recién registrado vale `0` |
| `incomes` | los ingresos del mes, del más antiguo al más reciente. Cada uno trae `id`, `user` (objeto `{ "id", "user" }`, igual que en el resto de la API), `amount` y `date` |
| `consumption_by_category` | el consumo del mes (`total`) y lo planificado (`planned`, suma de la lista de gastos fijos del mes) agrupado por nombre de categoría. Una categoría solo planificada trae `total` en `0.0`. **No tiene un orden garantizado**: el front lo ordena como necesite |
| `monthly_savings` | los últimos 6 meses, del más antiguo al más reciente |
| `monthly_savings[].accumulated` | ahorro acumulado: la suma corrida de `savings` dentro de esos 6 meses. El primer mes de la lista parte de 0, así que **no** es el ahorro de toda la vida |

---

## Ahorro

### `GET /savings`

Protegido. El ahorro mes a mes **desde el primer movimiento hasta el mes en curso**: es el detalle completo de lo que `GET /dashboard` resume en `monthly_savings` (solo los últimos 6 meses). El admin ve el de todos. No incluye meses futuros.

```bash
curl http://localhost:3000/api/v1/savings -H "Authorization: Bearer <TOKEN>"
```

`200`:

```json
{
  "savings_goal_percentage": 10,
  "months": [
    { "month": "2026-09", "income": "450000.0", "consumption": "38101.0", "savings": "411899.0", "accumulated": "411899.0" },
    { "month": "2026-10", "income": "0.0", "consumption": "1000.0", "savings": "-1000.0", "accumulated": "410899.0" }
  ]
}
```

| Campo | Qué es |
|-------|--------|
| `savings_goal_percentage` | entero de 0 a 100, nunca `null` (igual que en `GET /dashboard`) |
| `months` | del mes más antiguo al más reciente; `[]` si todavía no hay ingresos ni gastos. Un mes sin movimientos aparece en cero |
| `months[].savings` | `income - consumption`; puede ser negativo |
| `months[].accumulated` | suma corrida de `savings` desde el primer mes de la lista |

---

## Categorías

### `GET /categories`

Protegido. Lista todas las categorías (globales), ordenadas por nombre. Después de correr el seed devuelve las dos categorías de ejemplo; en una base sin seed devuelve `[]` (ver "Cómo reproducir los ejemplos").

```bash
curl http://localhost:3000/api/v1/categories -H "Authorization: Bearer <TOKEN>"
```

`200` (forma **Categoría**):

```json
[
  { "id": 2, "name": "Limpieza", "parent_id": null, "tracks_installments": null },
  { "id": 1, "name": "Supermercado", "parent_id": null, "tracks_installments": null }
]
```

### `POST /categories`

Protegido, **solo admin** (las categorías son compartidas por todos los usuarios). Un usuario común recibe `403`.

| Campo | Tipo | Obligatorio | Validación |
|-------|------|:-----------:|------------|
| `name` | string | Sí | no puede estar vacío |
| `parent_id` | integer | No | tiene que ser una categoría que exista |

```bash
curl -X POST http://localhost:3000/api/v1/categories \
  -H "Authorization: Bearer <TOKEN>" -H "Content-Type: application/json" \
  -d '{"name":"Tarjetas de crédito"}'
```

`201`: la categoría creada, con la forma **Categoría**. `422` con datos inválidos:

```json
{ "errors": [ { "field": "name", "message": "no puede estar en blanco" } ] }
```

### `PATCH /categories/:id`

Protegido, **solo admin**. Acepta los mismos campos y reglas que `POST`, todos opcionales. Una categoría no puede ser su propio padre ni colgar de una de sus subcategorías (`422` en `parent_id`). `404` si no existe. Borrar categorías no está en la API: una categoría con gastos no se puede borrar sin perder datos.

---

## Gastos

### `GET /expenses`

Protegido. Gastos del usuario, del más reciente al más antiguo (el admin ve los de todos).

| Parámetro de consulta | Tipo | Obligatorio | Qué hace |
|-----------------------|------|:-----------:|----------|
| `period` | string `YYYY-MM` | No | trae solo los gastos de ese mes. Si viene vacío (`?period=`) se ignora, igual que si no se envía. Si el valor es inválido (por ejemplo `2026-13`), responde `422` con `field` `period` y el mensaje "no es válido" |

La respuesta tiene un tope de **100 gastos**, sin paginación. Si hay más, devuelve los 100 más recientes **sin avisar**: usá `?period` para acotar.

```bash
curl "http://localhost:3000/api/v1/expenses?period=2026-09" -H "Authorization: Bearer <TOKEN>"
```

`200` (lista de **Gasto**):

```json
[
  {
    "id": 2,
    "amount": "13101.0",
    "date": "2026-09-12",
    "description": "Compra semanal",
    "is_fixed": false,
    "purchase_channel": "presencial",
    "user": { "id": 1, "user": "admin" },
    "vendor_id": null,
    "category": { "id": 1, "name": "Supermercado" },
    "expense_items": [
      { "id": 1, "name": "Leche", "quantity": 2, "unit": "unidad", "unit_price": "1800.5", "subtotal": "3601.0" },
      { "id": 2, "name": "Arroz", "quantity": 1, "unit": "unidad", "unit_price": "9500.0", "subtotal": "9500.0" }
    ]
  }
]
```

### `POST /expenses`

Protegido. El gasto queda a nombre del usuario del token.

| Campo | Tipo | Obligatorio | Validación |
|-------|------|:-----------:|------------|
| `date` | string `YYYY-MM-DD` | Sí | fecha válida (ver "Fechas" en Convenciones) |
| `category_id` | integer | Sí | tiene que existir |
| `amount` | number | Sí, si no hay ítems | mayor a 0 |
| `description` | string | No | — |
| `vendor_id` | integer | No | no se usa en el TP2: el front no lo envía |
| `is_fixed` | boolean | No | por defecto `false` |
| `purchase_channel` | string | No | `presencial`, `delivery` o `retiro` (por defecto `presencial`) |
| `expense_items_attributes` | array de ítems | No | ver la tabla de abajo |

Cada ítem de `expense_items_attributes`:

| Campo | Tipo | Obligatorio | Validación |
|-------|------|:-----------:|------------|
| `name` | string | Sí | no puede estar vacío. Si falta, responde `422` con `field` `expense_items.name` (`falta`: hoy el ítem sin nombre se descarta en silencio) |
| `quantity` | integer | No | entero mayor a 0; por defecto `1`. **No admite decimales**: para fracciones, usá `g` (1,5 kg = `1500` con `unit` `g`). Un decimal **no da error**: se recorta (`1.5` se guarda como `1` y `0.5` como `0`), así que el front tiene que validarlo antes de enviar |
| `unit` | string | No | `unidad`, `kg` o `g`; por defecto `unidad` |
| `unit_price` | number | Sí | mayor o igual a 0 |

Si se envían ítems, el front no envía `amount`: lo calcula el servidor como la suma de `quantity × unit_price`. Si llegaran los dos, gana el calculado y no es un error.

**Ejemplo simple** (sin ítems):

```bash
curl -X POST http://localhost:3000/api/v1/expenses \
  -H "Authorization: Bearer <TOKEN>" -H "Content-Type: application/json" \
  -d '{"amount":25000,"date":"2026-09-05","category_id":<CATEGORY_ID>,"description":"Productos de limpieza"}'
```

`201` (forma **Gasto**):

```json
{
  "id": 3,
  "amount": "25000.0",
  "date": "2026-09-05",
  "description": "Productos de limpieza",
  "is_fixed": false,
  "purchase_channel": "presencial",
  "user": { "id": 1, "user": "admin" },
  "vendor_id": null,
  "category": { "id": 2, "name": "Limpieza" },
  "expense_items": []
}
```

**Ejemplo con ítems** (el caso más completo para el front):

```bash
curl -X POST http://localhost:3000/api/v1/expenses \
  -H "Authorization: Bearer <TOKEN>" -H "Content-Type: application/json" \
  -d '{"date":"2026-09-12","category_id":<CATEGORY_ID>,"description":"Compra semanal","expense_items_attributes":[{"name":"Leche","quantity":2,"unit":"unidad","unit_price":1800.5},{"name":"Arroz","quantity":1,"unit":"unidad","unit_price":9500}]}'
```

`201`: `amount` es la suma de los subtotales (`3601.0 + 9500.0`).

```json
{
  "id": 2,
  "amount": "13101.0",
  "date": "2026-09-12",
  "description": "Compra semanal",
  "is_fixed": false,
  "purchase_channel": "presencial",
  "user": { "id": 1, "user": "admin" },
  "vendor_id": null,
  "category": { "id": 1, "name": "Supermercado" },
  "expense_items": [
    { "id": 1, "name": "Leche", "quantity": 2, "unit": "unidad", "unit_price": "1800.5", "subtotal": "3601.0" },
    { "id": 2, "name": "Arroz", "quantity": 1, "unit": "unidad", "unit_price": "9500.0", "subtotal": "9500.0" }
  ]
}
```

`422` con datos inválidos:

```json
{ "errors": [ { "field": "purchase_channel", "message": "no es válido" } ] }
```

Un `vendor_id` que no existe devuelve `422` con `field` `vendor_id` y el mensaje "no existe". Un `category_id` que no existe también devuelve `422`, con `field` `category_id` y el mensaje "debe existir". Si hay varios campos inválidos, la API los devuelve todos juntos en la misma respuesta.

### `PATCH /expenses/:id`

Protegido. Edita un gasto. Acepta los mismos campos y reglas que `POST`, todos opcionales. Solo se modifica lo que se envía.

```bash
curl -X PATCH http://localhost:3000/api/v1/expenses/<EXPENSE_ID> \
  -H "Authorization: Bearer <TOKEN>" -H "Content-Type: application/json" \
  -d '{"description":"Compra del sábado"}'
```

`200`: el gasto actualizado, con la forma **Gasto**. `404` si no existe o no es del usuario. `422` si hay datos inválidos. El `user` del gasto no cambia nunca: un `user_id` enviado se ignora.

**Editar o borrar ítems.** Para modificar un ítem que ya existe, se envía su `id` **y también su `name`**. Para borrarlo, se envía su `id` con `"_destroy": true` (el borrado no necesita `name`). Un ítem sin `id` se crea nuevo. Si el `id` de un ítem no pertenece a ese gasto, la API responde `404`:

```bash
curl -X PATCH http://localhost:3000/api/v1/expenses/<EXPENSE_ID> \
  -H "Authorization: Bearer <TOKEN>" -H "Content-Type: application/json" \
  -d '{"expense_items_attributes":[{"id":1,"name":"Leche","quantity":3},{"id":2,"_destroy":true}]}'
```

**Atención 1:** un ítem con `id` que llega sin `name` tiene que dar `422`, igual que en `POST`. El borrado (`_destroy`) no necesita `name`. Hoy ese ítem se descarta en silencio, sin error (ver «Qué falta todavía en `main`»: lo resuelve el PR de validación de ítems).

`amount` se recalcula con los ítems que quedan. **Atención 2:** si se borran todos los ítems, el gasto conserva el `amount` anterior; para fijar otro monto, enviá también `amount` en el mismo pedido.

### `DELETE /expenses/:id`

Protegido. Borra un gasto y sus ítems.

```bash
curl -X DELETE http://localhost:3000/api/v1/expenses/<EXPENSE_ID> -H "Authorization: Bearer <TOKEN>"
```

`204`, sin cuerpo. `404` si no existe o no es del usuario.

---

## Ingresos

### `POST /incomes`

Protegido. El ingreso queda a nombre del usuario del token; cualquier `user_id` enviado se ignora.

| Campo | Tipo | Obligatorio | Validación |
|-------|------|:-----------:|------------|
| `amount` | number | Sí | mayor a 0 |
| `date` | string `YYYY-MM-DD` | Sí | fecha válida (ver "Fechas" en Convenciones) |

```bash
curl -X POST http://localhost:3000/api/v1/incomes \
  -H "Authorization: Bearer <TOKEN>" -H "Content-Type: application/json" \
  -d '{"amount":450000,"date":"2026-09-01"}'
```

`201`: el ingreso creado, con la forma **Ingreso**:

```json
{ "id": 1, "amount": "450000.0", "date": "2026-09-01", "user": { "id": 1, "user": "admin" } }
```

`422`:

```json
{ "errors": [ { "field": "amount", "message": "debe ser mayor a 0" } ] }
```

### `GET /incomes`

Protegido. Ingresos del usuario, del más reciente al más antiguo (el admin ve los de todos, por eso cada uno trae `user`).

```bash
curl http://localhost:3000/api/v1/incomes -H "Authorization: Bearer <TOKEN>"
```

`200` (lista de **Ingreso**):

```json
[
  { "id": 1, "amount": "450000.0", "date": "2026-09-01", "user": { "id": 1, "user": "admin" } }
]
```

### `PATCH /incomes/:id`

Protegido. Edita un ingreso (`amount`, `date`, opcionales). Solo se modifica lo que se envía.

```bash
curl -X PATCH http://localhost:3000/api/v1/incomes/<INCOME_ID> \
  -H "Authorization: Bearer <TOKEN>" -H "Content-Type: application/json" \
  -d '{"amount":460000}'
```

`200`:

```json
{ "id": 1, "amount": "460000.0", "date": "2026-09-01", "user": { "id": 1, "user": "admin" } }
```

`404` si no existe o no es del usuario (el admin puede editar los de todos). `422` si hay datos inválidos, igual que en `POST`.

### `DELETE /incomes/:id`

Protegido. Borra un ingreso.

```bash
curl -X DELETE http://localhost:3000/api/v1/incomes/<INCOME_ID> -H "Authorization: Bearer <TOKEN>"
```

`204`, sin cuerpo. `404` si no existe o no es del usuario.

---

## Metas de ahorro

Las metas pertenecen al **grupo familiar** del usuario. Cada usuario registrado por la API tiene su propio grupo, así que ve solo las suyas. El admin ve y modifica las de todos. Una meta de otro grupo responde `404`. El aporte de ahorro **no es consumo**: no cambia el dashboard.

### `GET /savings_goals`

Protegido. Lista las metas, de la más reciente a la más antigua.

```bash
curl http://localhost:3000/api/v1/savings_goals -H "Authorization: Bearer <TOKEN>"
```

`200` (lista de **Meta de ahorro**):

```json
[
  { "id": 1, "name": "Viaje", "target_amount": "1000.0", "saved_amount": "250.0", "deadline": null, "progress_percentage": 25 }
]
```

### `POST /savings_goals`

Protegido. La meta queda en el grupo familiar del usuario; cualquier `family_group_id` enviado se ignora.

| Campo | Tipo | Obligatorio | Validación |
|-------|------|:-----------:|------------|
| `name` | string | Sí | no puede estar vacío |
| `target_amount` | number | Sí | mayor a 0 |
| `saved_amount` | number | No | mayor o igual a 0; por defecto `0` |
| `deadline` | string `YYYY-MM-DD` | No | fecha válida |

```bash
curl -X POST http://localhost:3000/api/v1/savings_goals \
  -H "Authorization: Bearer <TOKEN>" -H "Content-Type: application/json" \
  -d '{"name":"Notebook","target_amount":800,"deadline":"2027-03-01"}'
```

`201`: la meta creada, con la forma **Meta de ahorro**:

```json
{ "id": 2, "name": "Notebook", "target_amount": "800.0", "saved_amount": "0.0", "deadline": "2027-03-01", "progress_percentage": 0 }
```

`422` con datos inválidos:

```json
{ "errors": [ { "field": "target_amount", "message": "debe ser mayor a 0" } ] }
```

### `PATCH /savings_goals/:id`

Protegido. Acepta los mismos campos y reglas que `POST`, todos opcionales. Solo se modifica lo que se envía.

```bash
curl -X PATCH http://localhost:3000/api/v1/savings_goals/<GOAL_ID> \
  -H "Authorization: Bearer <TOKEN>" -H "Content-Type: application/json" \
  -d '{"saved_amount":500}'
```

`200`: la meta actualizada, con `progress_percentage` recalculado. `404` si no existe o es de otro grupo. `422` si hay datos inválidos. A diferencia del back-office, la API **no envía el mail** de felicitación al cumplir una meta.

### `DELETE /savings_goals/:id`

Protegido.

```bash
curl -X DELETE http://localhost:3000/api/v1/savings_goals/<GOAL_ID> -H "Authorization: Bearer <TOKEN>"
```

`204`, sin cuerpo. `404` si no existe o es de otro grupo.

---

## Compras en cuotas

Igual que las metas, pertenecen al **grupo familiar** del usuario (el admin ve todas; una compra de otro grupo responde `404`). Las cuotas **no crean consumo**: no cambian el dashboard.

### `GET /installment_purchases`

Protegido. Lista las compras, de la más reciente a la más antigua.

```bash
curl http://localhost:3000/api/v1/installment_purchases -H "Authorization: Bearer <TOKEN>"
```

`200` (lista de **Compra en cuotas**):

```json
[
  {
    "id": 1, "description": "Heladera", "total_amount": "1200.0", "installments_count": 12,
    "first_period": "2026-11", "category_id": 4, "vendor_id": null,
    "installment_amount": "100.0", "remaining_installments": 11
  }
]
```

### `POST /installment_purchases`

Protegido.

| Campo | Tipo | Obligatorio | Validación |
|-------|------|:-----------:|------------|
| `description` | string | Sí | no puede estar vacío |
| `total_amount` | number | Sí | mayor a 0 |
| `installments_count` | integer | Sí | entero de 1 a 48 |
| `first_period` | string `YYYY-MM` | Sí | mes válido, por ejemplo `2026-11` |
| `category_id` | integer | Sí | tiene que existir |
| `vendor_id` | integer | No | si se envía, tiene que existir |

```bash
curl -X POST http://localhost:3000/api/v1/installment_purchases \
  -H "Authorization: Bearer <TOKEN>" -H "Content-Type: application/json" \
  -d '{"description":"Televisor","total_amount":900,"installments_count":3,"first_period":"2026-11","category_id":<CATEGORY_ID>}'
```

`201`: la compra creada, con la forma **Compra en cuotas**:

```json
{
  "id": 2, "description": "Televisor", "total_amount": "900.0", "installments_count": 3,
  "first_period": "2026-11", "category_id": 4, "vendor_id": null,
  "installment_amount": "300.0", "remaining_installments": 2
}
```

`422` con datos inválidos (por ejemplo, un `first_period` con un mes que no existe):

```json
{ "errors": [ { "field": "first_period", "message": "debe tener formato AAAA-MM" } ] }
```

Un `category_id` que no existe da `422` con "debe existir", y un `vendor_id` que no existe, con "no existe". Si hay varios campos inválidos, la API los devuelve todos juntos.

### `PATCH /installment_purchases/:id`

Protegido. Acepta los mismos campos y reglas que `POST`, todos opcionales. Solo se modifica lo que se envía.

```bash
curl -X PATCH http://localhost:3000/api/v1/installment_purchases/<PURCHASE_ID> \
  -H "Authorization: Bearer <TOKEN>" -H "Content-Type: application/json" \
  -d '{"installments_count":6}'
```

`200`: la compra actualizada, con `installment_amount` y `remaining_installments` recalculados. `404` si no existe o es de otro grupo. `422` si hay datos inválidos.

### `DELETE /installment_purchases/:id`

Protegido.

```bash
curl -X DELETE http://localhost:3000/api/v1/installment_purchases/<PURCHASE_ID> -H "Authorization: Bearer <TOKEN>"
```

`204`, sin cuerpo. `404` si no existe o es de otro grupo.

---

## Lista de gastos fijos

Lo planificado de cada mes, por categoría. Pertenece al **grupo familiar** del usuario (cada usuario registrado por la API tiene el suyo). El admin ve y modifica los de todos. Un ítem de otro grupo responde `404`. Lo planificado se compara con el consumo real en `consumption_by_category` de `GET /dashboard` (campo `planned`).

### `GET /shopping_list_items`

Protegido. Lista los ítems ordenados por mes y nombre. Con `?period=AAAA-MM` trae solo ese mes.

```bash
curl "http://localhost:3000/api/v1/shopping_list_items?period=2026-11" -H "Authorization: Bearer <TOKEN>"
```

`200` (lista de **Ítem de la lista de gastos fijos**):

```json
[
  { "id": 1, "name": "Arroz", "period": "2026-11", "quantity": "2.0", "estimated_unit_price": "1500.0", "subtotal": "3000.0", "category": { "id": 1, "name": "Comida" } }
]
```

### `POST /shopping_list_items`

Protegido. El ítem queda en el grupo familiar del usuario; cualquier `family_group_id` enviado se ignora.

| Campo | Tipo | Obligatorio | Validación |
|-------|------|:-----------:|------------|
| `name` | string | Sí | no puede estar vacío |
| `period` | string `AAAA-MM` | Sí | mes válido, por ejemplo `2026-11` |
| `quantity` | number | No | mayor a 0 |
| `estimated_unit_price` | number | Sí | mayor o igual a 0 |
| `category_id` | integer | Sí | tiene que existir |

```bash
curl -X POST http://localhost:3000/api/v1/shopping_list_items \
  -H "Authorization: Bearer <TOKEN>" -H "Content-Type: application/json" \
  -d '{"name":"Fideos","period":"2026-11","quantity":3,"estimated_unit_price":800,"category_id":1}'
```

`201`: el ítem creado, con la forma **Ítem de la lista de gastos fijos**. `422` con datos inválidos:

```json
{ "errors": [ { "field": "period", "message": "debe tener formato AAAA-MM" } ] }
```

### `PATCH /shopping_list_items/:id`

Protegido. Acepta los mismos campos y reglas que `POST`, todos opcionales. Solo se modifica lo que se envía.

`200`: el ítem actualizado, con `subtotal` recalculado. `404` si no existe o es de otro grupo. `422` si hay datos inválidos.

### `DELETE /shopping_list_items/:id`

Protegido. `204`, sin cuerpo. `404` si no existe o es de otro grupo.

---

## Usuarios

### `GET /users`

Protegido, **solo admin**. Lista los usuarios. No devuelve contraseñas ni tokens.

```bash
curl http://localhost:3000/api/v1/users -H "Authorization: Bearer <TOKEN>"
```

`200` (lista de **Usuario**):

```json
[
  { "id": 1, "user": "admin", "email": null, "admin": true }
]
```

Con el token de un usuario común, `403`:

```json
{ "errors": [ { "field": "base", "message": "Acceso denegado" } ] }
```

---

## Endpoints planificados

Estos endpoints **todavía no existen** en la API: si el front los llama, recibe `404`. El front del TP2 no usa ninguno. Quedan documentados con la forma acordada para cuando se implementen.

| Método | Ruta | Protegido | Permiso |
|--------|------|:---------:|---------|
| GET | `/expenses/:id` | Sí | dueño del gasto o admin |

### `GET /expenses/:id` (planificado)

Protegido. Devuelve un gasto, con la forma **Gasto**.

```bash
curl http://localhost:3000/api/v1/expenses/<EXPENSE_ID> -H "Authorization: Bearer <TOKEN>"
```

`200`: un solo objeto, igual a un elemento de la lista de `GET /expenses`. `404` si no existe o no es del usuario.
