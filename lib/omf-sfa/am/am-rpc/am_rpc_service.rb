
require 'nokogiri'
require 'time'
require 'zlib'
require 'base64'
require 'openssl'

require 'omf-sfa/am/am-rpc/abstract_rpc_service'
require 'omf-sfa/am/am-rpc/am_authorizer'

require 'omf-sfa/am/am-rpc/am_rpc_api'
#require 'omf-sfa/am/privilege_credential'
#require 'omf-sfa/am/user_credential'

module OMF::SFA::AM::RPC

  class NotAuthorizedException < XMLRPC::FaultException; end

  class AMService < AbstractService
    include OMF::Common::Loggable

    attr_accessor :authorizer

    #implement ServiceAPI
    implement AMServiceAPI

    def get_version(opts = {})
      debug "GetVersion - #{opts}"
      {
      	:api => 2,
      	:geni_api => 2,
      	:omf_am => 1,
      	:geni_ad_rspec_versions => [{
      	  :type => 'ProtoGENI',
      	  :version => '2',
      	  :namespace => 'http://www.protogeni.net/resources/rspec/2',
      	  :schema => 'http://www.protogeni.net/resources/rspec/2/ad.xsd',
      	  :extensions => []
      	}]
      }
      {
        geni_api: 2,
        code: {
           geni_code: 0 # Success
           # am_type and am_code are optional. Leaving them out.
         },
        value: {
          #:api => 2,
          :geni_api => 2,
          geni_api_versions: {
               #'3' => 'https://0.0.0.0:8001', # This server's AM API absolute URL>
               #'2' => 'https://0.0.0.0:8001/RPC2' #Prior API version still supported at a slightly different URL - optional but included here>
          },
          :omf_am => 1,
          :geni_ad_rspec_versions => [{
            :type => 'ProtoGENI',
            :version => '2',
            :namespace => 'http://www.protogeni.net/resources/rspec/2',
            :schema => 'http://www.protogeni.net/resources/rspec/2/ad.xsd',
            :extensions => []
          }]
        }
      }
      # {
        # geni_api: 3, # This is AM API v3
        # code: {
             # geni_code: 0 # Success
             # # am_type and am_code are optional. Leaving them out.
           # },
        # value: {
              # geni_api: 3, # Match above
              # geni_api_versions: {
                   # #'3' => 'https://0.0.0.0:8001', # This server's AM API absolute URL>
                   # '2' => 'https://0.0.0.0:8001/RPC2' #Prior API version still supported at a slightly different URL - optional but included here>
              # },
              # geni_request_rspec_versions: [{
                   # type: "GENI", # case insensitive
                   # version: "3", # case insensitive
                   # schema: "http://www.geni.net/resources/rspec/3/request.xsd", # required but may be empty
                   # namespace: "http://www.geni.net/resources/rspec/3", # required but may be empty
                   # extensions: [] # required but may be empty
              # }],
              # geni_ad_rspec_versions: [{
                   # type: "GENI", # case insensitive
                   # version: "3", # case insensitive
                   # schema: "http://www.geni.net/resources/rspec/3/ad.xsd", # required but may be empty
                   # namespace: "http://www.geni.net/resources/rspec/3", # required but may be empty
                   # extensions: [] # required but may be empty
              # }],
              # geni_credential_types: [{ # This AM accepts only SFA style credentials for API v3
                   # geni_type: "geni_sfa", # case insensitive
                   # geni_version: "3" # case insensitive
             # }],
             # #geni_single_allocation = 0 # false - can operate on individual slivers. This is the default, so could legally be omitted here.
             # geni_allocate: "geni_many" # Can do multiple Allocates. This is not the default value, so is required here.
            # }
      # }
    end

    def list_resources(credentials, options)
      debug 'ListResources: Options: ', options.inspect

      only_available = options["geni_available"]
      compressed = options["geni_compressed"]
      slice_urn = options["geni_slice_urn"]

      authorizer = OMF::SFA::AM::RPC::AMAuthorizer.create_for_sfa_request(slice_urn, credentials, @request, @manager)
      #@authorizer.check_credentials(slice_urn, credentials.first, @manager)
      resources = @manager.find_all_components_for_account(authorizer.account, authorizer)
      # TODO: implement the "available_only" option

      # only list independent resources (TODO: What does this mean??)
      resources = resources.select {|r| r.independent_component?}
      #debug "Resources for '#{slice_urn}' >>> #{resources.inspect}"

      res = OMF::SFA::Resource::OComponent.sfa_advertisement_xml(resources).to_xml
      if compressed
	      res = Base64.encode64(Zlib::Deflate.deflate(res))
      end
      #res
      {value: res, code: { geni_code: 0 }}
    end

    def create_sliver(slice_urn, credentials, rspec_s, users)
      debug 'CreateSliver: SLICE URN: ', slice_urn, ' RSPEC: ', rspec_s, ' USERS: ', users.inspect
      #@authorizer.check_credentials(slice_urn, credentials.first, @manager)
      authorizer = OMF::SFA::AM::RPC::AMAuthorizer.create_for_sfa_request(slice_urn, credentials, @request, @manager)

      rspec = Nokogiri::XML.parse(rspec_s)
      resources = @manager.update_resources_from_rspec(rspec.root, true, authorizer)

      # TODO: Still need to implement USER handling

      OMF::SFA::Resource::OComponent.sfa_advertisement_xml(resources).to_s
    end

    def sliver_status(slice_urn, credentials)
      debug('SliverStatus for ', slice_urn)
      #@authorizer.check_credentials(slice_urn, credentials.first, @manager)
      authorizer = OMF::SFA::AM::RPC::AMAuthorizer.create_for_sfa_request(slice_urn, credentials, @request, @manager)

      status = {}
      status['geni_urn'] = slice_urn
      # Any of the following configuring, ready, failed, and unknown
      status['geni_status'] = 'unknown'
      status['omf_expires_at'] = authorizer.account.valid_until.utc.strftime('%Y%m%d%H%M%SZ')

      resources = @manager.find_all_components_for_account(authorizer.account, authorizer)
      # only list independent resources
      resources = resources.select {|r| r.independent_component?}
      status['geni_resources'] = resources.collect do |r|
      	{
      	  'geni_urn'=> r.urn,
      	  'geni_status' => r.status,
      	  'geni_error' => '',
      	}
      end
      status
    end

    def renew_sliver(slice_urn, credentials, expiration_time)
      #debug('RenewSliver ', slice_urn, ' until <', expiration_time.to_time.class, '>')
      expiration_time = expiration_time.to_time # is XMLRP::DateTime
      debug('RenewSliver ', slice_urn, ' until <', expiration_time, '>')
      #authorizer.check_credentials(slice_urn, credentials.first, @manager)
      authorizer = OMF::SFA::AM::RPC::AMAuthorizer.create_for_sfa_request(slice_urn, credentials, @request, @manager)

      @manager.renew_account_until({ :urn => slice_urn }, expiration_time, authorizer)
      true
    end

    # close the account and release the attached resources
    def delete_sliver(slice_urn, credentials)
      debug('DeleteSliver ', slice_urn)
      #@authorizer.check_credentials(slice_urn, credentials.first, @manager)
      authorizer = OMF::SFA::AM::RPC::AMAuthorizer.create_for_sfa_request(slice_urn, credentials, @request, @manager)

      # We don't like deleting things
      account = @manager.close_account({ :urn => slice_urn }, authorizer)
      # TODO: Should this really be here? Seems to be the job of the AM manager.
      @manager.release_all_components_for_account(account, authorizer)
      debug "Slice '#{slice_urn}' associated with account '#{account.id}:#{account.closed_at}'"
      true
    end

    # close the account but do not release its resources
    def shutdown_sliver(slice_urn, credentials)
      #@authorizer.check_credentials(slice_urn, credentials.first, @manager)
      authorizer = OMF::SFA::AM::RPC::AMAuthorizer.create_for_sfa_request(slice_urn, credentials, @request, @manager)

      #puts "SLICE URN: #{slice_urn}"
      account = @manager.close_account({ :urn => slice_urn }, authorizer)
      true
    end

    private

    def initialize(opts)
      super
      @manager = opts[:manager]
    end

  end # AMService

end # module



