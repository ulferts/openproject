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

# Handles the following no longer supported options and deprecations
# * Ruby 2.7: Using the last argument as keyword parameters is deprecated; maybe ** should be added to the call
# * Rails 6.1 polymorphic option for belongs_to

if Gem.loaded_specs["awesome_nested_set"].version > Gem::Version.new('3.2.1')
  raise "Check if these patches of awesome_nested_set still required."
end

module OpenProject::NestedSet::AwesomeNestedSetPatch
  extend ActiveSupport::Concern

  class_methods do
    # ruby 2.7 hash call fixed
    def acts_as_nested_set_relate_children!
      has_many_children_options = {
        :class_name => self.base_class.to_s,
        :foreign_key => parent_column_name,
        :primary_key => primary_column_name,
        :inverse_of => (:parent unless acts_as_nested_set_options[:polymorphic]),
      }

      # Add callbacks, if they were supplied.. otherwise, we don't want them.
      [:before_add, :after_add, :before_remove, :after_remove].each do |ar_callback|
        has_many_children_options.update(
          ar_callback => acts_as_nested_set_options[ar_callback]
        ) if acts_as_nested_set_options[ar_callback]
      end

      has_many :children, -> { order(order_column_name => :asc) },
               **has_many_children_options
    end

    # Polymorphic option removed.
    # ruby 2.7 hash call fixed
    def acts_as_nested_set_relate_parent!
      options = {
        :class_name => self.base_class.to_s,
        :foreign_key => parent_column_name,
        :primary_key => primary_column_name,
        :counter_cache => acts_as_nested_set_options[:counter_cache],
        :inverse_of => (:children unless acts_as_nested_set_options[:polymorphic]),
        :touch => acts_as_nested_set_options[:touch]
      }
      options[:optional] = true if ActiveRecord::VERSION::MAJOR >= 5
      belongs_to :parent, **options
    end
  end
end
