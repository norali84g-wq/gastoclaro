# Contrato de la API — GastoClaro

**Fecha:** 20/10/2026 · **Base URL:** `/api/v1` · **Formato:** JSON (`Content-Type: application/json`)

Este documento es el acuerdo entre front y back. Lo que está acá es lo que el front puede usar; si hay que cambiar algo, se cambia acá primero y se avisa por Trello.

**Estado de cada sección**

| Sección | Estado |
|---|---|
| 1. Convenciones, 2. Autenticación, 3. Categorías | **Completas** |
| 4. Gastos e ingresos, 5. Tarjetas, 6. Compras en cuotas, 7. Presupuestos, 8. Ahorro | Rutas, campos, reglas y errores. Falta un ejemplo de respuesta por endpoint |
| 9. Informes, 10. Análisis | Rutas y reglas de cálculo; el detalle de las respuestas se completa después |

---

## 1. Convenciones generales

- **Alcance:** todos los datos son personales. Cada usuario solo ve y modifica lo suyo. Pedir un recurso de otro usuario devuelve `404` (no `403`, para no revelar que existe).
- **Nombres:** rutas y campos en inglés, `snake_case`.
- **Autenticación:** header `Authorization: Bearer <token>` en todas las rutas, salvo las marcadas como públicas.
- **Montos:** siempre **enteros en centavos de peso argentino**, en campos que terminan en `_cents` (`250000` = $2.500,00). Nunca decimales ni strings. El front los formatea al mostrarlos con `Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS' })`.
- **Fechas:** `YYYY-MM-DD` (por ejemplo `"2026-10-19"`). Meses: `YYYY-MM` (por ejemplo `"2026-10"`); en la base se guardan como el día 1 del mes. Fecha y hora: ISO 8601 con zona (`2026-10-19T14:30:00-03:00`). Zona horaria del sistema: America/Argentina/Buenos_Aires.
- **Envoltorio en el cuerpo:** al crear o modificar, los datos van dentro del nombre del recurso: `{ "expense": { "amount_cents": 250000 } }`. Las rutas de auth no lo usan.
- **Paginación** en los listados de movimientos: `?page=1&per_page=50` (máximo 50). La respuesta trae `meta`:
  ```json
  { "data": [ ... ], "meta": { "page": 1, "per_page": 50, "total_count": 120, "total_pages": 3 } }
  ```
- **Respuestas con un solo recurso:** el objeto directo, sin envoltorio. **Listados:** `{ "data": [...] }` (con `meta` cuando está paginado).
- **Errores:** siempre el mismo formato. `field` es el campo con el problema, o `"base"` si el error es general:
  ```json
  { "errors": [ { "field": "amount_cents", "message": "debe ser mayor a 0" } ] }
  ```

**Códigos HTTP**

| Código | Cuándo |
|---|---|
| `200 OK` | Lectura o modificación correcta |
| `201 Created` | Recurso creado |
| `204 No Content` | Eliminación correcta (sin cuerpo) |
| `401 Unauthorized` | Falta el token, es inválido, venció o fue revocado |
| `404 Not Found` | El recurso no existe o es de otro usuario |
| `422 Unprocessable Entity` | Datos inválidos (validaciones) |
| `429 Too Many Requests` | Demasiados intentos de login (bloqueo de 5 minutos tras 5 fallos) |

---

## 2. Autenticación y perfil

El token es una cadena opaca que dura **30 días**. Se guarda hasheado en el servidor (tabla `sessions`), lo que permite invalidarlo al cerrar sesión.

### `POST /auth/register` — pública
Crea la cuenta, carga las categorías por defecto y deja al usuario autenticado.

Body:
```json
{ "name": "Norali", "email": "norali@example.com", "password": "clave12345", "password_confirmation": "clave12345" }
```
Respuesta `201`:
```json
{
  "token": "Vq3p...",
  "expires_at": "2026-11-18T10:00:00-03:00",
  "user": { "id": 1, "name": "Norali", "email": "norali@example.com" }
}
```
Errores `422`: correo con formato inválido, contraseña de menos de 8 caracteres, confirmación distinta, correo ya registrado (mensaje genérico, sin revelar datos de la cuenta existente).

