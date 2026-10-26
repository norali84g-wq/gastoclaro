# Contrato de la API — GastoClaro (TP2)

**Versión:** 0.1 · **Autora:** Norali · **Base URL:** `/api/v1` · **Formato:** JSON (`Content-Type: application/json`)

Este documento es el acuerdo entre el back-end (Rails) y el front-end (React). Lo que está acá es lo que el front puede usar. Si hay que cambiar algo, se cambia acá primero y se avisa por Trello.

## Estado de cada endpoint

| Estado | Significado |
|--------|-------------|
| `existe` | Ya funciona hoy en `main` con esta forma |
| `cambia` | Existe, pero la respuesta o los errores cambian (PR pendiente) |
| `falta` | Todavía no existe, está planificado |

## Convenciones

- **Alcance:** los datos son personales. Cada usuario ve y modifica solo lo suyo. El usuario `admin` ve los de todos y puede usar los endpoints marcados "solo admin".
- **Nombres:** rutas y campos en inglés, `snake_case`.
- **URL base:** `<API_URL>/api/v1`. En desarrollo, `http://localhost:3000/api/v1`. En el front, esta URL va en una variable de entorno, nunca escrita en el código.
- **Autenticación:** JWT. Se obtiene con `POST /login` o `POST /register` y se envía en cada pedido protegido:

  ```
  Authorization: Bearer <TOKEN>
  ```

  El token **vence a las 24 horas**. `DELETE /logout` lo invalida antes.
- **Montos:** se devuelven como **string decimal** (por ejemplo `"450000.0"`). Al enviar, se aceptan números.
- **Fechas:** `YYYY-MM-DD`. Los períodos del dashboard, `YYYY-MM`.
- **Recurso de otro usuario:** devuelve `404`, no `403`, para no revelar que existe.
- **Valores cerrados:** `purchase_channel` es `presencial`, `delivery` o `retiro`. `unit` (en los ítems de un gasto) es `unidad`, `kg` o `g`. La API devuelve estos códigos tal cual; el front los traduce para mostrarlos.
- **CORS:** la API acepta pedidos del origen configurado en la variable de entorno `FRONTEND_URL` (en desarrollo, `http://localhost:5173`) y acepta el header `Authorization`. El origen se nombra siempre de forma explícita, nunca con `*`.
- **Alcance del TP2:** las categorías son planas (`parent_id` y `tracks_installments` valen siempre `null` y el front los ignora) y el comercio (`vendor_id`) no se usa: no hay endpoint para listar comercios.
- **Vencimiento del token:** `POST /login` y `POST /register` devuelven `expires_at` (ISO 8601 con zona horaria) para avisar al usuario antes de que se caiga la sesión. Aun así, el front tiene que manejar un `401` en cualquier pedido: el token puede dejar de servir antes, por ejemplo si se cierra la sesión desde otro dispositivo.

## Formato de errores

Todos los errores usan la misma forma, igual que el contrato del TFI. `field` es el campo con el problema, o `"base"` si el error es general. `message` está en español y se puede mostrar al usuario:

```json
{ "errors": [ { "field": "amount", "message": "debe ser mayor a 0" } ] }
```

El front usa `field` para marcar el campo del formulario con error. Si `field` es `"base"`, muestra el mensaje como aviso general.

Reglas:

- El `field` se llama igual que el campo que el front envió (por ejemplo `category_id`, no `category`).
- Un `422` trae **todos** los errores de validación juntos, no solo el primero.
- Excepción conocida: los errores de los ítems de un gasto llegan como `expense_items.name`, no como `expense_items_attributes[0][name]`.

| HTTP | Cuándo ocurre | Ejemplo de `field` y `message` |
|:----:|---------------|-------------------------------|
| 401 | Falta el token, es inválido, venció o se cerró la sesión | `base` — "No autorizado" |
| 401 | Usuario o contraseña incorrectos en el login | `base` — "Usuario o contraseña incorrectos" |
| 403 | El usuario no tiene permiso (por ejemplo, no es admin) | `base` — "Acceso denegado" |
| 404 | El recurso no existe o es de otro usuario | `base` — "No encontrado" |
| 422 | Datos de entrada inválidos | el campo y su problema, por ejemplo `amount` — "debe ser mayor a 0" |

## Resumen de endpoints

| Método | Ruta | Protegido | Permiso | Estado |
|--------|------|:---------:|---------|:------:|
| POST | `/login` | No | — | cambia (errores y usuario) |
| DELETE | `/logout` | Sí | cualquier usuario | existe |
| POST | `/register` | No | — | cambia (errores y usuario) |
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

Protegido. Devuelve el usuario del token. Sirve para que el front sepa quién está logueado y si es admin al recargar la página. El campo `admin` sirve solo para decidir qué mostrar; los permisos los controla siempre la API.

