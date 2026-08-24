# Reglas de SQL — producción

**Esta base de datos es producción.** Un solo proyecto de Supabase, sin staging,
sin backups automáticos (plan Free) y con dos años de datos reales de personas:
nombres, DNI, teléfonos y contratos de inquilinos.

Estas reglas están escritas después de romper cosas de verdad, no en abstracto.

---

## Nunca, bajo ninguna circunstancia

| Prohibido | Por qué |
|---|---|
| `DROP TABLE` / `DROP SCHEMA` / `TRUNCATE` | Irreversible sin backup, y no hay backup |
| `DELETE` sin `WHERE` | Lo mismo, con más pasos |
| `UPDATE` sin `WHERE` | Toca todas las filas de la tabla |
| Ejecutar SQL generado sin leerlo entero | Si no lo entiendes, no lo pegues |
| Tocar el esquema `auth` a mano | Un usuario sin su fila en `auth.identities` existe pero no puede entrar |
| `ALTER TABLE ... DROP COLUMN` | La app en producción sigue leyendo esa columna |

## Antes de cualquier escritura

1. **Cuenta primero.** Haz el `SELECT count(*)` equivalente y comprueba que el
   número es el que esperas antes de ejecutar el `UPDATE`/`DELETE`.
2. **Un `WHERE` que identifique la fila**, no un filtro amplio.
3. **Comprueba lo que devuelve.** `UPDATE 1` cuando esperabas 1. Si dice
   `UPDATE 0`, no ha pasado nada: no lo repitas a ciegas, averigua por qué.
4. **Ten a mano la vuelta atrás** antes de ejecutar, no después.

## RLS: lo que ya salió mal

Activar RLS en todas las tablas **rompió la creación de propiedades**. El motivo:
`createProperty` insertaba en `properties` pero nadie creaba la fila de
`property_access` del dueño, y `fetchProperties` filtra estrictamente por esa
tabla. La propiedad se creaba y era invisible para quien la creó.

- **No actives RLS tabla por tabla sin comprobar quién escribe cada fila
  relacionada.** Una tabla protegida cuya fila hermana no se crea deja
  funcionalidad muerta y silenciosa.
- **Comprueba las políticas que ya existen** antes de añadir las tuyas.
  `properties` acabó con 9 políticas solapadas de dos tandas distintas.
- Las políticas de **Storage** son otro mundo: `storage.objects` no sigue las
  reglas de las tablas, y las rutas aquí tienen **dos formatos** conviviendo
  (`<room_id>/…` desde iOS y `room-photos/<property_id>/…` desde la webapp).
  Una política que asuma uno solo deniega el acceso a todo.

## Funciones `SECURITY DEFINER`

Se saltan la RLS por diseño. Por tanto:

1. **Comprueban quién llama**, siempre: `auth.uid()`, nunca un parámetro con el
   id del usuario. Un parámetro lo pone quien llama.
2. **`SET search_path`** fijo.
3. **Sin `EXECUTE` para `anon`** salvo que sea deliberado y esté justificado.

Esto no es teórico: `grant_admin(email)` no comprobaba nada y estaba abierta al
rol `anon`. Con la clave pública que va dentro de la app, cualquiera podía
hacerse premium con un `curl`.

## Migraciones

- **Todo cambio va a `supabase/migrations/`**, aunque lo ejecutes a mano en el
  editor. Si no, repo y producción divergen — y ya divergieron: `delete_account`
  y `apply_premium_purchase` llevaban meses en el repo **sin aplicar**, así que
  borrar cuenta fallaba siempre y quien pagara no recibía premium.
- El nombre lleva fecha y describe el cambio.
- Antes de dar por buena una migración, **verifica en la base** que quedó
  aplicada. `list_migrations` devolvía cero: nada de lo del repo estaba puesto.

## Lo que puede hacer Claude

- **Leer**: el MCP de Supabase está configurado con `--read-only`. Puede
  consultar esquema, políticas, triggers y datos para diagnosticar.
- **Escribir: no.** Redacta la migración, la deja en `supabase/migrations/` y la
  ejecutas tú. Esa separación es intencionada, no una limitación a rodear.
