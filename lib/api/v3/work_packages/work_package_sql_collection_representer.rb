module API
  module V3
    module WorkPackages
      class WorkPackageSqlCollectionRepresenter
        class_attribute :embed_map

        self.embed_map = {
          elements: WorkPackageSqlRepresenter
        }.with_indifferent_access

        class << self
          def select_sql(replace_map, _select)
            sql = <<~SELECT
              json_build_object(
                '_embedded', json_build_object(
                  'elements', json_agg(
                    %<elements>s
                  )
                )  
              )
            SELECT

            sql % replace_map.symbolize_keys
          end
        end
      end
    end
  end
end