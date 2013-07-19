
require 'omf-sfa/am/am-rest/rest_handler'
require 'omf-sfa/am/am-rest/resource_handler'

#require 'omf-sfa/resource/sliver'

module OMF::SFA::AM::Rest

  # Handles the collection of accounts on this AM.
  #
  class AccountHandler < RestHandler

    def initialize(opts = {})
      super
      @resource_class = OMF::SFA::Resource::OAccount
      opts[:account_handler] = self
      @coll_handlers = {
        active_components: (opts[:resource_handler] || ResourceHandler.new(opts))
      }
    end

    def show_resource_list(opts)
      authenticator = Thread.current["authenticator"]
      prefix = about = opts[:req].path
      resources = OMF::SFA::Resource::OAccount.all()
      show_resources(resources, :resources, opts)
    end

    # def find_handler(path, opts)
      # account_id = opts[:resource_uri] = path.shift
      # if account_id
        # account = opts[:account] = find_account(account_id)
      # end
      # return self if path.empty?
#
      # case comp = path.shift
      # when 'resources'
        # opts[:resource_uri] = path.join('/')
        # #puts "RESOURCE >>> '#{r}'::#{account.inspect}"
        # return @res_handler
      # end
      # raise UnknownResourceException.new "Unknown sub collection '#{comp}' for account '#{account_id}'."
    # end
#
    # def on_get(account_uri, opts)
      # debug 'get: account_uri: "', account_uri, '"'
      # if account_uri
        # account = opts[:account]
        # show_account_status(account, opts)
      # else
        # show_accounts(opts)
      # end
    # end
#
    # # def on_put(account_uri, opts)
      # # account = opts[:account] = OMF::SFA::Resource::Sliver.first_or_create(:name => opts[:account_id])
      # # configure_sliver(sliver, opts)
      # # show_sliver_status(sliver, opts)
    # # end
#
    # def on_delete(account_uri, opts)
      # account = opts[:account]
      # @am_manager.delete_account(account)
#
      # show_account_status(nil, opts)
    # end
#
    # # SUPPORTING FUNCTIONS
#
    # def show_account_status(account, opts)
      # if account
        # p = opts[:req].path.split('/')[0 .. -2]
        # p << account.uuid.to_s
        # prefix = about = p.join('/')
        # res = {
          # :about => about,
          # :type => 'account',
          # :properties => {
              # #:href => prefix + '/properties',
              # :expires_at => (Time.now + 600).rfc2822
          # },
          # :resources => {:href => prefix + '/resources'},
          # :policies => {:href => prefix + '/policies'},
          # :assertion => {:href => prefix + '/assertion'}
        # }
      # else
        # res = {:error => 'Unknown account'}
      # end
#
      # ['application/json', JSON.pretty_generate({:account_response => res})]
    # end
#
    # def show_accounts(opts)
      # authenticator = Thread.current["authenticator"]
      # prefix = about = opts[:req].path
      # accounts = @am_manager.find_all_accounts(authenticator).collect do |a|
        # {
          # :name => a.name,
          # :urn => a.urn,
          # :uuid => uuid = a.uuid.to_s,
          # :href => prefix + '/' + uuid
        # }
      # end
      # res = {
        # :about => opts[:req].path,
        # :accounts => accounts
      # }
#
      # ['application/json', JSON.pretty_generate({:accounts_response => res})]
    # end
#
    # # Configure the state of +account+ according to information
    # # in the http +req+.
    # #
    # # Note: It doesn't actually modify the account directly, but parses the
    # # the body and delegates the individual entries to the relevant
    # # sub collections, like 'resources', 'policies', ...
    # #
    # def configure_account(account, opts)
      # doc, format = parse_body(opts)
      # case format
      # when :xml
        # doc.xpath("//r:resources", 'r' => 'http://schema.mytestbed.net/am_rest/0.1').each do |rel|
          # @res_handler.put_components_xml(rel, opts)
        # end
      # else
        # raise BadRequestException.new "Unsupported message format '#{format}'"
      # end
    # end
#
    # def find_account(account_id)
      # if account_id.start_with?('urn')
        # fopts = {:urn => account_id}
      # else
        # begin
          # fopts = {:uuid => UUIDTools::UUID.parse(account_id)}
        # rescue ArgumentError
          # fopts = {:name => account_id}
        # end
      # end
      # authenticator = Thread.current["authenticator"]
      # account = @am_manager.find_account(fopts, authenticator)
    # end
  end
end
