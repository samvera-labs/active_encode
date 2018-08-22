class CreateActiveEncodeEncodeRecords < ActiveRecord::Migration[5.2]
  def change
    create_table :active_encode_encode_records do |t|
      t.string :global_id
      t.string :state
      t.string :adapter
      t.string :title
      t.text :raw_object

      t.timestamps
    end
  end
end
