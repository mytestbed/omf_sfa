
require 'json'
require 'omf_base'
require 'omf-sfa/resource'
include OMF::SFA::Resource


module OMF::SFA::Util

  class GraphJSONException < Exception

  end


  # This class handles the conversion between GraphJson
  # and a set of resources.
  #
  # Usage:
  #   GraphJson.parse_file(file_name) => Array of OResources
  #
  class GraphJSON < OMF::Base::LObject

    def self.parse_file(file_name, opts = {})
      content = File.open(file_name).read()
      self.new.parse(JSON.parse(content, symbolize_names: true), opts)
    end

    # Parse a hash following the GraphJSON format and return a
    # list od resources.
    #
    # * opts
    #   - :node_services Services to add to each node (default: [])
    #   - :create_new_uuids Don't use '_id' for UUID, create new ones
    #
    def self.parse(descr_hash, opts = {})
      self.new.parse(descr_hash, opts)
    end

    # Parse a hash following the GraphJSON format and return a
    # list od resources.
    #
    # * opts
    #   - :node_services Services to add to each node (default: [])
    #   - :create_new_uuids Don't use '_id' for UUID, create new ones
    #
    def parse(descr_hash, opts = {})
      @create_new_uuids = (opts[:create_new_uuids] == true)
      unless graph = descr_hash[:graph]
        raise GraphJSONException.new "Expected description 'graph' element at root - #{descr_hash}"
      end
      [:nodes, :edges].each do |type|
        unless graph[type]
          raise GraphJSONException.new "Missing '#{type}' declaration"
        end
        graph[type].each do |e|
          unless id = e[:_id]
            raise GraphJSONException.new "Missing '_id' for #{type} - #{e}"
          end
          if @id2descr.key? id
            raise GraphJSONException.new "Duplicated id '#{id}' detected - #{e}"
          end
          @id2descr[id] = e
        end
      end
      parse_defaults(graph, opts)
      parse_nodes(graph[:nodes], opts)
      parse_edges(graph, opts)
      #puts ">>>>> #{@resources}"
      @resources
    end

    def initialize()
      @id2descr = {}
      @resources = {}
      @sliver_types = {}
    end

    def parse_defaults(graph, opts)
      @defaults = {node: {}, interface: {}, network: {}}
      (graph[:defaults] || {}).each do |type, h|
        type_def = @defaults[type.to_sym] ||= {}
        h.each do |name, id|
          unless ref = @id2descr[id]
            raise GraphJSONException.new "Defaults refer to unknown id '#{id}'"
          end
          unless val = ref[name]
            raise GraphJSONException.new "Defaults refer to unspecified property '#{name}' in '#{id}' - #{ref}"
          end
          type_def[name] = val
          #puts "#{type}::#{name} ===> #{val}"
        end
      end
    end

    def parse_nodes(nodes, opts)
      nodes.each do |n|
        unless type = n[:_type]
          raise GraphJSONException.new "Missing '_type' declaration - #{n}"
        end
        case type
        when 'node'
          parse_node(n, opts)
        when 'network'
          parse_network(n, opts)
        else
          raise GraphJSONException.new "Unknown node type '#{type}' - #{n}"
        end
      end
    end

    def parse_node(node, gopts)
      el_defaults = @defaults[:node]
      opts = {}
      unless id = node[:_id]
        raise GraphJSONException.new "Missing node ID '_id' - #{node}"
      end
      opts[:uuid] = id unless @create_new_uuids
      opts[:name] = node[:name]
      parse_value(node, :component_manager, el_defaults, opts, false)
      parse_value(node, :urn, el_defaults, opts, false)
      opts[:sliver_type] = parse_sliver_type(node, el_defaults)

      @resources[id] = node_r = Node.create(opts)
      (gopts[:node_services] || []).each do |s|
        node_r.services << s
      end
      node_r
    end

    def parse_network(network, opts)
      el_defaults = @defaults[:network]
      # add defaults
      parse_value(network, :netmask, el_defaults, network, false)
      parse_value(network, :type, el_defaults, network, false)
    end

    def parse_edges(graph, gopts)
      # First collect interfaces into node declaration
      graph[:edges].each do |e|
        [[:_source, :tail, :_target], [:_target, :head, :_source]].each do |n_id, if_id, opp_id|
          n_descr = @id2descr[e[n_id]]
          next unless n_descr[:_type] == "node"
          if_a = (n_descr[:__ifs] ||= [])
          if_a << (if_descr = e[if_id] || {})
          opp_descr = @id2descr[e[opp_id]]
          if  opp_descr[:_type] == "network"
            if_descr[:__nw] = opp_descr
            (opp_descr[:__ifs] ||= []) << if_descr
          end
          (e[:__ifs] ||= []) << if_descr
        end
      end

      #
      graph[:nodes].each do |n_descr|
        next unless n_descr[:_type] == "node"
        node_id = n_descr[:_id]
        if_a = n_descr[:__ifs]
        next unless if_a

        # Add names to all interfaces
        names = if_a.map {|ifd| ifd[:name] }.compact
        i = 0
        if_a.each do |ifs|
          next if ifs[:name] # ok, has one already
          begin
            name = "if#{i}"
            i += 1
          end while names.include?(name)
          ifs[:name] = name
        end

        # Create interface resource
        node_r = @resources[node_id]
        if_a.each do |ifs|

          opts = { name: (ifs[:__client_id] = "#{node_r.name}:#{ifs[:name]}") }
          if ip_decl = ifs[:ip]
            if ip_decl.key? :type
              ip_decl[:ip_type] = ip_decl.delete(:type)
            end
            #puts "IP>>> #{ip_decl}"
            opts[:ip] = Ip.create(ip_decl)
          else

            # TODO: Maybe create IP address if the other end is a network
            if nw = ifs[:__nw]
              idx = nw[:__ifs].index do |oifs|
                ifs[:__client_id] == oifs[:__client_id]
              end
              #puts "\n#{idx}\n"
            end
          end
          if_r = ifs[:__if_r] = Interface.create(opts)
          node_r.interfaces << if_r
        end

      end

      # Create Link resources
      graph[:edges].each do |e|
        source = @id2descr[e[:_source]]
        target = @id2descr[e[:_target]]
        unless source && target
          raise GraphJSONException.new "Can't find source or target node - #{e}"
        end
        if source[:_type] == 'node' && target[:_type] == 'node'
          # direct link
          opts = {}
          unless id = e[:_id]
            raise GraphJSONException.new "Missing edge ID '_id' - #{e}"
          end
          opts[:uuid] = id unless @create_new_uuids
          opts[:name] = e[:name] #|| id
          link_r = Link.create(opts)
          @resources[id] = link_r
        elsif source[:_type] == 'network' && target[:_type] == 'network'
          raise GraphJSONException.new "Can't connect two networks directly - #{e}"
        else
          # one side is a network
          network = source[:_type] == 'network' ? source : target
          unless link_r = @resources[nw_id = network[:_id]]
            opts = {name: network[:name]}
            opts[:uuid] = nw_id unless @create_new_uuids
            link_r = Link.create(opts)
            @resources[nw_id] = link_r
          end
        end
        if link_r
          link_r.link_type = e[:link_type] || "lan"
          e[:__ifs].each do |ifs|
            link_r.interfaces << ifs[:__if_r]
          end
        end

      end
    end

    def parse_sliver_type(node, el_defaults)
      sliver_type = parse_value(node, :sliver_type, el_defaults, nil, true)
      disk_image_url = parse_value(node, :disk_image, el_defaults, nil, true)
      id = "#{sliver_type}-#{disk_image_url}"
      unless st_res = @sliver_types[id]
        di = DiskImage.create(url: disk_image_url)
        st_res = @sliver_types[id] = SliverType.create(name: sliver_type, disk_image: di)
      end
      st_res
    end


    def parse_value(el, name, defaults, opts, is_mandatory = false)
      val = el[name] || defaults[name]
      if is_mandatory && val.nil?
        raise GraphJSONException.new "Can't find value for mandatory property '#{name}' in '#{el}'"
      end
      if opts && !val.nil?
        opts[name.to_sym] = val
      end
      val
    end

  end

end

if $0 == __FILE__

  OMF::Base::Loggable.init_log 'graph_json'

  GURN.default_domain = "urn:publicid:IDN+acme.org"
  OMF::SFA::Resource::OResource.init()

  file = ARGV[0] || File.join(File.dirname(__FILE__), '/../../../examples/four_node_one_network.gjson')
  begin
    opts = {
      node_services: [
        InstallService.create(install_path: "/local", url: "http://emmy9.casa.umass.edu/InstaGENI_Images/install-script.tar.gz"),
        ExecuteService.create(command: "sudo sh /local/postboot_script.sh", shell: "sh")
      ],
      create_new_uuids: false
    }
    resources = OMF::SFA::Util::GraphJSON.parse_file(file, opts)
    #puts resources
    rspec = OComponent.to_rspec(resources.values, :request, suppress_id: true)
    puts rspec
  rescue OMF::SFA::Util::GraphJSONException => ex
    puts "ERROR: #{ex}"
  end
end
