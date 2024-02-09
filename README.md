# Sheety

```ruby

client_id = "some-oauth-client-id"
token = nil

# Set up the API and save a token if we didn't have one before.
sheety = Sheety::Client.new(client_id: client_id, token: token) do |token, previous_token|
  if !previous_token
    $stdout.with_sync do
      $stdout.puts "Save this token\n\n"
      $stdout.puts token
      $stdout.print "\n[Enter] "
      $stdin.gets
    end
  end
end

# Basic reading
COLUMN_TYPES = {
  id:     :string,
  email:  :string,
  active: :boolean,
  queues: :array,
}
REQUIRED_COLUMNS = %w(id email active).freeze

sheet = context.sheety_client.get_spreadsheet("spreadsheet-id", column_types: COLUMN_TYPES)

# Validate columns
missing_columns = REQUIRED_COLUMNS - sheet.headers
if missing_columns.present?
  abort "Missing required columns: #{missing_columns}.join(", ")"
end

# Modify every row
sheet.transform! do |row|
  # Add an id to anything lacking it
  row["id"] = SecureRandom.hex(16) if row["id"].blank?

  # Normalize email
  row["email"] = row["email"].downcase if row["email"].present?
end

sheet.hash_rows.each do |row|
  abort "Still missing ID on #{row.inspect}" if row["id"].blank?
end

```
