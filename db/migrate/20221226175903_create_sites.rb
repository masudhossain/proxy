class CreateSites < ActiveRecord::Migration[5.0]
  def change
    create_table :sites do |t|
      t.string :website
      t.string :token

      t.timestamps
    end
  end
end
