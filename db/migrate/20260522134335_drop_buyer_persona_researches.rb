class DropBuyerPersonaResearches < ActiveRecord::Migration[7.1]
  def change
    drop_table :buyer_persona_researches
  end
end
