

require 'omf-sfa/resource/oresource'
require 'omf-sfa/resource/ogroup'
require 'omf-sfa/resource/sfa_base'
require 'omf-sfa/resource/olease'

module OMF::SFA::Resource

  # Components are resources with a management interface.
  #
  class OComponent < OResource

    oproperty :domain, String #, readonly => true
    oproperty :exclusive, DataMapper::Property::Boolean

    # Status of component. Should be any of configuring, ready, failed, and unknown
    oproperty :status, String, :default => 'unknown'

    # Beside the set of 'physical' resources, most resources are actually provided
    # by other resources. Currently we assume that to be a one-to-many relation and
    # we maintain links in both directions (A.provides B; B.provided_by A).
    #
    oproperty :provides, self, :functional => false
    oproperty :provided_by, self

    has n, :component_leases, :child_key => [:component_id]
    has n, :leases, :model => 'OLease', :through => :component_leases, :via => :lease

    extend OMF::SFA::Resource::Base::ClassMethods
    include OMF::SFA::Resource::Base::InstanceMethods

    sfa_add_namespace :omf, 'http://schema.mytestbed.net/sfa/rspec/1'

    sfa :component_id, :attribute => true # "urn:publicid:IDN+plc:cornell+node+planetlab3-dsl.cs.cornell.edu" 
    sfa :component_manager_id, :attribute => true # "urn:publicid:IDN+plc+authority+am" 
    sfa :component_name, :attribute => true # "plane
    sfa :exclusive, :attribute => false 
    sfa :lease, :inline => true, :has_many => true
    alias_method :lease, :leases

    # def component_id
    # res = oproperty_get(:id)
    # end

    def component_name
      # the name property may have the full component name including domain and type
      self.name.split('+')[-1]
    end

    def update_from_xml(modifier_el, opts)
      if modifier_el.children.length > 0
        warn "'update_from_xml' not implememted '#{modifier_el.inspect}'"
      end
    end

    def create_from_xml(modifier_el, opts)
      if modifier_el.children.length > 0
        warn "'update_from_xml' not implememted '#{modifier_el.inspect}'"
      end
    end

    # Return true if this is an independent component or not. Independent
    # components are listed as assignable, reservable resources, while 
    # dependent ones are are tied to some other resource and need to 
    # 'stick' with their master. Interface is such an example.
    #
    def independent_component?
      true
    end

    def destroy
      if !self.provides.empty?
        raise OMF::SFA::AM::MissingImplementationException.new("Don't know yet how to delete resource which still provides other resources")
      end
      provider = self.provided_by      

      if provider
        pa = provider.provides
        pa.delete self
        # This assumes that base resources can only provide one virtual resource
        # TODO: This doesn't really test if the provider is a base resource
        provider.available = true
        provider.save
      end

      self.component_leases.each do |l|
        # unlink the resource with all its leases
        raise "Couldn't unlink resource with lease: #{l}" unless l.destroy 
      end

      super
    end

    before :save do
      self.urn = GURN.create(self.name, self)
    end

    def destroy!
      destroy
      super
    end
  end  # OComponent
end # OMF::SFA::Resource
