require "net/http"
require "uri"
require "json"
require "open3"

module SDLS
  class Client
    def initialize(host:, username:, password:, op_item_name: nil)
      @host = host
      @username = username
      @password = password
      @op_item_name = op_item_name
    end

    def authenticate(otp: nil)
      uri = build_uri("/webapi/auth.cgi", auth_params(otp))
      response_body = make_request(uri)

      handle_auth_response(response_body, otp)
    rescue => e
      warn "Authentication error: #{e.message}"
      nil
    end

    def create_download(magnet:, destination:)
      sid = authenticate
      return false unless sid

      uri = build_uri("/webapi/DownloadStation/task.cgi")
      data = download_params(magnet, destination, sid)

      response = Net::HTTP.post_form(uri, data)
      body = JSON.parse(response.body)

      if response.is_a?(Net::HTTPSuccess) && body["success"]
        puts "Download created successfully in #{destination}"
        true
      else
        warn "Download creation failed: #{body.inspect}"
        false
      end
    end

    private

    def build_uri(endpoint, params = nil)
      uri = URI.parse("#{@host}#{endpoint}")
      uri.query = URI.encode_www_form(params) if params
      uri
    end

    def make_request(uri)
      response = Net::HTTP.get_response(uri)
      raise "HTTP error: #{response.code}" unless response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    end

    def auth_params(otp)
      params = {
        api: "SYNO.API.Auth",
        version: 6,
        method: "login",
        account: @username,
        passwd: @password,
        session: "FileStation",
        format: "cookie"
      }
      params[:otp_code] = otp if otp
      params
    end

    def download_params(magnet, destination, sid)
      {
        api: "SYNO.DownloadStation.Task",
        version: "1",
        method: "create",
        session: "DownloadStation",
        _sid: sid,
        uri: magnet,
        destination: destination
      }
    end

    def handle_auth_response(body, otp)
      return body["data"]["sid"] if body["success"]

      if otp_required?(body, otp)
        retry_with_otp
      else
        raise "Authentication failed: #{body.inspect}"
      end
    end

    def otp_required?(body, current_otp)
      current_otp.nil? && body.dig("error", "errors", "types")&.any? { |e| e["type"] == "otp" }
    end

    def retry_with_otp
      puts "OTP required for authentication. Fetching from 1Password..."
      fetched_otp = fetch_otp_from_1password
      return authenticate(otp: fetched_otp) if fetched_otp
      raise "Could not retrieve OTP from 1Password"
    end

    def fetch_otp_from_1password
      return nil unless @op_item_name

      stdout, stderr, status = Open3.capture3("op item get \"#{@op_item_name}\" --otp")
      if status.success?
        stdout.strip
      else
        warn "Failed to retrieve OTP from 1Password: #{stderr.strip}"
        nil
      end
    end
  end
end
