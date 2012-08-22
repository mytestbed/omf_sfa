
require 'nokogiri'    
require 'time'
require 'zlib'
require 'base64'
require 'openssl'
#require 'xmlsec'
require 'tempfile'

require 'omf-sfa/am/am-rpc/abstract_rpc_service'
require 'omf-sfa/am/authorizer'

require 'omf-sfa/am/am-rpc/am_rpc_api'
require 'omf-sfa/am/privilege_credential'
require 'omf-sfa/am/user_credential'
  
module OMF::SFA::AM::RPC
    
  class NotAuthorizedException < XMLRPC::FaultException; end
  
  class AMService < AbstractService
    include OMF::Common::Loggable
    
    #implement ServiceAPI
    implement AMServiceAPI

    def get_version
      debug "GetVersion"

      {
        :geni_api => 1,
        :omf_am => "0.1",
        :ad_rspec_versions => [{ 
          :type => 'ProtoGENI',
          :version => '2',
          :namespace => 'http://www.protogeni.net/resources/rspec/2',
          :schema => 'http://www.protogeni.net/resources/rspec/2/ad.xsd',
          :extensions => []
        }]
      }
    end
  
    def list_resources(credentials, options)
      @authorizer = OMF::SFA::AM::Authorizer.create_for_web_request(@request.env, @manager)
      debug 'ListResources: Options: ', options.inspect
      
      only_available = options["geni_available"]
      compressed = options["geni_compressed"]
      slice_urn = options["geni_slice_urn"]
  
      check_credentials(:ListResources, slice_urn, credentials)
      resources = get_resources(slice_urn, only_available)
      res = OMF::SFA::Resource::OComponent.sfa_advertisement_xml(resources).to_xml
      if compressed
        res = Base64.encode64(Zlib::Deflate.deflate(res))
      end
      res
    end
  
    def create_sliver(slice_urn, credentials, rspec_s, users)
      debug 'CreateSliver: SLICE URN: ', slice_urn, ' RSPEC: ', rspec_s, ' USERS: ', users.inspect
      check_credentials(:CreateSliver, slice_urn, credentials)
      account = @manager.find_or_create_account(:urn => slice_urn)
      if account.closed?
        raise "Can't recreate a previously deleted sliver"
      end
      #debug "Slice '#{slice_urn}' associated with account '#{account.id}:#{account.closed_at}'"

      rspec = Nokogiri::XML.parse(rspec_s)
      resources = @manager.update_resources_from_xml(rspec.root, true, {:account => account})

      # TODO: Still need to implement USER handling
        
      OMF::SFA::Resource::OComponent.sfa_advertisement_xml(resources).to_s
    end
  
    def sliver_status(slice_urn, credentials)
      debug('SliverStatus for ', slice_urn)
      check_credentials(:SliverStatus, slice_urn, credentials)
      account = @manager.find_account(:urn => slice_urn)
      
      status = {}
      status['geni_urn'] = slice_urn
      # Any of the following configuring, ready, failed, and unknown
      status['geni_status'] = 'unknown'
      status['omf_expires_at'] = account.valid_until.utc.strftime('%Y%m%d%H%M%SZ')
      status['geni_resources'] = resources = get_resources(slice_urn, true).collect do |r|
        {
          'geni_urn'=> r.urn,
          'geni_status' => r.status,
          'geni_error' => '',          
        }
      end
  
      status
    end
  
    def renew_sliver(slice_urn, credentials, expiration_time)
      debug('RenewSliver ', slice_urn, ' until <', expiration_time.class, '>')          
      debug('RenewSliver ', slice_urn, ' until <', Time.parse(expiration_time), '>')
      check_credentials(:RenewSliver, slice_urn, credentials)
      @manager.renew_account_until({:urn => slice_urn}, expiration_time)
      true
    end
  
    def delete_sliver(slice_urn, credentials)
      debug('DeleteSliver ', slice_urn)
      check_credentials(:DeleteSliver, slice_urn, credentials)
      account = @manager.delete_account({:urn => slice_urn})
      debug "Slice '#{slice_urn}' associated with account '#{account.id}:#{account.closed_at}'"
      true
    end
  
    def shutdown_sliver(slice_urn, credentials)
      check_credentials(:Shutdown, slice_urn, credentials)
      puts "SLICE URN: #{slice_urn}"
      true
    end
    
    private 
    
    def initialize(opts)
      super
      @manager = opts[:manager]
    end
  
    def get_resources(slice_urn, available_only)
#      begin 
        resources = @manager.find_all_components_for_account(slice_urn, @authorizer)
        
        # only list independent resources
        resources = resources.select {|r| r.independent_component?}
        #debug "Resources for '#{slice_urn}' >>> #{resources.inspect}"
        
      # rescue UnavailableResourceException => ex
        # raise ex
        # # resources = []
      # rescue Exception => ex
        # error ex
        # debug "Backtrace\n\t#{ex.backtrace.join("\n\t")}"
        # raise ex
      # end
      
    end

  
    # Throws exception if credentials XML encoded in +cred_string_a+ 
    # are *not* sufficient for _action_
    #
    def check_credentials(action, slice_urn, cred_string_a)
      credentials = unmarshall_credentials(cred_string_a)
      #
      # TODO: Check policy for +action+
      # raise NotAuthorizedException.new(99, 'Insufficient credentials')
      
      credentials
    end
    
    def unmarshall_credentials(cred_string_a)
      begin 
        unless cert_s = @request.env['rack.peer_cert']
          raise "Missing peer cert"
        end
        peer_cert = OMF::SFA::AM::UserCredential.unmarshall(cert_s)
      end
      
      debug "Requester: #{peer_cert.subject} :: #{peer_cert.user_urn}"
      begin 
        credentials = cred_string_a.map do |cd|
          #debug "Credential: ", cd
          OMF::SFA::AM::PrivilegeCredential.unmarshall(cd)
        end
      rescue Exception => ex
        warn "Error while parsing credentials #{ex}"
        debug "\t#{ex.backtrace.join("\n\t")}"
      end
      debug "Credentials::: #{credentials.inspect}"
      credentials
    end
    
    
  end # AMService
  
end # module