### `POST /auth/login` — pública
Body: `{ "email": "norali@example.com", "password": "clave12345" }`
Respuesta `200`: igual que el registro.
Errores: `401` con `{ "errors": [ { "field": "base", "message": "Correo o contraseña incorrectos" } ] }` (sin decir cuál falló). `429` tras 5 intentos fallidos desde el mismo origen.

### `DELETE /auth/logout`
Invalida el token usado. Respuesta `204`. Cualquier pedido posterior con ese token devuelve `401`.

### `GET /me`
Respuesta `200`:
```json
{ "id": 1, "name": "Norali", "email": "norali@example.com", "created_at": "2026-10-19T10:00:00-03:00" }
```

### `PATCH /me`
Edita el nombre y/o la contraseña. El correo no se puede modificar en esta versión.
Body (todos opcionales): `{ "name": "Norali G.", "current_password": "...", "password": "nueva12345", "password_confirmation": "nueva12345" }`
Para cambiar la contraseña `current_password` es obligatoria. Respuesta `200` con el usuario. Errores `422`.

### `POST /auth/password/forgot` — pública
Body: `{ "email": "norali@example.com" }`. Responde **siempre** `200` con `{ "message": "Si el correo existe, te enviamos un enlace" }`. El enlace es de un solo uso y vence a las 2 horas.

### `POST /auth/password/reset` — pública
Body: `{ "token": "<token del enlace>", "password": "nueva12345", "password_confirmation": "nueva12345" }`. Respuesta `200`. Invalida todas las sesiones abiertas del usuario. Error `422` si el token venció o ya se usó.

### `GET /me/settings` y `PATCH /me/settings`
Configuración del usuario.
```json
{
  "small_expense_threshold_cents": 500000,
  "budget_alert_percent": 80,
  "card_due_alert_days": 3,
  "email_alerts": false,
  "needs_percent": 50,
  "wants_percent": 30,
  "savings_percent": 20
}
```
`needs_percent + wants_percent + savings_percent` debe ser 100 (si no, `422`). `budget_alert_percent` va de 1 a 100. `PATCH` acepta cualquier subconjunto de campos.

---

## 3. Categorías

**Objeto categoría**
```json
{
  "id": 3,
  "name": "Alimentos",
  "color": "#16A34A",
  "bucket": "needs",
  "parent_id": null,
  "favorite": false,
  "position": 0,
  "expenses_count": 12
}
```
- `bucket`: `needs` (necesidad), `wants` (deseo) o `null` (sin clasificar). **El ahorro no es una clasificación de categoría**: se registra con aportes (sección 8).
- `parent_id`: id de la categoría padre. Solo un nivel de anidamiento: una subcategoría no puede tener hijas.

### `GET /categories`
Lista todas las categorías del usuario (planas, ordenadas por `favorite` desc, `position`, `name`). Cada una incluye `expenses_count`. Respuesta `200`: `{ "data": [ {...}, ... ] }`.

### `POST /categories`
Body:
```json
{ "category": { "name": "Mascotas", "color": "#F59E0B", "bucket": "wants", "parent_id": null } }
```
Obligatorio: `name`. Respuesta `201` con la categoría.
Errores `422`: nombre vacío, nombre repetido dentro del mismo nivel, `bucket` inválido, `parent_id` que ya es una subcategoría.

### `GET /categories/:id`
Respuesta `200` con la categoría. Incluye `expenses_count` para que el front pueda avisar cuántos movimientos se verían afectados antes de borrar.

### `PATCH /categories/:id`
Body: cualquier subconjunto de `name`, `color`, `bucket`, `parent_id`, `favorite`, `position`. Respuesta `200`.
Error `422` si se intenta marcar como favorita una sexta categoría (máximo 5 favoritas).

### `DELETE /categories/:id`
Query opcional: `?reassign_to=<category_id>`.
- Con `reassign_to`: los gastos y las compras en cuotas de la categoría pasan a esa categoría.
- Sin `reassign_to`: quedan **sin categoría** (se muestran como "sin clasificar").

Los presupuestos de la categoría borrada se eliminan. Respuesta `204`. Error `422` si la categoría tiene subcategorías (hay que borrarlas o moverlas primero).

---

## 4. Gastos e ingresos

Un **gasto** es un pago único: efectivo, débito, transferencia o tarjeta **en 1 pago**. Una compra en cuotas **no** crea un gasto: se registra en la sección 6 y sus cuotas impactan en el mes en que se cobran.

