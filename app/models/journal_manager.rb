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

    def changed?(journable)
      # TODO: this should return true if no journal exists
      sql = <<~SQL
        WITH max_journals AS (
           SELECT
             *
           FROM
             journals
           WHERE
             journals.journable_id = #{journable.id}
             AND journals.journable_type = '#{base_class_name(journable.class)}'
             AND journals.version IN (SELECT MAX(version) FROM journals WHERE journable_id = #{journable.id} AND journable_type = '#{base_class_name(journable.class)}')
        )

        SELECT
          COUNT(*)
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

      ActiveRecord::Base.uncached do
        ActiveRecord::Base.connection.select_one(sql)['count'].positive?
      end
    end

    def add_journal!(journable, user = User.current, notes = '')
      return unless journalized?(journable)

      journal = create_journal(journable, user, notes)

      if journal
        # ensure the text_columns of the sink are sorted the same as the one of the source
        text_columns = text_column_names(journable)
        sink_selects = journable.journaled_columns_names - text_columns + text_columns
        source_selects = journable.journaled_columns_names - text_columns + text_columns.map { |column| "REGEXP_REPLACE(#{column}, '\\r\\n', '\n', 'g')" }

        additional_source_sql = journable.class.vestal_journals_options[:data_sql]&.call(journable) || ''

        data_sql = <<~SQL
          INSERT INTO
            #{journal_class(journable.class).table_name} (
              journal_id,
              #{sink_selects.join(', ')}
            )
          SELECT
            #{journal.id},
            #{source_selects.join(', ')}
          FROM #{journable.class.table_name}
          #{additional_source_sql}
          WHERE #{journable.class.table_name}.id = #{journable.id}
        SQL

        journal_class(journable.class)
          .connection
          .execute(data_sql)

        attachment_sql = <<~SQL
          INSERT INTO
            attachable_journals (
              journal_id,
              attachment_id,
              filename
            )
          SELECT
            #{journal.id},
            id,
            file
          FROM attachments
          WHERE
            attachments.container_id = #{journable.id}
            AND attachments.container_type = '#{journable.class.name}'
        SQL

        Journal::AttachableJournal
          .connection
          .execute(attachment_sql)

        # TODO: write migration to split up the existing migrations for multi select lists
        custom_value_sql = <<~SQL
          INSERT INTO
            customizable_journals (
              journal_id,
              custom_field_id,
              value
            )
          SELECT
            #{journal.id},
            custom_field_id,
            value
          FROM custom_values
          WHERE
            custom_values.customized_id = #{journable.id}
            AND custom_values.customized_type = '#{journable.class.name}'
            AND custom_values.value IS NOT NULL
            AND custom_values.value != ''
        SQL

        Journal::CustomizableJournal
          .connection
          .execute(custom_value_sql)
      end

      journable.journals.reload if journable.journals.loaded?
      # TODO: find new solution for touching the journable
      journal.send(:touch_journable)
      journal
    end

    def update_user_references(current_user_id, substitute_id)
      foreign_keys = %w[author_id user_id assigned_to_id responsible_id]

      Journal::BaseJournal.subclasses.each do |klass|
        foreign_keys.each do |foreign_key|
          if klass.column_names.include? foreign_key
            klass.where(foreign_key => current_user_id).update_all(foreign_key => substitute_id)
          end
        end
      end
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

      result = ::Journal
                 .connection
                 .select_one(create_sql)

      Journal.instantiate(result)
    end

    def create_journal_sql(journable, user, notes)
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
          COALESCE(MAX(version), 0) + 1,
          :activity_type,
          :user_id,
          :notes,
          now()
        FROM journals
        WHERE journable_id = :journable_id AND journable_type = :journable_type
        RETURNING *
      SQL

      ::OpenProject::SqlSanitization.sanitize(journal_sql,
                                              notes: notes,
                                              journable_id: journable.id,
                                              activity_type: journable.activity_type,
                                              journable_type: base_class_name(journable.class),
                                              user_id: user.id)
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

      additional_source_sql = journable.class.vestal_journals_options[:data_sql]&.call(journable) || ''

      <<~SQL
        SELECT
          max_journals.journable_id
        FROM
          max_journals
        JOIN
          #{data_table_name}
        ON
          #{data_table_name}.journal_id = max_journals.id
        RIGHT JOIN
          (SELECT * FROM #{journable_table_name} #{additional_source_sql}) #{journable_table_name}
        ON
          #{journable_table_name}.id = max_journals.journable_id
        WHERE
          #{journable_table_name}.id = #{journable.id} AND (#{data_columns.join(' OR ')})
      SQL
    end

    def text_column_names(journable)
      journable.class.columns_hash.select { |_, v| v.type == :text }.keys.map(&:to_sym) & journable.journaled_columns_names
    end
  end
end
