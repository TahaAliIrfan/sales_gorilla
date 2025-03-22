class AddClosingDateToDeals < ActiveRecord::Migration[7.1]
  def change
    add_column :deals, :closing_date, :date
  end
end
