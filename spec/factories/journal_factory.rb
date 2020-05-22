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

FactoryBot.define do
  factory :journal do
    user factory: :user
    created_at { Time.now }
    sequence(:version) { |n| n + 1 }

    callback(:after_create) do |journal, evaluator|
      data = evaluator.data
      data.journal = journal
      data.save
    end

    factory :work_package_journal, class: Journal do
      journable_type { 'WorkPackage' }
      activity_type { 'work_packages' }
      transient do
        data { FactoryBot.build(:journal_work_package_journal) }
      end

      callback(:after_stub) do |journal, options|
        journal.journable ||= options.journable || FactoryBot.build_stubbed(:work_package)
      end
    end

    factory :wiki_content_journal, class: Journal do
      journable_type { 'WikiContent' }
      activity_type { 'wiki_edits' }

      transient do
        data { FactoryBot.build(:journal_wiki_content_journal) }
      end
    end

    factory :message_journal, class: Journal do
      journable_type { 'Message' }
      activity_type { 'messages' }

      transient do
        data { FactoryBot.build(:journal_message_journal) }
      end
    end
  end
end
