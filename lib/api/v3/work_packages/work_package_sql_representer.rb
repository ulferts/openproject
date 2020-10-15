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

module API
  module V3
    module WorkPackages
      class WorkPackageSqlRepresenter
        extend ::API::V3::Utilities::PathHelper

        class_attribute :properties,
                        :association_links

        class << self
          # Properties
          # TODO: extract into class
          def properties_sql(select)

            properties
              .slice(*cleaned_selects(select))
              .map do |name, options|
              representation = if options[:representation]
                options[:representation].call
              else
                "work_packages.#{options[:column]}"
              end

              "'#{name}', #{representation}"
            end.join(', ')
          end

          def property(name,
                       column: name,
                       representation: nil,
                       render_if: nil)
            self.properties ||= {}

            properties[name] = { column: column, render_if: render_if, representation: representation }
          end

          def properties_conditions
            properties
              .select { |_, options| options[:render_if] }
              .map do |name, options|
                "- CASE WHEN #{options[:render_if].call} THEN '' ELSE '#{name}' END"
              end.join(' ')
          end

          # TODO: turn association_link into separate class so that
          # instances can be generated here
          def association_link(name, column: name, path: nil, join:, title: nil, href: nil)
            self.association_links ||= {}

            association_links[name] = { column: column,
                                        path: path,
                                        join: join,
                                        title: title,
                                        href: href }
          end

          def association_links_joins(select)
            association_links
              .slice(*cleaned_selects(select))
              .map do |name, link|
              if link[:join].is_a?(Symbol)
                "LEFT OUTER JOIN #{link[:join]} #{name} ON #{name}.id = work_packages.#{link[:column]}_id"
              else
                "LEFT OUTER JOIN #{link[:join][:table]} #{name} ON #{link[:join][:condition]} AND #{name}.id = work_packages.#{link[:column]}_id"
              end
            end
              .join(' ')
          end

          def association_links_selects(select)
            association_links
              .slice(*cleaned_selects(select))
              .map do |name, link|
              path_name = link[:path] ? link[:path][:api] : name
              title = link[:title] ? link[:title].call : "#{name}.name"

              href = link[:href] ? link[:href].call : "format('#{api_v3_paths.send(path_name, '%s')}', #{name}.id)"

              <<-SQL
               '#{name}', CASE
                          WHEN #{name}.id IS NOT NULL
                          THEN
                          json_build_object('href', #{href},
                                            'title', #{title})
                          ELSE
                          json_build_object('href', NULL,
                                            'title', NULL)
                          END
              SQL
            end
              .join(', ')
          end

          def select_sql(_replace_map, select)
            <<~SELECT
              json_build_object(
                #{properties_sql(select)},
                '_links', json_strip_nulls(
                  json_build_object(#{association_links_selects(select)})
                )
              )
            SELECT
          end

          private

          def cleaned_selects(select)
            # TODO: throw error on non supported select
            select
              .symbolize_keys
              .select { |_,v| v.empty? }
              .keys
          end
        end

        property :id

        property :subject

        property :createdAt,
                 column: :created_at

        property :updatedAt,
                 column: :updated_at

        association_link :author,
                         path: { api: :user, params: %w(author_id) },
                         join: :users,
                         title: -> {
                           join_string = if Setting.user_format == :lastname_coma_firstname
                                           " || ', ' || "
                                         else
                                           " || ' ' || "
                                         end

                           User::USER_FORMATS_STRUCTURE[Setting.user_format].map { |p| "author.#{p}" }.join(join_string)
                         }


        association_link :assignee,
                         column: :assigned_to,
                         path: { api: :user, params: %w(assigned_to_id) },
                         join: :users,
                         title: -> {
                           join_string = if Setting.user_format == :lastname_coma_firstname
                                           " || ', ' || "

                                         else
                                           " || ' ' || "

                                         end

                           User::USER_FORMATS_STRUCTURE[Setting.user_format].map { |p| "assignee.#{p}" }.join(join_string)
                         },
                         href: -> {
                           <<-SQL
                            CASE
                            WHEN assignee.type = 'User'
                            THEN format('#{api_v3_paths.user('%s')}', assignee.id)
                            ELSE format('#{api_v3_paths.group('%s')}', assignee.id)
                            END
                           SQL
                         }
      end
    end
  end
end
