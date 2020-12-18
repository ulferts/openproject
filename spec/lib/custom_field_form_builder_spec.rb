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
require 'ostruct'

describe CustomFieldFormBuilder do
  include Capybara::RSpecMatchers

  let(:helper) { ActionView::Base.new(ActionView::LookupContext.new(''), {}, @controller) }
  let(:builder) { described_class.new(:user, resource, helper, {}) }

  describe '#custom_field' do
    let(:options) { {class: 'custom-class'} }

    let(:custom_field) do
      FactoryBot.build_stubbed(:custom_field)
    end
    let(:resource) do
      FactoryBot.build_stubbed(:custom_value, custom_field: custom_field)
    end

    subject(:output) do
      builder.custom_field options
    end

    it_behaves_like 'labelled by default'
    it_behaves_like 'wrapped in field-container by default' do
      let(:container_count) { 2 }
    end

    context 'for a bool custom field' do
      it_behaves_like 'wrapped in container', 'check-box-container' do
        let(:container_count) { 2 }
      end

      it 'should output element' do
        expect(output).to be_html_eql(%{
          <input class="custom-class form--check-box"
                 id="user#{resource.custom_field_id}"
                 name="user[#{resource.custom_field_id}]"
                 type="checkbox"
                 value="1" />
        }).at_path('input:nth-of-type(2)')
      end
    end

    context 'for a date custom field' do
      before do
        resource.custom_field.field_format = 'date'
      end

      it_behaves_like 'wrapped in container', 'text-field-container' do
        let(:container_count) { 2 }
      end

      it 'should output element' do
        expect(output).to be_html_eql(%{
          <input class="custom-class -augmented-datepicker form--text-field"
                 id="user#{resource.custom_field_id}"
                 name="user[#{resource.custom_field_id}]"
                 type="text" />
        }).at_path('input')
      end
    end

    context 'for a text custom field' do
      before do
        resource.custom_field.field_format = 'text'
      end

      it_behaves_like 'wrapped in container', 'text-area-container' do
        let(:container_count) { 2 }
      end

      it 'should output element' do
        expect(output).to be_html_eql(%{
          <textarea class="custom-class form--text-area"
                    id="user#{resource.custom_field_id}"
                    name="user[#{resource.custom_field_id}]"
                    with_text_formatting="true"
                    editor_type="constrained"
                    macros="false">
          </textarea>
        }).at_path('textarea')
      end
    end

    context 'for a string custom field' do
      before do
        resource.custom_field.field_format = 'string'
      end

      it_behaves_like 'wrapped in container', 'text-field-container' do
        let(:container_count) { 2 }
      end

      it 'should output element' do
        expect(output).to be_html_eql(%{
          <input class="custom-class form--text-field"
                 id="user#{resource.custom_field_id}"
                 name="user[#{resource.custom_field_id}]"
                 type="text" />
        }).at_path('input')
      end
    end

    context 'for an int custom field' do
      before do
        resource.custom_field.field_format = 'int'
      end

      it_behaves_like 'wrapped in container', 'text-field-container' do
        let(:container_count) { 2 }
      end

      it 'should output element' do
        expect(output).to be_html_eql(%{
          <input class="custom-class form--text-field"
                 id="user#{resource.custom_field_id}"
                 name="user[#{resource.custom_field_id}]"
                 type="text" />
        }).at_path('input')
      end
    end

    context 'for a float custom field' do
      before do
        resource.custom_field.field_format = 'float'
      end

      it_behaves_like 'wrapped in container', 'text-field-container' do
        let(:container_count) { 2 }
      end

      it 'should output element' do
        expect(output).to be_html_eql(%{
          <input class="custom-class form--text-field"
                 id="user#{resource.custom_field_id}"
                 name="user[#{resource.custom_field_id}]"
                 type="text" />
        }).at_path('input')
      end
    end

    context 'for a list custom field' do
      let(:custom_field) do
        FactoryBot.build_stubbed(:list_wp_custom_field,
                                 custom_options: [custom_option])
      end
      let(:custom_option) do
        FactoryBot.build_stubbed(:custom_option, value: 'my_option')
      end

      it_behaves_like 'wrapped in container', 'select-container' do
        let(:container_count) { 2 }
      end

      it 'should output element' do
        expect(output).to be_html_eql(%{
          <select class="custom-class form--select"
                  id="user#{custom_field.id}"
                  name="user[#{custom_field.id}]"
                  no_label="true"><option
                  value=\"\" label=\" \"></option>
                  <option value=\"#{custom_option.id}\">my_option</option></select>
        }).at_path('select')
      end

      context 'which is required and has no default value' do
        before do
          custom_field.is_required = true
        end

        it 'should output element' do
          expect(output).to be_html_eql(%{
            <select class="custom-class form--select"
                    id="user#{custom_field.id}"
                    name="user[#{custom_field.id}]"
                    no_label="true"><option value=\"\">---
                    Please select ---</option>
                    <option value=\"#{custom_option.id}\">my_option</option></select>
          }).at_path('select')
        end
      end

      context 'which is required and a default value' do
        before do
          custom_field.is_required = true
          custom_option.default_value = true
        end

        it 'should output element' do
          expect(output).to be_html_eql(%{
            <select class="custom-class form--select"
                    id="user#{custom_field.id}"
                    name="user[#{custom_field.id}]"
                    no_label="true"><option
                    value=\"#{custom_option.id}\">my_option</option></select>
          }).at_path('select')
        end
      end
    end

    context 'for a user custom field' do
      let(:project) { FactoryBot.build_stubbed(:project) }
      let(:user1) { FactoryBot.build_stubbed(:user) }
      let(:user2) { FactoryBot.build_stubbed(:user) }

      before do
        resource.custom_field.field_format = 'user'
        resource.customized = project
        allow(project)
          .to receive(:users)
                .and_return([user1, user2])
      end

      it_behaves_like 'wrapped in container', 'select-container' do
        let(:container_count) { 2 }
      end

      it 'should output element' do
        expect(output).to be_html_eql(%{
          <select class="custom-class form--select"
                  id="user#{resource.custom_field_id}"
                  name="user[#{resource.custom_field_id}]"
                  no_label="true">
            <option value=\"\" label=\" \"></option>
            <option value="#{user1.id}">#{user1.name}</option>
            <option value="#{user2.id}">#{user2.name}</option>
          </select>
        }).at_path('select')
      end

      context 'which is required and has no default value' do
        before do
          resource.custom_field.is_required = true
        end

        it 'should output element' do
          expect(output).to be_html_eql(%{
            <select class="custom-class form--select"
                    id="user#{resource.custom_field_id}"
                    name="user[#{resource.custom_field_id}]"
                    no_label="true">
              <option value=\"\">--- Please select ---</option>
              <option value="#{user1.id}">#{user1.name}</option>
              <option value="#{user2.id}">#{user2.name}</option>
            </select>
          }).at_path('select')
        end
      end
    end

    context 'for a version custom field' do
      let(:project) { FactoryBot.build_stubbed(:project) }
      let(:version1) { FactoryBot.build_stubbed(:version) }
      let(:version2) { FactoryBot.build_stubbed(:version) }

      before do
        resource.custom_field.field_format = 'version'
        resource.customized = project
        allow(project)
          .to receive(:shared_versions)
                .and_return([version1, version2])
      end

      it_behaves_like 'wrapped in container', 'select-container' do
        let(:container_count) { 2 }
      end

      it 'should output element' do
        expect(output).to be_html_eql(%{
          <select class="custom-class form--select"
                  id="user#{resource.custom_field_id}"
                  name="user[#{resource.custom_field_id}]"
                  no_label="true">
            <option value=\"\" label=\" \"></option>
            <option value="#{version1.id}">#{version1.name}</option>
            <option value="#{version2.id}">#{version2.name}</option>
          </select>
        }).at_path('select')
      end

      context 'which is required and has no default value' do
        before do
          resource.custom_field.is_required = true
        end

        it 'should output element' do
          expect(output).to be_html_eql(%{
            <select class="custom-class form--select"
                    id="user#{resource.custom_field_id}"
                    name="user[#{resource.custom_field_id}]"
                    no_label="true">
              <option value=\"\">--- Please select ---</option>
              <option value="#{version1.id}">#{version1.name}</option>
              <option value="#{version2.id}">#{version2.name}</option>
            </select>
          }).at_path('select')
        end
      end
    end
  end
end
