
require 'omf_base/lobject'
OMF::Base::Loggable.init_log 'brite2rspec'

require 'omf-sfa/util/brite_parser'
require 'omf-sfa/resource'
include OMF::SFA::Resource

GURN.default_domain = "urn:publicid:IDN+acme.org"

unless file_name = ARGV[0]
  puts "Missing BRITE file name - #{ARGV}"
  exit -1
end

OMF::SFA::Resource::OResource.init()

node_services = []
node_services << ExecuteService.create(command: "sudo sh /local/postboot_script.sh", shell: "sh")
node_services << InstallService.create(install_path: "/local", url: "http://emmy9.casa.umass.edu/InstaGENI_Images/install-script.tar.gz")

di = DiskImage.create(url: "urn:publicid:IDN+utah.geniracks.net+image+emulab-ops:OPENVZ-STD")
sliver_type = SliverType.create(name: 'emulab-openvz', disk_image: di)

parser = OMF::SFA::Util::BriteParser.new()
# opts; [:id, :i], [:x, :f], [:y, :f], [:type]
parser.on_new_node do |opts|
  name = "n#{opts[:id]}"
  node = Node.create(name: name, urn: 'foo_urn', sliver_type: sliver_type, exclusive: false)
  node_services.each {|s| node.services << s }
  node
end

network_cnt = 0
# opts: [:id, :i], [:from, :i], [:to, :i], [:length, :f], [:delay, :f], [:bw, :f], [:type], [:direction]
parser.on_new_edge do |opts, from, to|
  name = "l#{opts[:id]}"
  link = Link.create(name: name)

  # Create a new subnet for each link
  ip_nw = "10.#{network_cnt / 256}.#{network_cnt % 256}"
  network_cnt += 1

  f_ip = Ip.create(address: "#{ip_nw}.1", netmask: "255.255.255.0", ip_type: "ipv4")
  f_name = "#{from.name}:if#{from.interfaces.length}"
  from.interfaces << f_if = Interface.create(name: f_name, ip: f_ip)

  t_ip = Ip.create(address: "#{ip_nw}.2", netmask: "255.255.255.0", ip_type: "ipv4")
  t_name = "#{to.name}:if#{to.interfaces.length}"
  to.interfaces << t_if = Interface.create(name: t_name, ip: t_ip)

  link.interfaces << f_if << t_if
  link.capacity = opts[:bw]
  #link.latency = opts[:delay]
  link
end

# Write RSPEC to stdout
parser.parse_file(file_name)
puts parser.to_rspec
