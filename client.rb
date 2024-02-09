# frozen_string_literal: true

require "google/apis/sheets_v4"
require "googleauth"
require "googleauth/token_store"

module Sheety
  class Client
    APPLICATION_NAME = "My Application"
    SCOPE = Google::Apis::SheetsV4::AUTH_SPREADSHEETS
    USER_ID = "default"
    OOB_URI = "urn:ietf:wg:oauth:2.0:oob"

    attr_reader :client_id

    def initialize(options = {}, &on_store)
      @token = options.fetch(:token, nil)
      if options[:client_id].is_a?(String)
        @client_id = Google::Auth::ClientId.from_hash(JSON.parse(options.fetch(:client_id)))
      else
        @client_id = options.fetch(:client_id)
      end
      @service = options.fetch(:service, nil)
      @on_store = on_store
    end

    def token_store
      @token_store ||= SimpleTokenStore.new(@token, &@on_store)
    end

    def user_authorizer
      @authorizer ||= Google::Auth::UserAuthorizer.new(client_id, SCOPE, token_store)
    end

    def get_existing_credentials
      user_authorizer.get_credentials(USER_ID)
    end

    def get_and_store_credentials
      raise "Can't authorize, not connected to TTY." unless $stdout.tty?
      $stdout.with_sync do
        url = user_authorizer.get_authorization_url(base_url: OOB_URI)

        $stdout.puts "Open the following URL in the browser and enter the resulting code after authorization: \n\n"
        $stdout.puts url
        system("open", url)

        $stdout.print "\nCode: "
        code = gets
      end

      user_authorizer.get_and_store_credentials_from_code(user_id: USER_ID, code: code, base_url: OOB_URI)
    end

    def authorization
      get_existing_credentials || get_and_store_credentials
    end

    def service
      @service ||= Google::Apis::SheetsV4::SheetsService.new.tap do |s|
        s.client_options.application_name = APPLICATION_NAME
        s.authorization = authorization
      end
    end

    def get_spreadsheet(id, options = {})
      Sheet.new(self, id, options)
    end
  end
end
