require "net/http"
require "uri"
require "json"
require "open3"

module SDL
  class Client
    def initialize(host:, username:, password:, op_item_name: nil)
      @host = host
      @username = username
      @password = password
      @op_item_name = op_item_name
    end

    def authenticate(otp: nil)
      uri = URI.parse("#{@host}/webapi/auth.cgi")
      query = {
        api: "SYNO.API.Auth",
        version: 6,
        method: "login",
        account: @username,
        passwd: @password,
        session: "FileStation",
        format: "cookie"
      }
      query[:otp_code] = otp if otp
      uri.query = URI.encode_www_form(query)

      response = Net::HTTP.get_response(uri)
      raise "HTTP error: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      body = JSON.parse(response.body)

      unless body["success"]
        if otp.nil? && body.dig("error", "errors", "types")&.any? { |e| e["type"] == "otp" }
          puts "OTP required for authentication. Fetching from 1Password..."
          fetched_otp = fetch_otp_from_1password
          return authenticate(otp: fetched_otp) if fetched_otp
        end
        raise "Authentication failed: #{body.inspect}"
      end

      body["data"]["sid"]
    rescue => e
      warn "Authentication error: #{e.message}"
      nil
    end

    private

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
