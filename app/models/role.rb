class Role < ApplicationRecord
  has_many :role_assignments, dependent: :destroy
  has_many :users, through: :role_assignments
  
  validates :name, presence: true
  validates :key, presence: true, uniqueness: true
  validates :hierarchy_level, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  
  # Predefined roles
  ADMIN = 'admin'
  MANAGER = 'manager'
  ASSOCIATE = 'associate'
  
  # Class methods to retrieve roles
  class << self
    def admin
      find_by(key: ADMIN)
    end
    
    def manager
      find_by(key: MANAGER)
    end
    
    def associate
      find_by(key: ASSOCIATE)
    end
    
    # Method to set up default roles
    def seed_default_roles
      return if exists?
      
      create([
        { name: 'Admin', key: ADMIN, description: 'Full access to the system', hierarchy_level: 100 },
        { name: 'Manager', key: MANAGER, description: 'Can manage associates and view their data', hierarchy_level: 50 },
        { name: 'Associate', key: ASSOCIATE, description: 'Basic access to manage assigned customers', hierarchy_level: 10 }
      ])
    end
  end
  
  # Returns all roles with lower hierarchy level
  def subordinate_roles
    Role.where('hierarchy_level < ?', hierarchy_level)
  end
  
  # Checks if this role has higher authority than another role
  def outranks?(other_role)
    return false unless other_role
    hierarchy_level > other_role.hierarchy_level
  end
end
