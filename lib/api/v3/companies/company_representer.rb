module API
  module V3
    module Companies
      class CompanyRepresenter < ::API::Decorators::Single
        include API::Decorators::LinkedResource
        include API::Decorators::DateProperty

        self_link title_getter: ->(*) { represented.name }

        property :id

        property :name

        date_time_property :created_at
        date_time_property :updated_at

        associated_resources :parents_users,
                             as: :owning_users,
                             v3_path: :user,
                             representer: ::API::V3::Users::UserRepresenter

        def _type
          'Company'
        end
      end
    end
  end
end
