module API
  module V3
    module WorkPackages
      class WorkPackageSqlCollectionRepresenter
        def initialize(scope,
                       self_link,
                       query: {},
                       project: nil,
                       groups:,
                       total_sums:,
                       page: nil,
                       per_page: nil,
                       embed_schemas: false,
                       current_user:)
          @project = project
          @groups = groups
          @total_sums = total_sums
          @embed_schemas = embed_schemas
          @scope = scope
        end

        def to_json
          result = ActiveRecord::Base.connection.select_one <<~SQL
            SELECT 
              json_build_object(
                '_embedded', json_build_object(
                  'elements', json_agg(
                    json_build_object(
                      'id', work_packages.id
                    )
                  )
                )  
              ) AS result
            FROM 
              (#{@scope.select('work_packages.*').to_sql}) work_packages
          SQL

          result['result']
        end
      end
    end
  end
end