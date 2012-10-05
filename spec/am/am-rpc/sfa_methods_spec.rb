require 'omf-sfa/am/am-rpc/am_rpc_service'
require 'omf-sfa/am/am_manager'
require 'dm-migrations'

include OMF::SFA::AM::RPC

def init_dm
  #setup database
  DataMapper::Logger.new($stdout, :info)

  DataMapper.setup(:default, 'sqlite::memory:')
  #DataMapper.setup(:default, 'sqlite:///tmp/am_test.db')
  DataMapper::Model.raise_on_save_failure = true
  DataMapper.finalize

  DataMapper.auto_migrate!
end

describe AMService do

  init_dm
  
  before (:each) { DataMapper.auto_migrate! }

  let (:manager) { double('am_manager') }

  let(:authorizer) { double('authorizer') }

  let (:am_rpc) do
    @am_rpc = AMService.new(:manager => manager) 
    @am_rpc.authorizer = authorizer
    @am_rpc
  end

  it 'will respond to get_version' do

    res = {
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

    am_rpc.get_version.should be_eql(res)
  end

  it 'will return all the resources of a slice' do
    
    account = OMF::SFA::Resource::OAccount.new(:urn => "urn:publicid:IDN+omf:test+account+1")
    OMF::SFA::Resource::Node.create({:name => 'node1', :account => account})

    authorizer.should_receive(:check_credentials).with(:ListResources, "urn:publicid:IDN+omf:test+account+1", "cred")

    manager.should_receive(:find_or_create_account).with({:urn => "urn:publicid:IDN+omf:test+account+1"}, anything)

    manager.stub(:find_all_components_for_account) do
      res = OMF::SFA::Resource::OComponent.all(:account => account)
    end

    res = am_rpc.list_resources("cred", {"geni_available" => false, "geni_compressed" => false, "geni_slice_urn" => "urn:publicid:IDN+omf:test+account+1"})

    req = Nokogiri.XML(res)
    node = req.xpath('//xmlns:node').first
    node[:component_name].should be_eql('node1')
  end

  it 'will create a sliver' do
    account = OMF::SFA::Resource::OAccount.new(:urn => "urn:publicid:IDN+omf:test+account+1")
    OMF::SFA::Resource::Node.create({:name => 'node1', :account => account})

    authorizer.should_receive(:check_credentials).with(:CreateSliver, "urn:publicid:IDN+omf:test+account+1", "cred")

    manager.should_receive(:find_or_create_account).with({:urn => "urn:publicid:IDN+omf:test+account+1"}, authorizer).and_return(account)

    resources = OMF::SFA::Resource::OComponent.all(:account => account)
    manager.should_receive(:update_resources_from_rspec).and_return(resources)

    res = am_rpc.create_sliver("urn:publicid:IDN+omf:test+account+1", "cred", "rspecs_here", "users")

    req = Nokogiri.XML(res)
    node = req.xpath('//xmlns:node').first
    node[:component_name].should be_eql('node1')
  end

  it "will return the status of a sliver" do

    account = OMF::SFA::Resource::OAccount.new(:urn => "urn:publicid:IDN+omf:test+account+1")
    OMF::SFA::Resource::Node.create({:name => 'node1', :account => account})

    authorizer.should_receive(:check_credentials).with(:SliverStatus, "urn:publicid:IDN+omf:test+account+1", "cred")

    manager.should_receive(:find_account).with({:urn => "urn:publicid:IDN+omf:test+account+1"}, authorizer).and_return(account)

    manager.should_receive(:find_or_create_account).with({:urn => "urn:publicid:IDN+omf:test+account+1"}, anything)

    manager.stub(:find_all_components_for_account) do
      OMF::SFA::Resource::OComponent.all(:account => account)
    end

    res = am_rpc.sliver_status("urn:publicid:IDN+omf:test+account+1", "cred")
    
    res['geni_urn'].should be_eql("urn:publicid:IDN+omf:test+account+1")
    node = res['geni_resources'].first
    node['geni_urn'].should be_eql("urn:publicid:IDN+mytestbed.net+node+node1")
  end

  it "will renew a sliver" do
    expiration_time = DateTime.new(2014).rfc3339

    authorizer.should_receive(:check_credentials).with(:RenewSliver, "urn:publicid:IDN+omf:test+account+1", "cred")
    
    manager.should_receive(:renew_account_until).with({:urn => "urn:publicid:IDN+omf:test+account+1"}, expiration_time, authorizer)

    am_rpc.renew_sliver("urn:publicid:IDN+omf:test+account+1", "cred", expiration_time)
  end

  it "will delete a sliver" do

    OMF::SFA::Resource::OAccount.new(:urn => "urn:publicid:IDN+omf:test+account+1")

    account = authorizer.should_receive(:check_credentials).with(:DeleteSliver, "urn:publicid:IDN+omf:test+account+1", "cred")

    manager.stub(:close_account) do |slice_urn, auth|
      account = OMF::SFA::Resource::OAccount.first(slice_urn)
      account.close
      account.save
      account
    end

    am_rpc.delete_sliver("urn:publicid:IDN+omf:test+account+1", "cred")
    account.should be_closed
  end

  it "will shutdown sliver" do

    account = OMF::SFA::Resource::OAccount.new(:urn => "urn:publicid:IDN+omf:test+account+1")

    authorizer.should_receive(:check_credentials).with(:Shutdown, "urn:publicid:IDN+omf:test+account+1", "cred")
    manager.should_receive(:find_account).and_return(account)
    authorizer.should_receive(:can_close_account?).with(account)

    am_rpc.shutdown_sliver("urn:publicid:IDN+omf:test+account+1", "cred")
    account.should be_closed
  end
end