### Gastos — objeto
```json
{
  "id": 10,
  "amount_cents": 420000,
  "spent_on": "2026-10-19",
  "description": "Café",
  "payment_method": "cash",
  "note": null,
  "category_id": 7,
  "card_id": null,
  "card_statement_id": null,
  "recurring_rule_id": null,
  "receipt_url": null,
  "created_at": "2026-10-19T10:15:00-03:00"
}
```
`payment_method`: `cash`, `debit`, `transfer`, `credit_card`. Si es `credit_card`, `card_id` es obligatorio y el gasto se imputa al resumen de la tarjeta según su fecha de cierre (`card_statement_id` lo asigna el servidor). `recurring_rule_id` viene lleno cuando el gasto lo generó una regla recurrente.

| Método y ruta | Descripción |
|---|---|
| `GET /expenses` | Lista paginada con filtros (ver abajo) |
| `POST /expenses` | Crea un gasto |
| `GET /expenses/:id` | Detalle |
| `PATCH /expenses/:id` | Modifica cualquier campo |
| `DELETE /expenses/:id` | Elimina (`204`) |
| `POST /expenses/:id/receipt` | Adjunta el comprobante (`multipart/form-data`, campo `file`; JPG, PNG o PDF, máx. 5 MB) |
| `DELETE /expenses/:id/receipt` | Quita el comprobante sin borrar el gasto |

**Carga rápida** (`POST /expenses`): solo `amount_cents` y `category_id` son obligatorios; `spent_on` toma por defecto el día de hoy y `payment_method` el valor `cash`.
```json
{ "expense": { "amount_cents": 420000, "category_id": 7 } }
```
Respuesta `201`: incluye además `"statement_preview"` cuando el medio de pago es tarjeta, indicando en qué resumen cae el gasto.
Errores `422`: monto menor o igual a 0, fecha posterior a hoy, `credit_card` sin `card_id`, `category_id` inexistente.

Al crear un gasto, el servidor revisa los presupuestos del mes y, si se alcanzó un umbral, registra una alerta (sección 7).

**Filtros de `GET /expenses`** (todos opcionales): `from`, `to` (fechas), `category_id`, `payment_method`, `min_amount_cents`, `max_amount_cents`, `q` (texto en la descripción), `page`, `per_page`. Orden fijo: fecha descendente.
La respuesta suma al `meta` el total de lo filtrado: `"total_amount_cents": 15230000`.

### Ingresos — objeto
```json
{ "id": 4, "amount_cents": 85000000, "received_on": "2026-10-01", "description": "Sueldo", "source": "salary", "recurring_rule_id": null }
```
`source`: `salary`, `fees`, `sale`, `other`.

| Método y ruta | Descripción |
|---|---|
| `GET /incomes` | Lista paginada. Filtros: `from`, `to`, `source`, `min_amount_cents`, `max_amount_cents`, `q` |
| `POST /incomes` | Crea. Obligatorios: `amount_cents`, `received_on` |
| `GET /incomes/:id`, `PATCH /incomes/:id`, `DELETE /incomes/:id` | Detalle, modificación, baja |

### Listado combinado
`GET /movements` — gastos e ingresos juntos, solo lectura, por fecha descendente. Filtros: los de gastos más `type` (`expense` o `income`). Cada elemento trae `"type"`. No incluye aportes de ahorro ni cuotas (esos se ven en sus secciones).

### Movimientos recurrentes
Una regla recurrente **genera** gastos o ingresos en cada fecha. Solo cuenta contra un presupuesto a través de los gastos que genera.

Objeto:
```json
{
  "id": 2, "kind": "expense", "amount_cents": 1500000, "description": "Alquiler",
  "category_id": 5, "payment_method": "transfer", "card_id": null, "source": null,
  "frequency": "monthly", "starts_on": "2026-10-05", "ends_on": null,
  "next_run_on": "2026-11-05", "last_run_on": "2026-10-05", "active": true
}
```

