require "net/http"
require "uri"
require "json"
require "open3"
require "tty-prompt"

module SDLS
  class Client
    def initialize(host:, username:, password:, op_item_name: nil, op_account: nil)
      @host = host
      @username = username
      @password = password
      @op_item_name = op_item_name
      @op_account = op_account
    end

    def authenticate(otp: nil)
      uri = URI.join(@host, "/webapi/auth.cgi")
      response_body = make_post_request(uri, auth_params(otp))

      handle_auth_response(response_body, otp)
    rescue => e
      warn "Authentication error: #{e.message}"
      nil
    end

    def create_download(magnet:, destination:)
      sid = authenticate
      return false unless sid

      uri = URI.join(@host, "/webapi/DownloadStation/task.cgi")
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

    def make_post_request(uri, params)
      response = Net::HTTP.post_form(uri, params)
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
      puts "OTP required for authentication."

      # Try 1Password first if configured and available
      if @op_item_name && onepassword_cli_available?
        puts "Fetching OTP from 1Password..."
        fetched_otp = fetch_otp_from_1password
        return authenticate(otp: fetched_otp) if fetched_otp
        puts "Failed to retrieve OTP from 1Password, falling back to manual entry."
      end

      # Fallback to manual OTP entry
      fetched_manual_otp = prompt_for_manual_otp
      return authenticate(otp: fetched_manual_otp) if fetched_manual_otp

      raise "Could not retrieve OTP"
    end

    def onepassword_cli_available?
      return @op_cli_available unless @op_cli_available.nil?

      @op_cli_available = if ENV.key?("SDLS_FORCE_OP_CLI")
        ENV["SDLS_FORCE_OP_CLI"] == "true"
      else
        system("which op > /dev/null 2>&1")
      end
    end

    def fetch_otp_from_1password
      return nil unless @op_item_name

      cmd = ["op", "item", "get", @op_item_name, "--otp"]
      cmd += ["--account", @op_account] if @op_account && !@op_account.to_s.strip.empty?

      stdout, stderr, status = Open3.capture3(*cmd)
      if status.success?
        stdout.strip
      else
        warn "Failed to retrieve OTP from 1Password: #{stderr.strip}"
        nil
      end
    end

    def prompt_for_manual_otp
      prompt = TTY::Prompt.new
      prompt.mask("Please enter your OTP code:")
    end
  end
end
