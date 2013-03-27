require 'omf_common'
require 'omf_common/dsl/xmpp'

#require 'omf-sfa/resource'
require 'omf-sfa/am/am_manager'


module OMF::SFA::AM

  extend OMF::SFA::AM

  # This class implements the AM Liaison
  #
  class AMLiaison < OMF::Common::LObject
    
    include OmfCommon::DSL::Xmpp

    attr_accessor :comm
    @leases = {}

    def initialize
      @comm = OmfCommon::Comm.new(:xmpp)
      EM.next_tick { @comm.connect('am_liaison', 'pw', 'localhost') }
    end    

    #def self.leases
    #  @@leases ||= {}
    #end

    # It will send the corresponding create messages to the components contained
    # in the lease when the lease is about to start. At the end of the
    # lease the corresponding release messages will be sent to the components.
    #
    # @param [OLease] lease Contains the lease information "valid_from" and 
    #                 "valid_until" along with the reserved components
    #
    def enable_lease(lease, component)
      debug "enable_lease: lease: '#{lease.inspect}' component: '#{component.inspect}'"

      resource_topic = @comm.get_topic(component.name)
      raise UnknownResourceException.new "Cannot find resource's pubsub topic: '#{component.inspect}'" unless resource_topic

      msg = @comm.create_message do |message|
        message.property('name', component.name)
        message.property('type', component.type)
      end

      msg.on_inform_created do |message|
        logger.info "Resource '#{message.resource_id}' successfully created at #{Time.now}"
        created_topic = @comm.get_topic(message.resource_id)

        # TODO: we need to define whether we ask for specific resource_id in the create
        # message or we let the resource_factory to pick one. We need to keep it synced 
        # with the resource_id we have in the DB. 
        resource_id = created_topic.id

        r_msg = @comm.release_message { |m| m.element('resource_id', resource_id) }

        r_msg.on_inform_released do |message|
          logger.info "Resource (#{message.resource_id}) released at #{Time.now}"
        end

        timer = EventMachine::Timer.new(lease[:valid_until] - Time.now) do
          r_msg.publish resource_topic.id
          @leases[lease].delete(component.id)
          @leases.delete(lease) if @leases[lease].empty?
        end
        @leases[lease][component.id] = {:end => timer}
      end

      timer = EventMachine::Timer.new(lease[:valid_from] - Time.now) do
        resource_topic.subscribe do
          # If subscribed, we publish a 'create' message
          msg.publish resource_topic.id
        end
      end

      @leases[lease] = {} unless @leases[lease]
      @leases[lease] = { component.id => {:start => timer} }
    end


    #def release_lease(resource)

    #  resource_topic = @comm.get_topic(resource.name)

    #  raise UnknownResourceException.new "Cannot find resource's pubsub topic: '#{resource.inspect}'" unless resource_topic

    #end

  end # AMLiaison
end # OMF::SFA::AM

