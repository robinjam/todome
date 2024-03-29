class LocationType < ActiveRecord::Base
  has_many :taggings, :dependent => :destroy
  has_many :tags, :through =>:taggings
  has_many :locations, :dependent => :nullify
  
  attr_accessible nil
end
