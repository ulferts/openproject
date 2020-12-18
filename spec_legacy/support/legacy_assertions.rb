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
module LegacyAssertionsAndHelpers
  extend ActiveSupport::Concern

  ##
  # Resets any global state that may have been changed through tests and the change of which
  # should not affect other tests.
  def reset_global_state!
    User.current = User.anonymous # reset current user in case it was changed in a test
    ActionMailer::Base.deliveries.clear
    RequestStore.clear!
  end

  ##
  # Attachments generated through fixtures do not files associated with them even
  # when one provides them within the fixture yml. Dunno why.
  #
  # This method fixes that. Tries to lookup existing files. Generates temporary files
  # where none exist.
  def initialize_attachments
    Attachment.all.each do |a|
      if a.file.filename.nil?
        begin # existing file under `spec/fixtures/files`
          a.file = uploaded_test_file a.disk_filename, a.attributes['content_type'],
                                      original_filename: a.attributes['filename']
        rescue # imaginary file: create it on-the-fly
          a.file = LegacyFileHelpers.mock_uploaded_file name: a.attributes['filename'],
                                                  content_type: a.attributes['content_type']
        end

        a.save!
      end
    end
  end

  def log_user(login, password)
    User.anonymous
    get '/login'
    assert_equal nil, session[:user_id]
    assert_response :success
    assert_template 'account/login'
    post '/login', username: login, password: password
    assert_equal login, User.find(session[:user_id]).login
  end

  ##
  # Creates a UploadedFile for a file in the fixtures under `spec/fixtures/files`.
  # Optionally allows to override the original filename.
  #
  # Shortcut for Rack::Test::UploadedFile.new(
  #   ActionController::TestCase.fixture_path + path, mime)
  def uploaded_test_file(name, mime, original_filename: nil)
    file = fixture_file_upload("/files/#{name}", mime, true)
    file.define_singleton_method(:original_filename) { original_filename } if original_filename
    file
  end

  def with_settings(options, &_block)
    saved_settings = options.keys.inject({}) { |h, k| h[k] = Setting[k].dup; h }
    options.each do |k, v| Setting[k] = v end
    yield
  ensure
    saved_settings.each { |k, v| Setting[k] = v }
  end

  # Shoulda macros
  def should_assign_to(variable, &block)
    # it "assign the instance variable '#{variable}'" do
    assert @controller.instance_variables.map(&:to_s).include?("@#{variable}")
    if block
      expected_result = instance_eval(&block)
      assert_equal @controller.instance_variable_get('@' + variable.to_s), expected_result
    end
    # end
  end

  def should_render_404
    should respond_with :not_found
    should render_template 'common/error'
  end

  def should_respond_with_content_type(content_type)
    # it "respond with content type '#{content_type}'" do
    assert_equal response.content_type, content_type
    # end
  end

  def assert_error_tag(options = {})
    assert_select('body', { attributes: { id: 'errorExplanation' } }.merge(options))
  end

  def credentials(login, password = nil)
    if password.nil?
      password = (login == 'admin' ? 'adminADMIN!' : login)
    end
    { 'HTTP_AUTHORIZATION' => ActionController::HttpAuthentication::Basic.encode_credentials(login, password) }
  end

  def repository_configured?(vendor)
    self.class.repository_configured?(vendor)
  end

  module ClassMethods
    def ldap_configured?
      return false if !!ENV['CI']

      @test_ldap = Net::LDAP.new(host: '127.0.0.1', port: 389)
      return @test_ldap.bind
    rescue Exception => e
      # LDAP is not listening
      return nil
    end

    # Returns the path to the test +vendor+ repository
    def repository_path(vendor)
      File.join(Rails.root.to_s.gsub(%r{config\/\.\.}, ''), "/tmp/test/#{vendor.downcase}_repository")
    end

    # Returns the url of the subversion test repository
    def subversion_repository_url
      path = repository_path('subversion')
      path = '/' + path unless path.starts_with?('/')
      "file://#{path}"
    end

    # Returns true if the +vendor+ test repository is configured
    def repository_configured?(vendor)
      File.directory?(repository_path(vendor))
    end

    # Test that a request allows the three types of API authentication
    #
    # * HTTP Basic with username and password
    # * HTTP Basic with an api key for the username
    # * Key based with the key=X parameter
    #
    # @param [Symbol] http_method the HTTP method for request (:get, :post, :put, :delete)
    # @param [String] url the request url
    # @param [optional, Hash] parameters additional request parameters
    # @param [optional, Hash] options additional options
    # @option options [Symbol] :success_code Successful response code (:success)
    # @option options [Symbol] :failure_code Failure response code (:unauthorized)
    def should_allow_api_authentication(http_method, url, parameters = {}, options = {})
      should_allow_http_basic_auth_with_username_and_password(http_method, url, parameters, options)
      should_allow_http_basic_auth_with_key(http_method, url, parameters, options)
      should_allow_key_based_auth(http_method, url, parameters, options)
    end

    # Test that a request allows the username and password for HTTP BASIC
    #
    # @param [Symbol] http_method the HTTP method for request (:get, :post, :put, :delete)
    # @param [String] url the request url
    # @param [optional, Hash] options additional options
    # @option options [Symbol] :success_code Successful response code (:success)
    # @option options [Symbol] :failure_code Failure response code (:unauthorized)
    def should_send_correct_authentication_scheme_when_header_authentication_scheme_is_session(http_method, url, options = {}, parameters = {})
      success_code = options[:success_code] || :success
      failure_code = options[:failure_code] || :unauthorized

      context "should not send www authenticate when header accept auth is session #{http_method} #{url}" do
        context 'without credentials' do
          before do
            send(http_method, url, params: parameters, headers: { 'HTTP_X_AUTHENTICATION_SCHEME' => 'Session' })
          end
          it { should respond_with failure_code }
          it { should_respond_with_content_type_based_on_url(url) }
          it 'include correct www_authenticate_header' do
            assert response.headers.has_key?('WWW-Authenticate')
            assert_equal 'Session realm="OpenProject API"', response.headers['WWW-Authenticate']
          end
        end
      end
    end

    # Test that a request allows the username and password for HTTP BASIC
    #
    # @param [Symbol] http_method the HTTP method for request (:get, :post, :put, :delete)
    # @param [String] url the request url
    # @param [optional, Hash] parameters additional request parameters
    # @param [optional, Hash] options additional options
    # @option options [Symbol] :success_code Successful response code (:success)
    # @option options [Symbol] :failure_code Failure response code (:unauthorized)
    def should_allow_http_basic_auth_with_username_and_password(http_method, url, parameters = {}, options = {})
      success_code = options[:success_code] || :success
      failure_code = options[:failure_code] || :unauthorized

      context "should allow http basic auth using a username and password for #{http_method} #{url}" do
        context 'with a valid HTTP authentication' do
          before do
            @user = FactoryBot.create(:user, password: 'adminADMIN!', password_confirmation: 'adminADMIN!', admin: true) # Admin so they can access the project

            send(http_method, url, params: parameters, headers: credentials(@user.login, 'adminADMIN!'))
          end
          it { should respond_with success_code }
          it { should_respond_with_content_type_based_on_url(url) }
          it 'login as the user' do
            assert_equal @user, User.current
          end
        end

        context 'with an invalid HTTP authentication' do
          before do
            @user = FactoryBot.create(:user)

            send(http_method, url, params: parameters, headers: credentials(@user.login, 'wrong_password'))
          end
          it { should respond_with failure_code }
          it { should_respond_with_content_type_based_on_url(url) }
          it 'not login as the user' do
            assert_equal User.anonymous, User.current
          end
        end

        context 'without credentials' do
          before do
            send(http_method, url, params: parameters)
          end
          it { should respond_with failure_code }
          it { should_respond_with_content_type_based_on_url(url) }
          it 'include_www_authenticate_header' do
            assert response.headers.has_key?('WWW-Authenticate')
          end
        end
      end
    end

    # Test that a request allows the API key with HTTP BASIC
    #
    # @param [Symbol] http_method the HTTP method for request (:get, :post, :put, :delete)
    # @param [String] url the request url
    # @param [optional, Hash] parameters additional request parameters
    # @param [optional, Hash] options additional options
    # @option options [Symbol] :success_code Successful response code (:success)
    # @option options [Symbol] :failure_code Failure response code (:unauthorized)
    def should_allow_http_basic_auth_with_key(http_method, url, parameters = {}, options = {})
      success_code = options[:success_code] || :success
      failure_code = options[:failure_code] || :unauthorized

      context "should allow http basic auth with a key for #{http_method} #{url}" do
        context 'with a valid HTTP authentication using the API token' do
          before do
            @user = FactoryBot.create(:user, admin: true)
            @token = FactoryBot.create(:api_token, user: @user)

            send(http_method, url, params: parameters, headers: credentials(@token.plain_value, 'X'))
          end
          it { should respond_with success_code }
          it { should_respond_with_content_type_based_on_url(url) }
          it { should_be_a_valid_response_string_based_on_url(url) }
          it 'login as the user' do
            assert_equal @user, User.current
          end
        end

        context 'with an invalid HTTP authentication' do
          before do
            @user = FactoryBot.create(:user)
            @token = FactoryBot.create(:rss_token, user: @user)

            send(http_method, url, params: parameters, headers: credentials(@token.value, 'X'))
          end
          it { should respond_with failure_code }
          it { should_respond_with_content_type_based_on_url(url) }
          it 'not login as the user' do
            assert_equal User.anonymous, User.current
          end
        end
      end
    end

    # Test that a request allows full key authentication
    #
    # @param [Symbol] http_method the HTTP method for request (:get, :post, :put, :delete)
    # @param [String] url the request url, without the key=ZXY parameter
    # @param [optional, Hash] parameters additional request parameters
    # @param [optional, Hash] options additional options
    # @option options [Symbol] :success_code Successful response code (:success)
    # @option options [Symbol] :failure_code Failure response code (:unauthorized)
    def should_allow_key_based_auth(http_method, url, parameters = {}, options = {})
      success_code = options[:success_code] || :success
      failure_code = options[:failure_code] || :unauthorized

      context "should allow key based auth using key=X for #{http_method} #{url}" do
        context 'with a valid api token' do
          before do
            @user = FactoryBot.create(:user, admin: true)
            @token = FactoryBot.create(:api_token, user: @user)
            # Simple url parse to add on ?key= or &key=
            request_url = if url.match(/\?/)
                            url + "&key=#{@token.plain_value}"
                          else
                            url + "?key=#{@token.plain_value}"
                          end
            send(http_method, request_url, params: parameters)
          end
          it { should respond_with success_code }
          it { should_respond_with_content_type_based_on_url(url) }
          it { should_be_a_valid_response_string_based_on_url(url) }
          it 'login as the user' do
            assert_equal @user, User.current
          end
        end

        context 'with an invalid api token' do
          before do
            @user = FactoryBot.create(:user)
            @token = FactoryBot.create(:rss_token, user: @user)
            # Simple url parse to add on ?key= or &key=
            request_url = if url.match(/\?/)
                            url + "&key=#{@token.value}"
                          else
                            url + "?key=#{@token.value}"
                          end
            send(http_method, request_url, params: parameters)
          end
          it { should respond_with failure_code }
          it { should_respond_with_content_type_based_on_url(url) }
          it 'not login as the user' do
            assert_equal User.anonymous, User.current
          end
        end
      end

      context "should allow key based auth using X-OpenProject-API-Key header for #{http_method} #{url}" do
        before do
          @user = FactoryBot.create(:user, admin: true)
          @token = FactoryBot.create(:api_token, user: @user)
          send(http_method, url, params: {}, headers: { 'X-OpenProject-API-Key' => @token.plain_value.to_s })
        end
        it { should respond_with success_code }
        it { should_respond_with_content_type_based_on_url(url) }
        it { should_be_a_valid_response_string_based_on_url(url) }
        it 'login as the user' do
          assert_equal @user, User.current
        end
      end
    end
  end

  # Uses should_respond_with_content_type based on what's in the url:
  #
  # '/project/issues.xml' => should_respond_with_content_type :xml
  # '/project/issues.json' => should_respond_with_content_type :json
  #
  # @param [String] url Request
  def should_respond_with_content_type_based_on_url(url)
    case
    when url.match(/xml/i)
      should_respond_with_content_type 'application/xml'
    when url.match(/json/i)
      should_respond_with_content_type 'application/json'
    else
      raise "Unknown content type for should_respond_with_content_type_based_on_url: #{url}"
    end
  end

  # Uses the url to assert which format the response should be in
  #
  # '/project/issues.xml' => should_be_a_valid_xml_string
  # '/project/issues.json' => should_be_a_valid_json_string
  #
  # @param [String] url Request
  def should_be_a_valid_response_string_based_on_url(url)
    case
    when url.match(/xml/i)
      should_be_a_valid_xml_string
    when url.match(/json/i)
      should_be_a_valid_json_string
    else
      raise "Unknown content type for should_be_a_valid_response_based_on_url: #{url}"
    end
  end

  # Checks that the response is a valid JSON string
  def should_be_a_valid_json_string
    # it "be a valid JSON string (or empty)" do
    assert(response.body.blank? || ActiveSupport::JSON.decode(response.body))
    # end
  end

  # Checks that the response is a valid XML string
  def should_be_a_valid_xml_string
    # it "be a valid XML string" do
    assert REXML::Document.new(response.body)
    # end
  end
end