| Método y ruta | Descripción |
|---|---|
| `GET /recurring_rules` | Lista las reglas del usuario |
| `POST /recurring_rules` | Crea una regla: `kind` (`expense`/`income`), `amount_cents`, `description`, `category_id`, `payment_method`/`card_id` (gastos) o `source` (ingresos), `frequency` (`monthly`, `bimonthly`, `quarterly`, `yearly`), `starts_on`, `ends_on` (opcional) |
| `PATCH /recurring_rules/:id` | Modifica o da de baja (`"active": false`) sin borrar lo ya generado |
| `DELETE /recurring_rules/:id` | Elimina la regla (los movimientos generados se conservan) |

Errores `422`: `ends_on` anterior a `starts_on`, `frequency` inválida, `kind: expense` sin `payment_method`.

---

## 5. Tarjetas

Objeto: `id`, `nickname`, `issuer`, `last_four`, `closing_day` (1–31), `due_day` (1–31), `credit_limit_cents` (opcional), `active`. **Nunca** se guarda el número completo ni el código de seguridad.

| Método y ruta | Descripción |
|---|---|
| `GET /cards`, `POST /cards`, `GET /cards/:id`, `PATCH /cards/:id` | Alta, lectura y edición |
| `DELETE /cards/:id` | Si tiene consumos, no se elimina: queda inactiva (`active: false`). Sin consumos, se elimina |
| `GET /cards/:id/statements` | Resúmenes de la tarjeta. Filtro `?period=YYYY-MM` |
| `GET /card_statements/:id` | Detalle del resumen (ver abajo) |
| `GET /card_statements/:id/payments` | Pagos registrados de ese resumen |
| `POST /card_statements/:id/payments` | Registra un pago (total o parcial) |

**Resumen de tarjeta.** El resumen es lo que hay que pagar. Su total **no se guarda**: se calcula con los gastos con tarjeta y las cuotas que caen en el período.
```json
{
  "id": 8, "card_id": 2, "period": "2026-10", "closing_on": "2026-10-25", "due_on": "2026-11-05",
  "total_cents": 8500000, "paid_cents": 3000000, "status": "partial",
  "expenses": [ { "id": 10, "description": "Super", "amount_cents": 420000, "spent_on": "2026-10-19" } ],
  "installments": [ { "id": 31, "description": "Heladera", "number": 2, "of": 6, "amount_cents": 1200000 } ]
}
```
`status`: `pending` (nada pagado), `partial`, `paid`, `overdue` (vencido con saldo).

**Pago.** El pago es lo que efectivamente se pagó. Un resumen puede tener varios.
`POST /card_statements/:id/payments`
```json
{ "payment": { "paid_on": "2026-11-05", "amount_cents": 3000000, "interest_cents": 0 } }
```
Respuesta `201` con el pago. Errores `422`: monto menor o igual a 0, `interest_cents` negativo, fecha posterior a hoy.

---

## 6. Compras en cuotas

Una compra en cuotas **no crea un gasto**. El servidor genera sus cuotas, y cada cuota impacta en el mes de `billing_month`. En los informes y en los presupuestos se suman gastos más cuotas.

Objeto:
```json
{
  "id": 5, "description": "Heladera", "total_amount_cents": 7200000, "installments_count": 6,
  "purchased_on": "2026-09-10", "card_id": 2, "category_id": 9,
  "installments": [
    { "number": 1, "amount_cents": 1200000, "billing_month": "2026-10", "card_statement_id": 8, "paid": true }
  ]
}
```
- `installments_count` es un entero mayor a 1 (con 1 pago es un gasto común).
- **Redondeo:** el total se divide por la cantidad de cuotas y la diferencia de redondeo se suma a la **última** cuota, así la suma da exacto el total.
- `paid` es `true` cuando el resumen de esa cuota está pagado por completo.

| Método y ruta | Descripción |
|---|---|
| `GET /installment_purchases` | Lista con cuota actual sobre total. Filtro `?status=active|finished` |
| `POST /installment_purchases` | Crea la compra y genera las cuotas |
| `GET /installment_purchases/:id` | Detalle con cada cuota y su estado |
| `PATCH /installment_purchases/:id` | Recalcula las cuotas aún no pagadas y conserva las pagadas |
| `DELETE /installment_purchases/:id` | Elimina la compra y sus cuotas pendientes; si hay cuotas en resúmenes cerrados exige `?confirm=true` |
| `GET /commitments` | Compromiso futuro: total por cada uno de los próximos 12 meses, con detalle |
| `POST /installment_purchases/simulate` | Simula sin guardar: `{ "total_amount_cents": 12000000, "installments_count": 6 }` |

