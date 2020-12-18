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

describe Queries::Projects::Filters::CustomFieldFilter, type: :model do
  let(:query) { Queries::Projects::ProjectQuery.new }
  let(:cf_accessor) { "cf_#{custom_field.id}" }
  let(:instance) do
    described_class.create!(name: cf_accessor, operator: '=', context: query)
  end
  let(:instance_key) { nil }

  shared_let(:list_project_custom_field) { FactoryBot.create(:list_project_custom_field) }
  let(:bool_project_custom_field) { FactoryBot.build_stubbed(:bool_project_custom_field) }
  let(:int_project_custom_field) { FactoryBot.build_stubbed(:int_project_custom_field) }
  let(:float_project_custom_field) { FactoryBot.build_stubbed(:float_project_custom_field) }
  let(:text_project_custom_field) { FactoryBot.build_stubbed(:text_project_custom_field) }
  let(:user_project_custom_field) { FactoryBot.build_stubbed(:user_project_custom_field) }
  let(:version_project_custom_field) { FactoryBot.build_stubbed(:version_project_custom_field) }
  let(:date_project_custom_field) { FactoryBot.build_stubbed(:date_project_custom_field) }
  let(:string_project_custom_field) { FactoryBot.build_stubbed(:string_project_custom_field) }
  let(:custom_field) { list_project_custom_field }

  let(:all_custom_fields) do
    [list_project_custom_field,
     bool_project_custom_field,
     int_project_custom_field,
     float_project_custom_field,
     text_project_custom_field,
     user_project_custom_field,
     version_project_custom_field,
     date_project_custom_field,
     string_project_custom_field]
  end

  before do
    allow(ProjectCustomField)
      .to receive(:all)
      .and_return(all_custom_fields)
  end

  describe 'invalid custom field' do
    let(:cf_accessor) { 'cf_100' }
    let(:all_custom_fields) { [] }

    it 'raises exception' do
      expect { instance }.to raise_error(::Queries::Filters::InvalidError)
    end
  end

  describe '.valid?' do
    let(:custom_field) { string_project_custom_field }
    before do
      instance.values = ['bogus']
    end

    before do
      allow(ProjectCustomField)
        .to receive_message_chain(:visible, :exists?)
        .and_return(true)
    end

    shared_examples_for 'custom field type dependent validity' do
      context 'with a string custom field' do
        it 'is valid' do
          expect(instance).to be_valid
        end
      end

      context 'with a list custom field' do
        let(:custom_field) { list_project_custom_field }

        before do
          instance.values = [list_project_custom_field.possible_values.first.id]
        end

        it 'is valid' do
          expect(instance).to be_valid
        end

        it "is invalid if the value is not one of the custom field's possible values" do
          instance.values = ['bogus']

          expect(instance).to_not be_valid
        end
      end
    end

    context 'without a project' do
      it_behaves_like 'custom field type dependent validity'
    end
  end

  describe '.key' do
    it 'is a regular expression' do
      expect(described_class.key).to eql(/cf_(\d+)/)
    end
  end

  describe 'instance attributes' do
    it 'are valid' do
      all_custom_fields.each do |cf|
        name = "cf_#{cf.id}"
        filter = described_class.create!(name: name)
        expect(filter.name).to eql(:"cf_#{cf.id}")
        expect(filter.order).to eql(20)
      end
    end
  end

  describe '#type' do
    context 'integer' do
      let(:cf_accessor) { "cf_#{int_project_custom_field.id}" }

      it 'is integer for an integer' do
        expect(instance.type)
          .to eql(:integer)
      end
    end

    context 'float' do
      let(:cf_accessor) { "cf_#{float_project_custom_field.id}" }

      it 'is integer for a float' do
        expect(instance.type)
          .to eql(:float)
      end
    end

    context 'text' do
      let(:cf_accessor) { "cf_#{text_project_custom_field.id}" }
      it 'is text for a text' do
        expect(instance.type)
          .to eql(:text)
      end
    end

    context 'list optional' do
      let(:cf_accessor) { "cf_#{list_project_custom_field.id}" }

      it 'is list_optional for a list' do
        expect(instance.type)
          .to eql(:list_optional)
      end
    end

    context 'user' do
      let(:cf_accessor) { "cf_#{user_project_custom_field.id}" }
      it 'is list_optional for a user' do
        expect(instance.type)
          .to eql(:list_optional)
      end
    end

    context 'version' do
      let(:cf_accessor) { "cf_#{version_project_custom_field.id}" }

      it 'is list_optional for a version' do
        expect(instance.type)
          .to eql(:list_optional)
      end
    end

    context 'version' do
      let(:cf_accessor) { "cf_#{date_project_custom_field.id}" }

      it 'is date for a date' do
        expect(instance.type)
          .to eql(:date)
      end
    end

    context 'bool' do
      let(:cf_accessor) { "cf_#{bool_project_custom_field.id}" }

      it 'is list for a bool' do
        expect(instance.type)
          .to eql(:list)
      end
    end

    context 'string' do
      let(:cf_accessor) { "cf_#{string_project_custom_field.id}" }

      it 'is string for a string' do
        expect(instance.type)
          .to eql(:string)
      end
    end
  end

  describe '#human_name' do
    it 'is the field name' do
      expect(instance.human_name)
        .to eql(list_project_custom_field.name)
    end
  end

  describe '#allowed_values' do
    context 'integer' do
      let(:cf_accessor) { "cf_#{int_project_custom_field.id}" }

      it 'is nil for an integer' do
        expect(instance.allowed_values)
          .to be_nil
      end
    end

    context 'float' do
      let(:cf_accessor) { "cf_#{float_project_custom_field.id}" }

      it 'is integer for a float' do
        expect(instance.allowed_values)
          .to be_nil
      end
    end

    context 'text' do
      let(:cf_accessor) { "cf_#{text_project_custom_field.id}" }

      it 'is text for a text' do
        expect(instance.allowed_values)
          .to be_nil
      end
    end

    context 'list' do
      let(:cf_accessor) { "cf_#{list_project_custom_field.id}" }

      it 'is list_optional for a list' do
        expect(instance.allowed_values)
          .to match_array(list_project_custom_field.custom_options.map { |co| [co.value, co.id.to_s] })
      end
    end

    context 'user' do
      let(:cf_accessor) { "cf_#{user_project_custom_field.id}" }

      it 'is list_optional for a user' do
        bogus_return_value = ['user1', 'user2']
        allow(user_project_custom_field)
          .to receive(:possible_values_options)
          .and_return(bogus_return_value)

        expect(instance.allowed_values)
          .to match_array bogus_return_value
      end
    end

    context 'version' do
      let(:cf_accessor) { "cf_#{version_project_custom_field.id}" }

      it 'is list_optional for a version' do
        bogus_return_value = ['version1', 'version2']
        allow(version_project_custom_field)
          .to receive(:possible_values_options)
          .and_return(bogus_return_value)

        expect(instance.allowed_values)
          .to match_array bogus_return_value
      end
    end

    context 'date' do
      let(:cf_accessor) { "cf_#{date_project_custom_field.id}" }

      it 'is nil for a date' do
        expect(instance.allowed_values)
          .to be_nil
      end
    end

    context 'bool' do
      let(:cf_accessor) { "cf_#{bool_project_custom_field.id}" }

      it 'is list for a bool' do
        expect(instance.allowed_values)
          .to match_array [[I18n.t(:general_text_yes), OpenProject::Database::DB_VALUE_TRUE],
                           [I18n.t(:general_text_no), OpenProject::Database::DB_VALUE_FALSE]]
      end
    end

    context 'string' do
      let(:cf_accessor) { "cf_#{string_project_custom_field.id}" }

      it 'is nil for a string' do
        expect(instance.allowed_values)
          .to be_nil
      end
    end
  end

  describe '.all_for' do
    before do
      allow(ProjectCustomField)
        .to receive(:visible)
        .and_return([list_project_custom_field,
                     bool_project_custom_field,
                     int_project_custom_field,
                     float_project_custom_field,
                     text_project_custom_field,
                     date_project_custom_field,
                     string_project_custom_field])
    end

    it 'returns a list with a filter for every custom field' do
      filters = described_class.all_for

      [list_project_custom_field,
       bool_project_custom_field,
       int_project_custom_field,
       float_project_custom_field,
       text_project_custom_field,
       date_project_custom_field,
       string_project_custom_field].each do |cf|
        expect(filters.detect { |filter| filter.name == :"cf_#{cf.id}" }).to_not be_nil
      end

      expect(filters.detect { |filter| filter.name == :"cf_#{version_project_custom_field.id}" })
        .to be_nil
      expect(filters.detect { |filter| filter.name == :"cf_#{user_project_custom_field.id}" })
        .to be_nil
    end
  end

  context 'list cf' do
    describe '#ar_object_filter? / #value_objects' do
      let(:custom_field) { list_project_custom_field }

      describe '#ar_object_filter?' do
        it 'is true' do
          expect(instance)
            .to be_ar_object_filter
        end
      end

      describe '#value_objects' do
        before do
          instance.values = [custom_field.custom_options.last.id,
                             custom_field.custom_options.first.id]
        end

        it 'returns an array with custom classes' do
          expect(instance.value_objects)
            .to match_array([custom_field.custom_options.last,
                             custom_field.custom_options.first])
        end

        it 'ignores invalid values' do
          instance.values = ['invalid',
                             custom_field.custom_options.last.id]

          expect(instance.value_objects)
            .to match_array([custom_field.custom_options.last])
        end
      end
    end

    context 'bool cf' do
      let(:custom_field) { bool_project_custom_field }

      it_behaves_like 'non ar filter'
    end

    context 'int cf' do
      let(:custom_field) { int_project_custom_field }

      it_behaves_like 'non ar filter'
    end

    context 'float cf' do
      let(:custom_field) { float_project_custom_field }

      it_behaves_like 'non ar filter'
    end

    context 'text cf' do
      let(:custom_field) { text_project_custom_field }

      it_behaves_like 'non ar filter'
    end

    context 'user cf' do
      let(:custom_field) { user_project_custom_field }

      describe '#ar_object_filter?' do
        it 'is true' do
          expect(instance)
            .to be_ar_object_filter
        end
      end

      describe '#value_objects' do
        let(:user1) { FactoryBot.build_stubbed(:user) }
        let(:user2) { FactoryBot.build_stubbed(:user) }

        before do
          allow(Principal)
            .to receive(:where)
            .and_return([user1, user2])

          instance.values = [user1.id.to_s, user2.id.to_s]
        end

        it 'returns an array with users' do
          expect(instance.value_objects)
            .to match_array([user1, user2])
        end
      end
    end

    context 'version cf' do
      let(:custom_field) { version_project_custom_field }

      describe '#ar_object_filter?' do
        it 'is true' do
          expect(instance)
            .to be_ar_object_filter
        end
      end

      describe '#value_objects' do
        let(:version1) { FactoryBot.build_stubbed(:version) }
        let(:version2) { FactoryBot.build_stubbed(:version) }

        before do
          allow(Version)
            .to receive(:where)
            .with(id: [version1.id.to_s, version2.id.to_s])
            .and_return([version1, version2])

          instance.values = [version1.id.to_s, version2.id.to_s]
        end

        it 'returns an array with users' do
          expect(instance.value_objects)
            .to match_array([version1, version2])
        end
      end
    end

    context 'date cf' do
      let(:custom_field) { date_project_custom_field }

      it_behaves_like 'non ar filter'
    end

    context 'string cf' do
      let(:custom_field) { string_project_custom_field }

      it_behaves_like 'non ar filter'
    end
  end
end
