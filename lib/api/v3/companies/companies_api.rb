module API
  module V3
    module Companies
      class CompaniesAPI < ::API::OpenProjectAPI
        helpers ::API::Utilities::PageSizeHelper

        resources :companies do
          get do
            query = ParamsToQueryService
                    .new(::Company, current_user)
                    .call(params)

            if query.valid?
              CompanyCollectionRepresenter.new(query.results,
                                               self_link: api_v3_paths.companies,
                                               page: to_i_or_nil(params[:offset]),
                                               per_page: resolve_page_size(params[:pageSize]),
                                               current_user: current_user)
            else
              raise ::API::Errors::InvalidQuery.new(query.errors.full_messages)
            end
          end

          route_param :id, type: Integer, desc: 'Company ID' do
            after_validation do
              @company = ::Company.find(params[:id])
            end

            get do
              CompanyRepresenter.create(@company,
                                        current_user: current_user,
                                        embed_links: true)
            end
          end
        end
      end
    end
  end
end
