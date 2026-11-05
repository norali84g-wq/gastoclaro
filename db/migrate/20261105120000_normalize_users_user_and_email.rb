# Normaliza el nombre de usuario y el correo (sin espacios y en minúsculas) y deja
# el índice único del nombre de usuario sobre el valor ya normalizado.
#
# Si al normalizar dos filas quedan iguales (por ejemplo "demo" y "Demo"), aborta sin
# tocar nada: decidir qué usuario sobrevive y qué pasa con sus datos no lo puede
# resolver una migración sola.
class NormalizeUsersUserAndEmail < ActiveRecord::Migration[8.1]
  class MigrationUser < ActiveRecord::Base
    self.table_name = "users"
  end

  def up
    MigrationUser.reset_column_information
    ensure_no_collisions!(:user)
    ensure_no_collisions!(:email)

    MigrationUser.find_each do |row|
      changes = { user: normalize(row.user) }
      changes[:email] = normalize(row.email) unless row.email.nil?
      changes.reject! { |column, value| row[column] == value }
      row.update_columns(changes) if changes.any?
    end

    add_index :users, :user, unique: true, name: "index_users_on_user" unless index_exists?(:users, :user, unique: true)
    # El índice único del correo (index_users_on_email_unique) ya existe y, con los
    # valores normalizados, alcanza.
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          "Pasar a minúsculas y recortar espacios pierde la forma original de los valores; no se puede deshacer."
  end

  private

  def normalize(value)
    value.to_s.strip.downcase
  end

  def ensure_no_collisions!(column)
    rows = MigrationUser.where.not(column => [ nil, "" ]).pluck(:id, column)
    conflicts = rows.group_by { |_id, value| normalize(value) }.select { |_value, group| group.size > 1 }
    return if conflicts.empty?

    detail = conflicts.map do |normalized, group|
      "  \"#{normalized}\": " + group.map { |id, value| "id #{id} (\"#{value}\")" }.join(", ")
    end
    raise "No se puede normalizar users.#{column}: hay valores que quedarían repetidos. " \
          "Resolvelos a mano y volvé a correr la migración.\n#{detail.join("\n")}"
  end
end
