require 'test/unit'
require 'active_record'
require 'fileutils'
require File.expand_path(File.dirname(__FILE__) + "/../lib/paranoia")

DB_FILE = 'tmp/test_db'

FileUtils.mkdir_p File.dirname(DB_FILE)
FileUtils.rm_f DB_FILE

ActiveRecord::Base.establish_connection :adapter => 'sqlite3', :database => DB_FILE
ActiveRecord::Base.connection.execute 'CREATE TABLE paranoid_models (id INTEGER NOT NULL PRIMARY KEY, deleted_at DATETIME)'
ActiveRecord::Base.connection.execute 'CREATE TABLE featureful_models (id INTEGER NOT NULL PRIMARY KEY, deleted_at DATETIME, name VARCHAR(32))'
ActiveRecord::Base.connection.execute 'CREATE TABLE plain_models (id INTEGER NOT NULL PRIMARY KEY, deleted_at DATETIME)'
ActiveRecord::Base.connection.execute 'CREATE TABLE callback_models (id INTEGER NOT NULL PRIMARY KEY, deleted_at DATETIME)'
ActiveRecord::Base.connection.execute 'CREATE TABLE scoped_models (id INTEGER NOT NULL PRIMARY KEY, state INTEGER, deleted_at DATETIME)'

class ParanoiaTest < Test::Unit::TestCase
  def test_plain_model_class_is_not_paranoid
    assert_equal false, PlainModel.paranoid?
  end

  def test_paranoid_model_class_is_paranoid
    assert_equal true, ParanoidModel.paranoid?
  end

  def test_plain_models_are_not_paranoid
    assert_equal false, PlainModel.new.paranoid?
  end

  def test_paranoid_models_are_paranoid
    assert_equal true, ParanoidModel.new.paranoid?
  end

  def test_destroy_behavior_for_plain_models
    model = PlainModel.new
    assert_equal 0, model.class.count
    model.save!
    assert_equal 1, model.class.count
    model.destroy

    assert_equal true, model.deleted_at.nil?
    assert model.frozen?

    assert_equal 0, model.class.count
    assert_equal 0, model.class.unscoped.count
  end

  def test_destroy_behavior_for_paranoid_models
    model = ParanoidModel.new
    assert_equal 0, model.class.count
    model.save!
    assert_equal 1, model.class.count
    model.destroy

    assert_equal false, model.deleted_at.nil?
    assert model.frozen?

    assert_equal 0, model.class.count
    assert_equal 1, model.class.unscoped.count

  end

  def test_destroy_behavior_for_featureful_paranoid_models
    model = get_featureful_model
    assert_equal 0, model.class.count
    model.save!
    assert_equal 1, model.class.count
    model.destroy

    assert_equal false, model.deleted_at.nil?

    assert_equal 0, model.class.count
    assert_equal 1, model.class.unscoped.count
  end

  def test_only_destroyed_scope_for_paranoid_models
    model = ParanoidModel.new
    model.save
    model.destroy
    model2 = ParanoidModel.new
    model2.save

    assert_equal model, ParanoidModel.only_deleted.last
    assert_equal false, ParanoidModel.only_deleted.include?(model2)
  end
  
  def test_delete_behavior_for_callbacks
    model = CallbackModel.new
    model.save
    model.delete
    assert_equal nil, model.instance_variable_get(:@callback_called)
  end
  
  def test_destroy_behavior_for_callbacks
    model = CallbackModel.new
    model.save
    model.destroy
    assert model.instance_variable_get(:@callback_called)
  end
  
  def test_restore
    model = ParanoidModel.new
    model.save
    id = model.id
    model.destroy
    
    assert model.destroyed?
    
    model = ParanoidModel.only_deleted.find(id)
    model.restore!
    
    assert_equal false, model.destroyed?
  end
  
  def test_real_destroy
    model = ParanoidModel.new
    model.save
    model.destroy!
    
    assert_equal false, ParanoidModel.unscoped.exists?(model.id)
  end
  
  def test_real_delete
    model = ParanoidModel.new
    model.save
    model.delete!
    
    assert_equal false, ParanoidModel.unscoped.exists?(model.id)
  end

  def test_with_additional_scopes
    model = ScopedModel.new
    model.save

    model2 = ScopedModel.new(:state => 2)
    model2.save

    model3 = ScopedModel.new
    model3.save
    model3.delete

    assert_equal 1, ScopedModel.count
    assert_equal 3, ScopedModel.unscoped.count
    assert_equal 1, ScopedModel.only_deleted.count
    assert_equal 2, ScopedModel.default_scope_with_deleted.count

    model2.delete
    assert_equal 1, ScopedModel.count
    assert_equal 3, ScopedModel.unscoped.count
    assert_equal 2, ScopedModel.only_deleted.count
    assert_equal 2, ScopedModel.default_scope_with_deleted.count

    model.delete
    assert_equal 0, ScopedModel.count
    assert_equal 3, ScopedModel.unscoped.count
    assert_equal 3, ScopedModel.only_deleted.count
    assert_equal 2, ScopedModel.default_scope_with_deleted.count
  end

  private
  def get_featureful_model
    FeaturefulModel.new(:name => "not empty")
  end
end

# Helper classes

class ParanoidModel < ActiveRecord::Base
  acts_as_paranoid
end

class FeaturefulModel < ActiveRecord::Base
  acts_as_paranoid
  validates :name, :presence => true, :uniqueness => true
end

class PlainModel < ActiveRecord::Base
end

class CallbackModel < ActiveRecord::Base
  acts_as_paranoid
  before_destroy {|model| model.instance_variable_set :@callback_called, true }
end

class ScopedModel < ActiveRecord::Base
  self.acts_as_paranoid where(:state => 1).scoped
end
