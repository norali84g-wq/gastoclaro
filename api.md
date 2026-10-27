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
| Formato de errores `{ "errors": [...] }` en los `401` | `{ "error": "..." }` | PR #37 |
| Mensajes de error en español | en inglés (falta `es.yml`) | PR #37 |
| `GET /me` y usuario en la respuesta de login y register | no existe | PR #39 |
| CORS | no hay `cors.rb` | PR #25 |
| `expires_at` en login y register | no se devuelve | sin PR todavía |
| `422` con `field: "period"` si `?period` es inválido | no valida | sin PR todavía |
| `422` si un ítem de gasto llega sin `name` | el ítem se descarta en silencio | PR aparte |
| `400` si el JSON está mal formado | Rails responde con su propio formato | sin PR todavía |
| Categorías de ejemplo en `db/seeds.rb` (Supermercado y Limpieza) | el seed no crea categorías | PR aparte |

## Convenciones

- **Alcance:** los datos son personales. Cada usuario ve y modifica solo lo suyo. El usuario `admin` ve los de todos y puede usar los endpoints marcados "solo admin".
- **Nombres:** rutas y campos en inglés, `snake_case`.
- **URL base:** `<API_URL>/api/v1`. En desarrollo, `http://localhost:3000/api/v1`. En el front, esta URL va en una variable de entorno, nunca escrita en el código.
- **`Content-Type: application/json`:** es **obligatorio** en todos los `POST` y `PATCH`. En los `GET` y `DELETE` no hace falta.
- **Autenticación:** JWT. Se obtiene con `POST /login` o `POST /register` y se envía en cada pedido protegido:

  ```
  Authorization: Bearer <TOKEN>
  ```

  El token **vence a las 24 horas**. `POST /login` y `POST /register` devuelven `expires_at` (ISO 8601 con zona horaria) para avisar al usuario antes de que se caiga la sesión. `DELETE /logout` lo invalida antes. Aun así, el front tiene que manejar un `401` en cualquier pedido: el token puede dejar de servir antes, por ejemplo si se cierra la sesión desde otro dispositivo.
- **Parámetro de ruta `:id`:** siempre es un entero positivo. Un `:id` que no existe o es de otro usuario devuelve `404`.
- **Montos:** se devuelven como **string decimal** (por ejemplo `"450000.0"`). Al enviar, se aceptan números.
- **Fechas:** `YYYY-MM-DD`. Los períodos, `YYYY-MM`. Una fecha inexistente (`2026-02-30`) o con otro formato (`05/09/2026`) devuelve `422` con `field` `date` y el mensaje "no puede estar en blanco": la API no distingue entre una fecha vacía y una inválida.
- **Recurso de otro usuario:** devuelve `404`, no `403`, para no revelar que existe.
- **Valores cerrados:** `purchase_channel` es `presencial`, `delivery` o `retiro`. `unit` (en los ítems de un gasto) es `unidad`, `kg` o `g`. La API devuelve estos códigos tal cual; el front los traduce para mostrarlos.
- **CORS:** la API acepta pedidos del origen configurado en la variable de entorno `FRONTEND_URL` (en desarrollo, `http://localhost:5173`) y acepta el header `Authorization`. El origen se nombra siempre de forma explícita, nunca con `*`.
- **Alcance del TP2:** el comercio (`vendor_id`) no se usa: vale siempre `null` y no hay endpoint para listar comercios. Las categorías son planas (`parent_id` y `tracks_installments` valen siempre `null`) y el front los ignora.

## Cómo reproducir los ejemplos

Los ejemplos usan marcadores entre `<>` que hay que reemplazar. Los `id` que aparecen en las respuestas son solo ilustrativos: dependen del orden en que se crearon los datos.

| Marcador | Qué poner |
|----------|-----------|
| `<TOKEN>` | el `token` que devuelve `POST /login` |
| `<CATEGORY_ID>` | un `id` de `GET /categories` (en el JSON va como número, sin comillas) |
| `<EXPENSE_ID>` / `<INCOME_ID>` | el `id` que devolvió el `POST` correspondiente |

Con una base nueva (`bin/rails db:setup`) existe el usuario `admin` (ver `db/seeds.rb`), pero **no hay categorías** y `GET /categories` devuelve `[]`. Hasta que el seed las cree, se cargan desde el panel web `/admin/categories` (con el usuario admin) o con `bin/rails console`. La API no tiene endpoint para crear categorías. Cuando el seed las incluya (va a crear dos: Supermercado y Limpieza), alcanza con `bin/rails db:seed`.

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
| POST | `/login` | No | — | cambia (errores, usuario y `expires_at`) |
| DELETE | `/logout` | Sí | cualquier usuario | existe |
| POST | `/register` | No | — | cambia (errores, usuario y `expires_at`) |
| GET | `/me` | Sí | cualquier usuario | falta |
| GET | `/dashboard` | Sí | cualquier usuario | cambia (nombres de campos) |
| GET | `/categories` | Sí | cualquier usuario | existe |
| GET | `/expenses` | Sí | cualquier usuario | cambia (período, tope y usuario) |
| GET | `/expenses/:id` | Sí | dueño del gasto o admin | falta |
| POST | `/expenses` | Sí | cualquier usuario | cambia (errores) |
| PATCH | `/expenses/:id` | Sí | dueño del gasto o admin | falta |
| DELETE | `/expenses/:id` | Sí | dueño del gasto o admin | falta |
| GET | `/incomes` | Sí | cualquier usuario | falta |
| POST | `/incomes` | Sí | cualquier usuario | cambia (errores) |
| PATCH | `/incomes/:id` | Sí | dueño del ingreso o admin | falta |
| DELETE | `/incomes/:id` | Sí | dueño del ingreso o admin | falta |
| GET | `/users` | Sí | solo admin | cambia (errores) |

