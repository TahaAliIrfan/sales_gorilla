class AddRequestPayloadToMetaConversionLogs < ActiveRecord::Migration[7.1]
  def change
    add_column :meta_conversion_logs, :request_payload, :jsonb
  end
end
