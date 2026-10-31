# GastoClaro

GastoClaro es una aplicación web de gestión de gastos personales hecha con Ruby on Rails, pensada para dejar atrás las planillas de Excel o las anotaciones en papel, donde es fácil olvidarse de registrar algo. Cada usuario registra sus ingresos y gastos (con detalle por ítem, comercio y canal de compra) organizados por categorías, define metas de ahorro, controla sus compras en cuotas y arma una lista de compras con lo que estima gastar, para después compararla con lo que realmente gastó y saber en qué se le fue la plata. Incluye un back-office web para administrar todo y una API JSON (v1) pensada para clientes externos, por ejemplo una app móvil.

**Stack:** Ruby 3.4.10, Rails 8.1, SQLite, Puma, Hotwire (Turbo + Stimulus) e importmap.

## Sobre el proyecto

- **Trabajo:** TP2 de Programación IV (Tecnicatura Universitaria en Programación). Integra este back-end con un front-end propio.
- **Temática:** gestión de gastos personales (ver la descripción de arriba).
- **Integrantes:** Norali Gorosito y Nico Ventureira.
- **Modalidad:** grupal.
- **Autoría del back-end original:** Norali Gorosito (TP1 individual, que se evolucionó en este TP2).
- **Front-end:** React, en el repositorio [gastoClaro-front](https://github.com/ventureiranm/gastoClaro-front). Su instalación, versiones, variables de entorno y comandos (pruebas y compilación) están en el README de ese repositorio.
- **Contrato de la API:** [`api.md`](api.md).

## Índice

1. [Requisitos e instalación](#requisitos-e-instalación)
2. [Datos de prueba y credenciales de demostración](#datos-de-prueba-y-credenciales-de-demostración)
3. [Back-office (panel de administración)](#back-office-panel-de-administración)
4. [API v1](#api-v1)
5. [Modelo de datos](#modelo-de-datos)
6. [Calidad y tests](#calidad-y-tests)
7. [Evolución futura](#evolución-futura)

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

**Variables de entorno:**

| Variable | Para qué sirve | Valor por defecto |
|----------|----------------|-------------------|
| `FRONTEND_URL` | Origen, o lista de orígenes separados por comas, desde los que el front en React puede llamar a la API (CORS). Ejemplo: `https://app.ejemplo.com,http://localhost:5174`. Una barra final se ignora. | En desarrollo y test: `http://localhost:5173` (Vite). **En producción es obligatoria**: sin ella la app no arranca. |

Si el front corre en otro puerto, levantá el servidor así: `FRONTEND_URL=http://localhost:5174 bin/rails server`.

**Antes de desplegar:** en `config/deploy.yml` la variable `FRONTEND_URL` está comentada. Hay que descomentarla y poner la URL real del front; sin ella la app no arranca en producción.

## Datos de prueba y credenciales de demostración

`bin/rails db:setup` (o `bin/rails db:seed` si la base ya existe) carga los datos de `db/seeds.rb`. Se puede correr más de una vez sin duplicar nada.

| Usuario | Contraseña | Qué es |
|---------|------------|--------|
| `admin` | `admin1234` | Administrador. Entra al back-office y a la API. No tiene email. |
| `demo` | `demo1234` | Usuario común de demostración (`demo@example.com`), con 2 ingresos y 3 gastos para que el panel muestre datos. **Solo se crea fuera de producción.** |

El seed también crea las dos categorías de ejemplo del contrato de la API (Supermercado y Limpieza).

> **Solo para desarrollo.** Estas credenciales están en el repositorio y no son de cuentas reales. No las uses en un entorno real: cambiá las contraseñas o eliminá los usuarios antes de publicar.

## Back-office (panel de administración)

- **URL de acceso:** <http://localhost:3000/admin/login>
- **Usuario de prueba** (lo crea `db/seeds.rb`, junto con el grupo familiar "Familia Gorosito"):

  | Usuario | Contraseña |
  |---------|------------|
  | `admin` | `admin1234` |

> **Solo para desarrollo.** Esta credencial está en el repositorio. No la uses en un entorno real: cambiá la contraseña o eliminá el usuario antes de publicar.

Solo pueden ingresar los usuarios con el flag `admin`. Una vez dentro, el back-office ofrece estas secciones (rutas bajo `/admin`): panel principal, gastos, ingresos, categorías, compras en cuotas, comercios (vendors), metas de ahorro, usuarios, lista de compras (con carga por lote), ahorro y estadísticas.

## API v1

La API devuelve y recibe JSON y todas sus rutas cuelgan de `/api/v1`. **El contrato completo está en [`api.md`](api.md)**: rutas, campos, validaciones, permisos, errores y ejemplos reproducibles. Esa es la única fuente de la documentación de la API; este README no la repite para que no queden dos versiones distintas.

Lo básico para empezar:

1. `POST /api/v1/login` con `user` y `password` devuelve un `token` (JWT) y cuándo vence (`expires_at`).
2. En cada pedido protegido se envía `Authorization: Bearer <TOKEN>`. El token vence a las 24 horas, y `DELETE /api/v1/logout` lo invalida antes.
3. Un usuario común ve solo sus datos. El administrador ve los de todos.
4. Los errores (`400`, `401`, `403`, `404` y `422`) tienen todos la misma forma: `{ "errors": [ { "field": "...", "message": "..." } ] }`. Los textos están en `config/locales/es.yml`.
5. En `api.md` cada endpoint indica su estado (`existe`, `cambia` o `falta`).

Con la base cargada con `db:seed`, se puede probar entrando con `demo` / `demo1234` (ver [Datos de prueba](#datos-de-prueba-y-credenciales-de-demostración)).

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
| `User` | Usuario del grupo. Tiene contraseña con `has_secure_password`, un `token_version` que invalida los tokens de la API al cerrar sesión y el flag `admin` para el back-office |
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

Comandos, desde la raíz del proyecto:

```bash
bin/rails test      # pruebas automatizadas
bin/rubocop         # estilo del código
bin/brakeman        # análisis de seguridad
```

Estado verificado al 2026-10-31: **120 tests, 365 assertions, 0 fallas, 0 errores, 0 omitidos.** Cubren los endpoints de la API v1, los modelos, parte del back-office y los mailers.

- **Rubocop:** 107 archivos inspeccionados, **0 ofensas**.
- **Brakeman:** **0 advertencias activas**. Hay 2 advertencias ignoradas a propósito, ambas falsos positivos de mass assignment en `Admin::UsersController`, justificados y documentados en `config/brakeman.ignore`. Esa pantalla solo es accesible para administradores logueados y existe justamente para que un admin cree usuarios y los marque como administradores.

**Lo que hoy no está cubierto por tests:** las pantallas del back-office de gastos, ingresos, usuarios, comercios, compras en cuotas, lista de compras, ahorro y estadísticas, y no hay tests de sistema (navegador).

Los comandos de pruebas y de compilación del front-end están en el README de su repositorio.

## Evolución futura

Estas funcionalidades **quedaron fuera del alcance de esta entrega** y son una **idea planeada a futuro**. Hoy no están implementadas.

- **Lectura automática de tickets y facturas (OCR):** sacar una foto del comprobante y que la app cargue sola el comercio, la fecha y los ítems del gasto. El modelo de gastos ya admite adjuntar una imagen de comprobante y guardar ítems con precio unitario, que serían la base para esto.
- **Comparación de precios entre comercios:** con los precios por ítem y el comercio de cada compra, comparar cuánto cuesta el mismo producto en distintos lugares y ayudar a elegir dónde comprar.
- **Presupuesto por categoría:** definir un monto objetivo mensual por categoría de gasto (por ejemplo, Alimentos) y mostrar el consumo acumulado contra ese objetivo, con una alerta visual cuando se acerca o supera el límite.
- **Carga de gastos por chat (WhatsApp o un asistente con IA):** registrar un gasto escribiendo un mensaje en lenguaje natural ("gasté 5000 en el supermercado"), en vez de completar el formulario manualmente.
