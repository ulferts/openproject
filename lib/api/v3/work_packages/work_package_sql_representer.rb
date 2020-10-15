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

        class_attribute :properties

        class << self
          # Properties
          # TODO: extract into class
          def properties_sql(select)
            # TODO: throw error on non supported select
            cleaned_selects = select
                              .symbolize_keys
                              .select { |_,v| v.empty? }
                              .slice(*supported_selects)
                              .keys

            properties
              .slice(*cleaned_selects)
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

          def select_sql(_replace_map, select)

            <<~SELECT
              json_build_object(
                #{properties_sql(select)}
              )
            SELECT
          end

          private

          def supported_selects
            %i(id subject createdAt updatedAt)
          end
        end

        property :id

        property :subject

        property :createdAt,
                 column: :created_at

        property :updatedAt,
                 column: :updated_at
      end
    end
  end
end
