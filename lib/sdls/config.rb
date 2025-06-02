# frozen_string_literal: true

require "yaml"

module SDLS
  REQUIRED_KEYS = %i[host username password]
  Config = Data.define(:host, :username, :password, :op_item_name, :directories) do
    def self.load(path)
      raise "Configuration file not found: #{path}" unless File.exist?(path)

      data = YAML.load_file(path)
      data = {} unless data.is_a?(Hash)
      data = symbolize_keys(data)

      missing_keys = REQUIRED_KEYS - data.keys
      nil_keys = REQUIRED_KEYS.select { |k| data[k].nil? }

      if missing_keys.any? || nil_keys.any?
        raise "Configuration file (#{path}) is missing required keys or values: #{(missing_keys + nil_keys).uniq.join(", ")}"
      end

      new(**data)
    rescue Psych::SyntaxError => e
      raise "Error parsing configuration file (#{path}): #{e.message}"
    end

    def self.symbolize_keys(hash)
      hash.to_h { |k, v| [k.to_sym, v] }
    end
  end
end
