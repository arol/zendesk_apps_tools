require 'sinatra/base'
require 'sinatra/cross_origin'
require 'zendesk_apps_support/package'

module ZendeskAppsTools
  class Server < Sinatra::Base
    set :protection, except: :frame_options
    ZENDESK_DOMAINS_REGEX = %r{^http(?:s)?://[a-z0-9-]+\.(?:zendesk|zopim|zd-(?:dev|master|staging))\.com$}

    get '/app.js' do
      access_control_allow_origin
      content_type 'text/javascript'

      new_settings = settings.settings_helper.refresh!
      settings.parameters = new_settings if new_settings

      package = ZendeskAppsSupport::Package.new(settings.root, false)
      app_name = package.manifest.name || 'Local App'
      installation = ZendeskAppsSupport::Installation.new(
        id: settings.install_id,
        app_id: settings.app_id,
        app_name: app_name,
        enabled: true,
        requirements: package.requirements_json,
        settings: settings.parameters.merge(title: app_name),
        updated_at: Time.now.iso8601,
        created_at: Time.now.iso8601
      )

      app_js = package.compile(
        app_id: settings.app_id,
        app_name: app_name,
        assets_dir: "http://localhost:#{settings.port}/",
        locale: params['locale']
      )

      ZendeskAppsSupport::Installed.new([app_js], [installation]).compile
    end

    enable :cross_origin

    def send_file(*args)
      access_control_allow_origin
      super(*args)
    end

    def request_from_zendesk?
      request.env['HTTP_ORIGIN'] =~ ZENDESK_DOMAINS_REGEX
    end

    # This is for any preflight request
    # It reads 'Access-Control-Request-Headers' to set 'Access-Control-Allow-Headers'
    # And also sets 'Access-Control-Allow-Origin' header
    options '*' do
      access_control_allow_origin
      if request_from_zendesk?
        headers 'Access-Control-Allow-Headers' => request.env['HTTP_ACCESS_CONTROL_REQUEST_HEADERS']
      end
    end

    # This sets the 'Access-Control-Allow-Origin' header for requests coming from zendesk
    def access_control_allow_origin
      headers 'Access-Control-Allow-Origin' => request.env['HTTP_ORIGIN'] if request_from_zendesk?
    end
  end
end
