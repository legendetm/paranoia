module Paranoia
  attr_accessor :paranoid_default_scope

  def self.included(klazz)
    klazz.extend Query
  end

  module Query
    def paranoid? ; true ; end

    def only_deleted
      unscoped {
        where("deleted_at is not null")
      }
    end

    def default_scope_with_deleted
      unscoped {
        end_of_paranoid_default_scope
      }
    end
    alias :with_deleted :default_scope_with_deleted
  end

  def destroy
    _run_destroy_callbacks { delete }
  end

  def delete    
    self.update_attribute(:deleted_at, Time.now) if !deleted? && persisted?
    freeze
  end
  
  def restore!
    update_attribute :deleted_at, nil
  end

  def destroyed?
    !self.deleted_at.nil?
  end
  alias :deleted? :destroyed?
end

class ActiveRecord::Base
  def self.acts_as_paranoid(paranoid_default_scope=nil)
    alias_method :destroy!, :destroy
    alias_method :delete!,  :delete
    include Paranoia

    self.paranoid_default_scopes += [paranoid_default_scope] unless paranoid_default_scope.nil?
    default_scope end_of_paranoid_default_scope.where(:deleted_at => nil)
  end

  def self.paranoid? ; false ; end
  def paranoid? ; self.class.paranoid? ; end

protected
  class_attribute :paranoid_default_scopes, :instance_writer => false
  self.paranoid_default_scopes = []
  def self.end_of_paranoid_default_scope
    paranoid_default_scopes.inject(relation) do |default_scope, scope|
      if scope.is_a?(Hash)
        default_scope.apply_finder_options(scope)
      elsif !scope.is_a?(Arel::Relation) && scope.respond_to?(:call)
        default_scope.merge(scope.call)
      else
        default_scope.merge(scope)
      end
    end
  end
end