`200`:

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
    { "category": "Servicios", "total": "25000.0" },
    { "category": "Supermercado", "total": "13101.0" }
  ],
  "monthly_savings": [
    { "month": "2026-09", "income": "450000.0", "consumption": "38101.0", "savings": "411899.0", "accumulated": "411899.0" }
  ]
}
```

`monthly_savings` trae los últimos 6 meses, del más antiguo al más reciente.

`savings_goal_percentage` es un entero de 0 a 100, nunca `null`. Para un usuario recién registrado vale `0`.

---

## Categorías

### `GET /categories`

Protegido. Lista todas las categorías (globales), ordenadas por nombre. En el TP2 son planas: `parent_id` y `tracks_installments` valen siempre `null` y el front los ignora.

`200`:

```json
[
  { "id": 3, "name": "Servicios", "parent_id": null, "tracks_installments": null },
  { "id": 1, "name": "Supermercado", "parent_id": null, "tracks_installments": null }
]
```

---

## Gastos

### `GET /expenses`

Protegido. Gastos del usuario, del más reciente al más antiguo (el admin ve los de todos). Parámetro opcional `?period=YYYY-MM` para traer solo un mes. La respuesta tiene un tope de 100 gastos, sin paginación.

`200`:

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
    "vendor_id": 1,
    "category": { "id": 1, "name": "Supermercado" },
    "expense_items": [
      { "id": 1, "name": "Leche", "quantity": 2, "unit": "unidad", "unit_price": "1800.5", "subtotal": "3601.0" }
    ]
  }
]
```

### `GET /expenses/:id` (falta)

Protegido. Devuelve un gasto, con la misma forma que un elemento de `GET /expenses`. `404` si no existe o no es del usuario.

### `POST /expenses`

Protegido. El gasto queda a nombre del usuario del token.

| Campo | Tipo | Obligatorio | Validación |
|-------|------|:-----------:|------------|
| `date` | string `YYYY-MM-DD` | Sí | — |
| `category_id` | integer | Sí | tiene que existir |
| `amount` | number | Sí, si no hay ítems | mayor a 0 |
| `description` | string | No | — |
| `vendor_id` | integer | No | tiene que existir. No se usa en el TP2: el front no lo envía |
| `is_fixed` | boolean | No | por defecto `false` |
| `purchase_channel` | string | No | `presencial`, `delivery` o `retiro` (por defecto `presencial`) |
| `expense_items_attributes` | array | No | cada ítem: `name` (obligatorio), `quantity` (mayor a 0), `unit` (`unidad`, `kg` o `g`), `unit_price` (mayor o igual a 0) |

Si se envían ítems, el front no envía `amount`: lo calcula el servidor como la suma de `quantity × unit_price`. Si llegaran los dos, gana el calculado y no es un error.

```bash
curl -X POST http://localhost:3000/api/v1/expenses \
  -H "Authorization: Bearer <TOKEN>" -H "Content-Type: application/json" \
  -d '{"amount":25000,"date":"2026-09-05","category_id":3,"description":"Luz","is_fixed":true}'
```

`201`: el gasto creado, con la misma forma que un elemento de `GET /expenses`.

`422` con datos inválidos:

```json
{ "errors": [ { "field": "purchase_channel", "message": "no es válido" } ] }
```

Un `vendor_id` que no existe devuelve `422` con `field` `vendor_id` y el mensaje "no existe". Un `category_id` que no existe también devuelve `422`, con `field` `category_id` y el mensaje "debe existir". Si hay varios campos inválidos, la API los devuelve todos juntos en la misma respuesta.

### `PATCH /expenses/:id` (falta)

Protegido. Edita un gasto. Acepta los mismos campos que `POST`, todos opcionales. `200` con el gasto actualizado. `404` si no existe o no es del usuario. `422` si hay datos inválidos.

### `DELETE /expenses/:id` (falta)

Protegido. Borra un gasto. `204` sin cuerpo. `404` si no existe o no es del usuario.

---

## Ingresos

### `GET /incomes` (falta)

Protegido. Ingresos del usuario, del más reciente al más antiguo (el admin ve los de todos).

`200`:

```json
[
  { "id": 1, "amount": "450000.0", "date": "2026-09-01" }
]
```

### `POST /incomes`

Protegido. El ingreso queda a nombre del usuario del token; cualquier `user_id` enviado se ignora.

| Campo | Tipo | Obligatorio | Validación |
|-------|------|:-----------:|------------|
| `amount` | number | Sí | mayor a 0 |
| `date` | string `YYYY-MM-DD` | Sí | — |

```bash
curl -X POST http://localhost:3000/api/v1/incomes \
  -H "Authorization: Bearer <TOKEN>" -H "Content-Type: application/json" \
  -d '{"amount":450000,"date":"2026-09-01"}'
```

`201`:

```json
{ "id": 1, "amount": "450000.0", "date": "2026-09-01" }
```

`422`:

```json
{ "errors": [ { "field": "amount", "message": "debe ser mayor a 0" } ] }
```

### `PATCH /incomes/:id` (falta)

Protegido. Edita un ingreso (`amount`, `date`, opcionales). `200` con el ingreso actualizado. `404` o `422` como en gastos.

### `DELETE /incomes/:id` (falta)

Protegido. Borra un ingreso. `204` sin cuerpo. `404` si no existe o no es del usuario.

---

## Usuarios

### `GET /users`

Protegido, **solo admin**. Lista los usuarios. No devuelve contraseñas ni tokens.

`200`:

```json
[
  { "id": 1, "user": "admin", "email": null, "admin": true }
]
```

Con el token de un usuario común, `403`:

```json
{ "errors": [ { "field": "base", "message": "Acceso denegado" } ] }
```
