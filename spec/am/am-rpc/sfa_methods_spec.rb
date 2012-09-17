require 'omf-sfa/am/am-rpc/am_rpc_service'

include OMF::SFA::AM::RPC

describe AMService do

  let (:manager) { double('am_manager') }

  let (:am_rpc) { @am_rpc = AMService.new(:manager => manager) }

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
end
