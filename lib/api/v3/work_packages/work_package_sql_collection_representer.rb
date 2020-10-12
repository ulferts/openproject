module API
  module V3
    module WorkPackages
      class WorkPackageSqlCollectionRepresenter
        class_attribute :embed_map

        self.embed_map = {
          elements: WorkPackageSqlRepresenter
        }

        attr_accessor :embed,
                      :select,
                      :current_user

        def initialize(scope,
                       self_link,
                       query: {},
                       project: nil,
                       groups:,
                       total_sums:,
                       embed: {},
                       select: {},
                       page: nil,
                       per_page: nil,
                       current_user:)
          @project = project
          @groups = groups
          @total_sums = total_sums
          @scope = scope
          self.embed = embed
          self.select = select
          self.current_user = current_user
        end

        def to_json(*)
          result = ActiveRecord::Base.connection.select_one <<~SQL
            SELECT 
              #{select_sql} AS json 
            FROM 
              (#{@scope.select('work_packages.*').to_sql}) work_packages
          SQL

          result['json']
        end

        def select_sql
          <<~SELECT
            json_build_object(
              '_embedded', json_build_object(
                'elements', json_agg(
                  #{elements_select_sql}
                )
              )  
            )
          SELECT
        end

        def elements_select_sql
          API::V3::WorkPackages::WorkPackageSqlRepresenter
            .new(nil, current_user: current_user, embed: embed['elements'], select: select['elements'])
            .select_sql
        end

        class << self
          def select_sql
            <<~SELECT
              json_build_object(
                '_embedded', json_build_object(
                  'elements', json_agg(
                    %<work_packages_element>s
                  )
                )  
              )
            SELECT
          end

          def select_embed
            [work_packages_element]
          end
        end
      end
    end
  end
end