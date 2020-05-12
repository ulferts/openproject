#-- encoding: UTF-8
#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2012-2020 the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2017 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See docs/COPYRIGHT.rdoc for more details.
#++

class JournalManager
  class << self
    def journalized?(obj)
      obj.present? && obj.respond_to?(:journals)
    end

    def journal_class(type)
      namespace = type.name.deconstantize

      if namespace == 'Journal'
        type
      else
        "Journal::#{journal_class_name(type)}".constantize
      end
    end

    # TODO: turn into service
    def add_journal!(journable, user = User.current, notes = '')
      return unless journalized?(journable)

      journal = create_journal(journable, user, notes)

      return unless journal

      journable.journals.reload if journable.journals.loaded?
      touch_journable(journal, journable)
      journal
    end

    private

    def journal_class_name(type)
      "#{base_class_name(type)}Journal"
    end

    def base_class(type)
      type.base_class
    end

    def base_class_name(type)
      base_class(type).name
    end

    def create_journal(journable, user, notes)
      # TODO: remove journal version table
      Rails.logger.debug "Inserting new journal for #{base_class_name(journable.class)} ##{journable.id}"

      create_sql = create_journal_sql(journable, user, notes)

      result = Journal.connection.uncached do
        ::Journal
           .connection
           .select_one(create_sql)
      end

      Journal.instantiate(result) if result
    end

    def create_journal_sql(journable, user, notes)
      <<~SQL
        WITH max_journals AS (
          #{select_max_journal_sql(journable)}
        ), changes AS (
          #{select_changed_sql(journable)}
        ), inserted_journal AS (
          #{insert_journal_sql(journable, notes, user)}
        ), insert_data AS (
          #{insert_data_sql(journable)}
        ), insert_attachable AS (
          #{insert_attachable_sql(journable)}
        ), insert_customizable AS (
          #{insert_customizable_sql(journable)}
        )

        SELECT * from inserted_journal
      SQL
    end

    def insert_journal_sql(journable, notes, user)
      condition = if notes.blank?
                    "WHERE EXISTS (SELECT * FROM changes)"
                  else
                    ""
                  end

      timestamp = if notes.blank? && journable_timestamp(journable)
                    ':created_at'
                  else
                    'now()'
                  end

      journal_sql = <<~SQL
        INSERT INTO
          journals (
            journable_id,
            journable_type,
            version,
            activity_type,
            user_id,
            notes,
            created_at
          )
        SELECT
          :journable_id,
          :journable_type,
          COALESCE(max_journals.version, 0) + 1,
          :activity_type,
          :user_id,
          :notes,
          #{timestamp}
        FROM max_journals
        #{condition}
        RETURNING *
      SQL

      ::OpenProject::SqlSanitization.sanitize(journal_sql,
                                              notes: notes,
                                              journable_id: journable.id,
                                              activity_type: journable.activity_type,
                                              journable_type: base_class_name(journable.class),
                                              user_id: user.id,
                                              created_at: journable_timestamp(journable))
    end

    def insert_data_sql(journable)
      data_sql = <<~SQL
        INSERT INTO
          #{journal_class(journable.class).table_name} (
            journal_id,
            #{data_sink_columns(journable)}
          )
        SELECT
          #{id_from_inserted_journal_sql},
          #{data_source_columns(journable)}
        FROM #{journable.class.table_name}
        #{journable_data_sql_addition(journable)}
        WHERE
          #{only_if_created_sql}
          AND #{journable.class.table_name}.id = :journable_id
      SQL

      ::OpenProject::SqlSanitization.sanitize(data_sql,
                                              journable_id: journable.id)
    end

    def insert_attachable_sql(journable)
      attachable_sql = <<~SQL
        INSERT INTO
          attachable_journals (
            journal_id,
            attachment_id,
            filename
          )
        SELECT
          #{id_from_inserted_journal_sql},
          attachments.id,
          attachments.file
        FROM attachments
        WHERE
          #{only_if_created_sql}
          AND attachments.container_id = :journable_id
          AND attachments.container_type = :journable_class_name
      SQL

      ::OpenProject::SqlSanitization.sanitize(attachable_sql,
                                              journable_id: journable.id,
                                              journable_class_name: journable.class.name)
    end

    def insert_customizable_sql(journable)
      customizable_sql = <<~SQL
        INSERT INTO
          customizable_journals (
            journal_id,
            custom_field_id,
            value
          )
        SELECT
          #{id_from_inserted_journal_sql},
          custom_values.custom_field_id,
          custom_values.value
        FROM custom_values
        WHERE
          #{only_if_created_sql}
          AND custom_values.customized_id = :journable_id
          AND custom_values.customized_type = :journable_class_name
          AND custom_values.value IS NOT NULL
          AND custom_values.value != ''
      SQL

      ::OpenProject::SqlSanitization.sanitize(customizable_sql,
                                              journable_id: journable.id,
                                              journable_class_name: journable.class.name)
    end

    def select_max_journal_sql(journable)
      max_journal_sql = <<~SQL
        SELECT
          :journable_id journable_id,
          :journable_type journable_type,
          COALESCE(journals.version, fallback.version) AS version,
          COALESCE(journals.id, 0) id
        FROM
          journals
        RIGHT OUTER JOIN
          (SELECT 0 AS version) fallback
        ON
           journals.journable_id = :journable_id
           AND journals.journable_type = :journable_type
           AND journals.version IN (SELECT MAX(version) FROM journals WHERE journable_id = :journable_id AND journable_type = :journable_type)
      SQL

      ::OpenProject::SqlSanitization.sanitize(max_journal_sql,
                                              journable_id: journable.id,
                                              journable_type: base_class_name(journable.class))
    end

    def select_changed_sql(journable)
      <<~SQL
        SELECT
           *
        FROM
          (#{data_changes_sql(journable)}) data_changes
        FULL JOIN
          (#{customizable_changes_sql(journable)}) customizable_changes
        ON
          customizable_changes.journable_id = data_changes.journable_id
        FULL JOIN
          (#{attachable_changes_sql(journable)}) attachable_changes
        ON
          attachable_changes.journable_id = data_changes.journable_id
      SQL
    end

    def attachable_changes_sql(journable)
      <<~SQL
        SELECT
          max_journals.journable_id
        FROM
          max_journals
        LEFT OUTER JOIN
          attachable_journals
        ON
          attachable_journals.journal_id = max_journals.id
        FULL JOIN
          (SELECT *
           FROM attachments
           WHERE attachments.container_id = #{journable.id} AND attachments.container_type = '#{journable.class.name}') attachments
        ON
          attachments.id = attachable_journals.attachment_id
        WHERE
          (attachments.id IS NULL AND attachable_journals.attachment_id IS NOT NULL)
          OR (attachable_journals.attachment_id IS NULL AND attachments.id IS NOT NULL)
      SQL
    end

    # TODO:
    #  * normalize strings
    def customizable_changes_sql(journable)
      <<~SQL
        SELECT
          max_journals.journable_id
        FROM
          max_journals
        LEFT OUTER JOIN
          customizable_journals
        ON
          customizable_journals.journal_id = max_journals.id
        FULL JOIN
          (SELECT *
           FROM custom_values
           WHERE custom_values.customized_id = #{journable.id} AND custom_values.customized_type = '#{journable.class.name}') custom_values
        ON
          custom_values.custom_field_id = customizable_journals.custom_field_id
        WHERE
          (custom_values.value IS NULL AND customizable_journals.value IS NOT NULL)
          OR (customizable_journals.value IS NULL AND custom_values.value IS NOT NULL AND custom_values.value != '')
          OR (customizable_journals.value != custom_values.value)
      SQL
    end

    def data_changes_sql(journable)
      journable_table_name = journable.class.table_name
      data_table_name = journal_class(journable.class).table_name

      text_columns = text_column_names(journable)

      data_columns = (journable.journaled_columns_names - text_columns).map do |column_name|
        <<~SQL
          (#{journable_table_name}.#{column_name} != #{data_table_name}.#{column_name})
          OR (#{journable_table_name}.#{column_name} IS NULL AND #{data_table_name}.#{column_name} IS NOT NULL)
          OR (#{journable_table_name}.#{column_name} IS NOT NULL AND #{data_table_name}.#{column_name} IS NULL)
        SQL
      end

      data_columns += text_columns.map do |column_name|
        <<~SQL
          (REGEXP_REPLACE(COALESCE(#{journable_table_name}.#{column_name}, ''), '\\r\\n', '\n', 'g') !=
           REGEXP_REPLACE(COALESCE(#{data_table_name}.#{column_name}, ''), '\\r\\n', '\n', 'g'))
        SQL
      end

      # TODO: consider switching subqueries to avoid RIGHT JOIN in favor of LEFT JOIN
      <<~SQL
        SELECT
          #{journable_table_name}.id journable_id
        FROM
          (SELECT * FROM max_journals
           JOIN
             #{data_table_name}
           ON
             #{data_table_name}.journal_id = max_journals.id) #{data_table_name}
        RIGHT JOIN
          (SELECT * FROM #{journable_table_name} #{journable_data_sql_addition(journable)}) #{journable_table_name}
        ON
          #{journable_table_name}.id = #{data_table_name}.journable_id
        WHERE
          #{journable_table_name}.id = #{journable.id} AND (#{data_columns.join(' OR ')})
      SQL
    end

    def only_if_created_sql
      "EXISTS (SELECT * from inserted_journal)"
    end

    def id_from_inserted_journal_sql
      "(SELECT id FROM inserted_journal)"
    end

    def data_sink_columns(journable)
      text_columns = text_column_names(journable)
      (journable.journaled_columns_names - text_columns + text_columns).join(', ')
    end

    def data_source_columns(journable)
      text_columns = text_column_names(journable)
      normalized_text_columns = text_columns.map { |column| "REGEXP_REPLACE(#{column}, '\\r\\n', '\n', 'g')" }
      (journable.journaled_columns_names - text_columns + normalized_text_columns).join(', ')
    end

    def journable_data_sql_addition(journable)
      journable.class.vestal_journals_options[:data_sql]&.call(journable) || ''
    end

    def text_column_names(journable)
      journable.class.columns_hash.select { |_, v| v.type == :text }.keys.map(&:to_sym) & journable.journaled_columns_names
    end

    def touch_journable(journal, journable)
      return unless journal.notes.present?

      # Not using touch here on purpose,
      # as to avoid changing lock versions on the journables for this change
      attributes = journable.send(:timestamp_attributes_for_update_in_model)

      timestamps = attributes.index_with { journal.created_at }
      journable.update_columns(timestamps) if timestamps.any?
    end

    def journable_timestamp(journable)
      journable.respond_to?(:updated_at) && journable.updated_at || journable.respond_to?(:updated_on) && journable.updated_on
    end
  end
end