Errores `422`: `installments_count` menor o igual a 1, monto menor o igual a 0, tarjeta inexistente o inactiva.

---

## 7. Presupuestos

Un presupuesto es un **tope por mes**. Se compara contra lo que realmente se gastó. Puede ser de una categoría o subcategoría, o **general** del mes (`category_id: null`).

Objeto: `id`, `month` (`YYYY-MM`), `amount_cents`, `category_id` (`null` = presupuesto general del mes).
Reglas: un solo presupuesto por categoría y mes, y uno solo general por mes (`422` si se repite).

| Método y ruta | Descripción |
|---|---|
| `GET /budgets?month=YYYY-MM` | Presupuestos del mes |
| `POST /budgets`, `PATCH /budgets/:id`, `DELETE /budgets/:id` | Alta, modificación, baja |
| `POST /budgets/copy` | Copia al mes siguiente: `{ "from_month": "2026-10", "to_month": "2026-11" }` |
| `GET /budgets/progress?month=YYYY-MM` | Presupuestado contra gastado (ver abajo) |
| `GET /alerts` | Alertas del usuario, ordenadas por fecha (ver abajo) |
| `PATCH /alerts/:id/read` | Marca una alerta como leída |

**Cómo se calcula lo gastado.** Es la suma de los **gastos** del mes más las **cuotas** cuyo `billing_month` es ese mes.
- El real de una categoría padre incluye a sus subcategorías.
- El real del presupuesto general es todo lo gastado del mes.
- Los aportes de ahorro **no** cuentan como gasto.

`GET /budgets/progress`
```json
{
  "month": "2026-10",
  "data": [
    {
      "budget_id": 1, "category_id": null, "parent_id": null,
      "budgeted_cents": 90000000, "spent_cents": 61000000, "available_cents": 29000000,
      "percent_used": 67.8, "pace": "on_track"
    },
    {
      "budget_id": 2, "category_id": 3, "parent_id": null,
      "budgeted_cents": 20000000, "spent_cents": 18500000, "own_spent_cents": 9000000, "available_cents": 1500000,
      "percent_used": 92.5, "pace": "over_pace"
    }
  ]
}
```
`own_spent_cents` aparece en las categorías padre: lo gastado directamente en ella, sin las subcategorías. `pace`: `under`, `on_track` u `over_pace`, según lo gastado contra los días transcurridos del mes. **No sumar el presupuesto de un padre con el de sus hijos** para sacar totales: el del padre ya los incluye.

**Alertas.** Cuando un presupuesto llega al umbral del usuario (`budget_alert_percent`) o al 100 %, el servidor registra una alerta una sola vez por presupuesto y umbral. Los vencimientos de tarjeta próximos se calculan al consultar.
```json
{
  "data": [
    { "id": 4, "kind": "budget", "budget_id": 2, "category_id": 3, "threshold_percent": 80, "triggered_at": "2026-10-18T12:00:00-03:00", "read_at": null },
    { "id": null, "kind": "card_due", "card_statement_id": 8, "due_on": "2026-11-05", "days_left": 3 }
  ]
}
```

Errores `422`: monto menor o igual a 0, mes con formato inválido, presupuesto repetido para esa categoría y mes, `category_id` inexistente.

---

## 8. Ahorro

El ahorro tiene **metas**. Cada meta recibe **aportes**. Un aporte **no es un gasto**: ingreso = gastos + ahorro. El avance de la meta se calcula, no se guarda.

**Meta**
```json
{
  "id": 3, "name": "Viaje", "target_amount_cents": 150000000, "target_date": "2027-03-01",
  "saved_cents": 45000000, "remaining_cents": 105000000, "percent": 30.0, "achieved": false, "contributions_count": 4
}
```
`saved_cents` es la suma de los aportes; `achieved` es `true` cuando `saved_cents >= target_amount_cents`.

