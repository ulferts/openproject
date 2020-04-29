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
require 'spec_helper'

describe Journal,
         type: :model do
  describe '#create' do
    it 'updates updated_on of the journable record (touch)' do
      user = FactoryBot.create(:user)
      timestamp = 5.minutes.ago
      journaled = FactoryBot.create(:work_package)
      journaled.update_columns(created_at: timestamp, updated_at: timestamp)

      Journal.create user: user, notes: 'A note', journable: journaled, data: Journal::WorkPackageJournal.new

      expect(journaled.updated_at)
        .not_to eql timestamp
    end
  end

  describe '#journable' do
    it 'raises no error on a new journal without a journable' do
      expect(Journal.new.journable)
        .to be_nil
    end
  end
end
