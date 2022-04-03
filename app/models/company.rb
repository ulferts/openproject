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
# See COPYRIGHT and LICENSE files for more details.
#++

class Company < ApplicationRecord
  has_many :parent_shares, -> { where(active: true) }, foreign_key: 'child_id', class_name: 'Share'
  has_many :parents, through: :parent_shares

  has_many :children_shares, -> { where(active: true) }, foreign_key: 'parent_id', class_name: 'Share'
  has_many :children, through: :children_shares

  belongs_to :owner, class_name: 'User'

  validates_presence_of :name

  def parents_users
    @parents_users ||= parents.exists? ? users : [owner]
  end

  private

  def users
    parents.map { |parent| parent.parents_users }.flatten
  end
end