| Método y ruta | Descripción |
|---|---|
| `GET /savings_goals` | Lista las metas. El `meta` trae `total_saved_cents` |
| `POST /savings_goals` | Crea una meta. Obligatorios: `name`, `target_amount_cents`. Opcional: `target_date` |
| `GET /savings_goals/:id` | Detalle con el avance |
| `PATCH /savings_goals/:id` | Modifica nombre, monto objetivo o fecha |
| `DELETE /savings_goals/:id` | Elimina la meta y sus aportes. Si tiene aportes exige `?confirm=true` |
| `GET /savings_goals/:id/contributions` | Aportes de la meta, por fecha descendente |
| `POST /savings_goals/:id/contributions` | Registra un aporte |
| `PATCH /savings_contributions/:id`, `DELETE /savings_contributions/:id` | Modifica o elimina un aporte |

**Aporte**
```json
{ "contribution": { "amount_cents": 1000000, "contributed_on": "2026-10-20", "note": "Del sueldo" } }
```
Errores `422`: monto menor o igual a 0, fecha posterior a hoy, `target_amount_cents` menor o igual a 0, `name` vacío.

---

## 9. Informes

Parámetros comunes: `from`, `to` o `month`, y `constant_currency=true` para ver los montos ajustados por inflación. Un solo servicio (`ReportService`) reúne los cálculos.

| Ruta | Descripción |
|---|---|
| `GET /reports/summary` | Pantalla principal (ver abajo) |
| `GET /reports/by_category` | Totales por categoría; cada padre trae sus subcategorías |
| `GET /reports/monthly_evolution` | Evolución mensual de gastos, ingresos y ahorro |
| `GET /reports/comparison` | Comparación entre dos períodos |
| `GET /reports/export?format=csv|pdf` | Exportación del informe. `422` si el formato no existe |

**Reglas de cálculo**
- **Gastado** = gastos + cuotas del mes (por `billing_month`).
- **Ahorrado** = suma de aportes del mes.
- **Saldo sin asignar** = ingresos − gastado − ahorrado.
- **Variación %** = (actual − anterior) ÷ anterior × 100. Si el anterior es 0, se devuelve `null` ("sin dato").
- **Moneda constante** = monto nominal × IPC del período base ÷ IPC del período del gasto.

`GET /reports/summary?month=2026-10`
```json
{
  "month": "2026-10",
  "incomes_cents": 85000000, "spent_cents": 61000000, "saved_cents": 10000000, "unassigned_balance_cents": 14000000,
  "spent_variation_percent": 4.2,
  "last_movements": [ ],
  "upcoming_due_dates": [ ]
}
```

## 10. Análisis

| Ruta | Descripción |
|---|---|
| `GET /analysis/small_expenses` | Gastos hormiga del período: gastos por debajo de `small_expense_threshold_cents`, agrupados por categoría |
| `GET /analysis/rule_50_30_20` | Distribución real contra la referencia del usuario. Necesidades y deseos salen del `bucket` de la categoría; el ahorro, de los aportes |
| `GET /analysis/personal_inflation` | Variación del gasto propio por categoría contra el índice de referencia |
| `GET /price_indices` | Índice mensual de precios (solo lectura): `{ "period": "2026-09", "value": "7250.1234", "source": "INDEC" }` |

**El índice de precios es un dato global**, no es del usuario: se carga desde el back-office (o con una tarea de importación), no desde la API del usuario. Por eso esta API no tiene `POST /price_indices`.

La inflación personal se calcula por categoría. Hacerla por producto requiere registrar los ítems de cada compra, que hoy no están en el alcance.

---

## 11. Decisiones tomadas en este contrato

1. **Token opaco con tabla `sessions`** (y no JWT puro) para poder invalidarlo al cerrar sesión, como pide HU-03.
2. **Montos en centavos enteros** para evitar errores de redondeo, como se enseñó en Programación IV.
3. **`404` en recursos de otro usuario**, no `403`.
4. **Todo es personal:** no hay grupos ni gastos compartidos en el alcance.
5. **Borrado de categorías:** reasignación opcional con `reassign_to`; si no se indica, los movimientos quedan "sin clasificar".
6. **El ahorro no es un gasto:** se registra con aportes a metas.
7. **Obligación y pago separados:** el resumen de tarjeta es lo que hay que pagar; el pago es lo que se pagó, y puede ser parcial.
8. **Los datos derivados no se guardan:** total del resumen, avance de la meta, saldo, estado de pago.
9. **Los campos de fecha de gastos e ingresos son `spent_on` y `received_on`.**
