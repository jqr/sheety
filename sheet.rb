# frozen_string_literal: true

require "google/apis/sheets_v4"

module Sheety
  class Sheet
    attr_reader :client, :id

    delegate :service, to: :client

    def initialize(client, id, options = {})
      @client = client
      @id = id
      @column_types = options.fetch(:column_types).transform_keys do |k|
        clean_header(k)
      end.transform_values do |v|
        v.to_sym
      end
    end

    # Resets locally cached data.
    def reset!
      @table = nil
    end

    # Returns an Array of Arrays representing each individual cell.
    def table
      @table ||= begin
        response = service.get_spreadsheet_values(@id, "A:ZZZ")
        response.values
      end
    end

    # Returns a normalized list of headers.
    def headers
      header_row = table.first
      raise "Missing header row" unless header_row.present?

      header_row.map { |h| clean_header(h) }.tap do |clean_headers|
        # TODO: VALIDATE duplicate headers are array type

        unexpected_headers = clean_headers - @column_types.keys
        raise "Unexpected header: #{unexpected_headers}" if unexpected_headers.present?
      end
    end

    # Returns every non-header row in hash form, with headers as the keys.
    def hash_rows
      data_rows.map.map do |row_array|
        convert_row_array(row_array)
      end
    end

    # Updates a single cell at address to value. The address argument should
    # be in spreadhseet form, like B5.
    def update_cell(address, value)
      reset!
      value_range = Google::Apis::SheetsV4::ValueRange.new
      value_range.update!(range: address, values: [[value]])
      service.update_spreadsheet_value(@id, address, value_range, value_input_option: "RAW")
    end

    # Updates a single cell at row, in header's column to value.
    def update_row_value(row, header, value)
      update_cell("#{header_to_column(header)}#{row}", value)
    end

    # Modifies cells in the spreadsheet to the returned hash.
    def transform!
      hash_rows.each.with_index do |row, row_index|
        new_row = row.deep_dup # duplicate so block can modify in place

        yield new_row

        if new_row != row
          raise "Only handles identical keys" unless new_row.keys == row.keys

          new_row.each do |k, v|
            if row[k] != v
              type = column_type(k)
              raise "Can only update :string types, not #{type.inspect}" unless type == :string

              update_row_value(row_index + 2, k, v)
            end
          end
        end
      end
    end

    private

    def header_to_column(header)
      header = clean_header(header)
      index = headers.index(header)
      raise "Unknown header: #{header.inspect}" unless index
      raise 'Referenced header column is too large(#{index}) to use simple hack' if index > 26
      ("A".ord + index).chr
    end

    def clean_header(header)
      header.to_s.strip.downcase.gsub(/\s+/, "_")
    end

    def data_rows
      table[1..-1]
    end

    def column_type(column)
      @column_types[column] || raise("Unknown column #{column.inspect}")
    end

    def coercive_assign(row, key, value)
      value = value.to_s.strip
      case type = column_type(key)
      when :array
        row[key] ||= []
        row[key] << value if value.present?
      when :boolean
        row[key] = value.casecmp("TRUE").zero?
      when :string
        row[key] = value.present? ? value : nil
      else
        raise "Unknown column type: #{type.inspect}"
      end
    end

    def convert_row_array(row_array)
      headers.each_with_object({}).with_index do |(k, row_hash), i|
        coercive_assign(row_hash, k, row_array[i])
      end
    end
  end
end
