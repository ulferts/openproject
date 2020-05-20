# TODO: remove journal version table
# TODO: Document sql
module Journals
  class CreateService
    attr_accessor :journable, :user

    def initialize(journable, user)
      self.user = user
      self.journable = journable
    end

    def call(notes: '')
      journal = create_journal(notes)

      return ServiceResult.new success: true unless journal

      reload_journals
      touch_journable(journal)

      ServiceResult.new success: true, result: journal
    end

    private

    def create_journal(notes)
      Rails.logger.debug "Inserting new journal for #{journable_type} ##{journable.id}"

      create_sql = create_journal_sql(notes)

      # We need to ensure that the result is genuine. Otherwise,
      # calling the service repeatedly for the same journable
      # could e.g. return a (query cached) journal creation
      # that then e.g. leads to the later code thinking that a journal was
      # created.
      result = Journal.connection.uncached do
        ::Journal
          .connection
          .select_one(create_sql)
      end

      Journal.instantiate(result) if result
    end

    def create_journal_sql(notes)
      <<~SQL
        WITH max_journals AS (
          #{select_max_journal_sql}
        ), changes AS (
          #{select_changed_sql}
        ), inserted_journal AS (
          #{insert_journal_sql(notes)}
        ), insert_data AS (
          #{insert_data_sql}
        ), insert_attachable AS (
          #{insert_attachable_sql}
        ), insert_customizable AS (
          #{insert_customizable_sql}
        )

        SELECT * from inserted_journal
      SQL
    end

    def insert_journal_sql(notes)
      condition = if notes.blank?
                    "WHERE EXISTS (SELECT * FROM changes)"
                  else
                    ""
                  end

      timestamp = if notes.blank? && journable_timestamp
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
                                              journable_type: journable_type,
                                              user_id: user.id,
                                              created_at: journable_timestamp)
    end

    def insert_data_sql
      data_sql = <<~SQL
        INSERT INTO
          #{data_table_name} (
            journal_id,
            #{data_sink_columns}
          )
        SELECT
          #{id_from_inserted_journal_sql},
          #{data_source_columns}
        FROM #{journable_table_name}
        #{journable_data_sql_addition}
        WHERE
          #{only_if_created_sql}
          AND #{journable_table_name}.id = :journable_id
      SQL

      ::OpenProject::SqlSanitization.sanitize(data_sql,
                                              journable_id: journable.id)
    end

    def insert_attachable_sql
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

    def insert_customizable_sql
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
          #{normalize_newlines_sql('custom_values.value')}
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

    def select_max_journal_sql
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
                                              journable_type: journable_type)
    end

    def select_changed_sql
      <<~SQL
        SELECT
           *
        FROM
          (#{data_changes_sql}) data_changes
        FULL JOIN
          (#{customizable_changes_sql}) customizable_changes
        ON
          customizable_changes.journable_id = data_changes.journable_id
        FULL JOIN
          (#{attachable_changes_sql}) attachable_changes
        ON
          attachable_changes.journable_id = data_changes.journable_id
      SQL
    end

    def attachable_changes_sql
      attachable_changes_sql = <<~SQL
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
           WHERE attachments.container_id = :journable_id AND attachments.container_type = :container_type) attachments
        ON
          attachments.id = attachable_journals.attachment_id
        WHERE
          (attachments.id IS NULL AND attachable_journals.attachment_id IS NOT NULL)
          OR (attachable_journals.attachment_id IS NULL AND attachments.id IS NOT NULL)
      SQL

      ::OpenProject::SqlSanitization.sanitize(attachable_changes_sql,
                                              journable_id: journable.id,
                                              container_type: journable.class.name)
    end

    def customizable_changes_sql
      customizable_changes_sql = <<~SQL
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
           WHERE custom_values.customized_id = :journable_id AND custom_values.customized_type = :customized_type) custom_values
        ON
          custom_values.custom_field_id = customizable_journals.custom_field_id
        WHERE
          (custom_values.value IS NULL AND customizable_journals.value IS NOT NULL)
          OR (customizable_journals.value IS NULL AND custom_values.value IS NOT NULL AND custom_values.value != '')
          OR (#{normalize_newlines_sql('customizable_journals.value')} !=
              #{normalize_newlines_sql('custom_values.value')})
      SQL

      ::OpenProject::SqlSanitization.sanitize(customizable_changes_sql,
                                              customized_type: journable.class.name,
                                              journable_id: journable.id)
    end

    def data_changes_sql
      data_changes_sql = <<~SQL
        SELECT
          #{journable_table_name}.id journable_id
        FROM
          (SELECT * FROM #{journable_table_name} #{journable_data_sql_addition}) #{journable_table_name}
        LEFT JOIN
          (SELECT * FROM max_journals
           JOIN
             #{data_table_name}
           ON
             #{data_table_name}.journal_id = max_journals.id) #{data_table_name}
        ON
          #{journable_table_name}.id = #{data_table_name}.journable_id
        WHERE
          #{journable_table_name}.id = :journable_id AND (#{data_changes_condition_sql})
      SQL

      ::OpenProject::SqlSanitization.sanitize(data_changes_sql,
                                              journable_id: journable.id)
    end

    def only_if_created_sql
      "EXISTS (SELECT * from inserted_journal)"
    end

    def id_from_inserted_journal_sql
      "(SELECT id FROM inserted_journal)"
    end

    def data_changes_condition_sql
      data_table = data_table_name
      journable_table = journable_table_name

      data_changes = (journable.journaled_columns_names - text_column_names).map do |column_name|
        <<~SQL
          (#{journable_table}.#{column_name} != #{data_table}.#{column_name})
          OR (#{journable_table}.#{column_name} IS NULL AND #{data_table}.#{column_name} IS NOT NULL)
          OR (#{journable_table}.#{column_name} IS NOT NULL AND #{data_table}.#{column_name} IS NULL)
        SQL
      end

      data_changes += text_column_names.map do |column_name|
        <<~SQL
          #{normalize_newlines_sql("#{journable_table}.#{column_name}")} !=
           #{normalize_newlines_sql("#{data_table}.#{column_name}")}
        SQL
      end

      data_changes.join(' OR ')
    end

    def data_sink_columns
      text_columns = text_column_names
      (journable.journaled_columns_names - text_columns + text_columns).join(', ')
    end

    def data_source_columns
      text_columns = text_column_names
      normalized_text_columns = text_columns.map { |column| normalize_newlines_sql(column) }
      (journable.journaled_columns_names - text_columns + normalized_text_columns).join(', ')
    end

    def journable_data_sql_addition
      journable.class.vestal_journals_options[:data_sql]&.call(journable) || ''
    end

    def text_column_names
      journable.class.columns_hash.select { |_, v| v.type == :text }.keys.map(&:to_sym) & journable.journaled_columns_names
    end

    def journable_timestamp
      journable.respond_to?(:updated_at) && journable.updated_at || journable.respond_to?(:updated_on) && journable.updated_on
    end

    def journable_type
      journable.class.base_class.name
    end

    def journable_table_name
      journable.class.table_name
    end

    def data_table_name
      journable.class.journal_class.table_name
    end

    def normalize_newlines_sql(column)
      "REGEXP_REPLACE(COALESCE(#{column},''), '\\r\\n', '\n', 'g')"
    end

    # Because we added the journal via bare metal sql, rails does not yet
    # know of the journal. If the journable has the journals loaded already,
    # the caller might expect the journals to also be updated so we do it for him.
    def reload_journals
      journable.journals.reload if journable.journals.loaded?
    end

    def touch_journable(journal)
      return unless journal.notes.present?

      # Not using touch here on purpose,
      # as to avoid changing lock versions on the journables for this change
      attributes = journable.send(:timestamp_attributes_for_update_in_model)

      timestamps = attributes.index_with { journal.created_at }
      journable.update_columns(timestamps) if timestamps.any?
    end
  end
end