Más adelante se prevén endpoints de metas de ahorro y compras en cuotas. Se agregan acá cuando se definan.

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
| `parent_id` | integer | **Sí** | siempre `null` en el TP2 |
| `tracks_installments` | boolean | **Sí** | siempre `null` en el TP2 |

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
| `vendor_id` | integer | **Sí** | siempre `null` en el TP2 |
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
| `user` | objeto `{ id, user }` | No | a quién pertenece. Importa para el admin, que ve los de todos |

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
  "expires_at": "2026-10-27T03:14:00-03:00",
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
  "expires_at": "2026-10-27T03:14:00-03:00",
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

### `GET /me` (falta)

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

`200` (nombres **nuevos**; hoy el back devuelve versiones en español de estos campos y cambia en un PR aparte):

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
    { "category": "Limpieza", "total": "25000.0" },
    { "category": "Supermercado", "total": "13101.0" }
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
| `incomes` | los ingresos del mes, del más antiguo al más reciente |
| `consumption_by_category` | el consumo del mes agrupado por nombre de categoría |
| `monthly_savings` | los últimos 6 meses, del más antiguo al más reciente |
| `monthly_savings[].accumulated` | ahorro acumulado: la suma corrida de `savings` dentro de esos 6 meses. El primer mes de la lista parte de 0, así que **no** es el ahorro de toda la vida |

---

## Categorías

### `GET /categories`

Protegido. Lista todas las categorías (globales), ordenadas por nombre. Con una base nueva devuelve `[]` hasta que se carguen (ver "Cómo reproducir los ejemplos").

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

---

## Gastos

### `GET /expenses`

Protegido. Gastos del usuario, del más reciente al más antiguo (el admin ve los de todos).

| Parámetro de consulta | Tipo | Obligatorio | Qué hace |
|-----------------------|------|:-----------:|----------|
| `period` | string `YYYY-MM` | No | trae solo los gastos de ese mes. Si el valor es inválido (por ejemplo `2026-13`), responde `422` con `field` `period` y el mensaje "no es válido" (`falta`: hoy no lo valida) |

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

### `GET /expenses/:id` (falta)

Protegido. Devuelve un gasto, con la forma **Gasto**.

```bash
curl http://localhost:3000/api/v1/expenses/<EXPENSE_ID> -H "Authorization: Bearer <TOKEN>"
```

`200`: un solo objeto, igual a un elemento de la lista de arriba. `404` si no existe o no es del usuario.

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
| `quantity` | integer | No | entero mayor a 0; por defecto `1`. **No admite decimales**: para fracciones, usá `g` (1,5 kg = `1500` con `unit` `g`) |
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

### `PATCH /expenses/:id` (falta)

Protegido. Edita un gasto. Acepta los mismos campos y reglas que `POST`, todos opcionales. Solo se modifica lo que se envía.

```bash
curl -X PATCH http://localhost:3000/api/v1/expenses/<EXPENSE_ID> \
  -H "Authorization: Bearer <TOKEN>" -H "Content-Type: application/json" \
  -d '{"description":"Compra del sábado"}'
```

`200`: el gasto actualizado, con la forma **Gasto**. `404` si no existe o no es del usuario. `422` si hay datos inválidos.

**Editar o borrar ítems.** Para modificar un ítem que ya existe, se envía su `id`. Para borrarlo, se envía su `id` con `"_destroy": true`. Un ítem sin `id` se crea nuevo:

```bash
curl -X PATCH http://localhost:3000/api/v1/expenses/<EXPENSE_ID> \
  -H "Authorization: Bearer <TOKEN>" -H "Content-Type: application/json" \
  -d '{"expense_items_attributes":[{"id":1,"quantity":3},{"id":2,"_destroy":true}]}'
```

`amount` se recalcula con los ítems que quedan. **Atención:** si se borran todos los ítems, el gasto conserva el `amount` anterior; para fijar otro monto, enviá también `amount` en el mismo pedido.

### `DELETE /expenses/:id` (falta)

Protegido. Borra un gasto y sus ítems.

```bash
curl -X DELETE http://localhost:3000/api/v1/expenses/<EXPENSE_ID> -H "Authorization: Bearer <TOKEN>"
```

`204`, sin cuerpo. `404` si no existe o no es del usuario.

---

## Ingresos

### `GET /incomes` (falta)

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

`201` (forma **Ingreso**):

```json
{ "id": 1, "amount": "450000.0", "date": "2026-09-01", "user": { "id": 1, "user": "admin" } }
```

`422`:

```json
{ "errors": [ { "field": "amount", "message": "debe ser mayor a 0" } ] }
```

### `PATCH /incomes/:id` (falta)

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

`404` si no existe o no es del usuario. `422` si hay datos inválidos, igual que en `POST`.

### `DELETE /incomes/:id` (falta)

Protegido. Borra un ingreso.

```bash
curl -X DELETE http://localhost:3000/api/v1/incomes/<INCOME_ID> -H "Authorization: Bearer <TOKEN>"
```

`204`, sin cuerpo. `404` si no existe o no es del usuario.

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
