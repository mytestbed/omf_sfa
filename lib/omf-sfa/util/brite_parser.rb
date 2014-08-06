#
# Load topology from BRITE file
#

require 'omf_sfa'

# BRITE format
#
# Topology: ( [numNodes] Nodes, [numEdges] Edges )
# Model ( [ModelNum] ):  [Model.toString()]
#
# Nodes: ([numNodes]):
# [NodeID]  [x-coord]  [y-coord]  [inDegree] [outDegree] [ASid]  [type]
# [NodeID]  [x-coord]  [y-coord]  [inDegree] [outDegree] [ASid]  [type]
# [NodeID]  [x-coord]  [y-coord]  [inDegree] [outDegree] [ASid]  [type]
# ...
#
# Edges: ([numEdges]):
# [EdgeID]  [fromNodeID]  [toNodeID]  [Length]  [Delay]  [Bandwidth]  [ASFromNodeID]  [ASToNodeID]  [EdgeType]  [Direction]
# [EdgeID]  [fromNodeID]  [toNodeID]  [Length]  [Delay]  [Bandwidth]  [ASFromNodeID]  [ASToNodeID]  [EdgeType]  [Direction]
# [EdgeID]  [fromNodeID]  [toNodeID]  [Length]  [Delay]  [Bandwidth]  [ASFromNodeID]  [ASToNodeID]  [EdgeType]  [Direction]
#
module OMF::SFA::Util
  class BriteParser < OMF::Base::LObject

    def initialize()
      @nodes = {}
      @edges = []
      #@sliver = OMF::SFA::Resource::Sliver.def_sliver

    end

    def on_new_node(&block)
      @on_new_node = block
    end

    def on_new_edge(&block)
      @on_new_edge = block
    end

    def create_node(opts)
      node = @on_new_node.call(opts)
      @nodes[opts[:id]] = node if node
    end

    def create_edge(opts)
      from = @nodes[opts[:from]]
      to = @nodes[opts[:to]]
      edge = @on_new_edge.call(opts, from, to)
      @edges << edge if edge
    end

    def to_rspec()
      OComponent.to_rspec(@nodes.values() + @edges, :request, suppress_id: true)
    end

    def parse_file(file_name)
      f = File.open(File.absolute_path(file_name))
      sp = [
        lambda {|l, i| _parse_header(l, i)},
        lambda {|l, i| _parse_nodes(l, i)},
        lambda {|l, i| _parse_edges(l, i)},
      ]
      p = sp.shift
      i = 0
      f.each do |l|
        if l.strip!.empty?
          next if i == 0 # skip multiple consectutive empty lines
          p = sp.shift
          i = 0
          next
        end
        p.call(l, i)
        i += 1
      end
    end

    def _parse_header(l, i)
      case l
      when /^Topology/
        # ignore Topology: ( 111 Nodes, 111 Edges )
      when /^Model/
        unless m = l.match(/Model\W*([\d]*)\W*:*(.*)/)
          fatal "Missing 'Model' declaration in header"
          exit -1
        end
        @model_type = m[1]
        @model_opts = m[2]
      else
        warn "Ignoring unexpected header line - #{l}"
      end
    end

    def _parse_nodes(l, i)
      return if i == 0

      unless m = l.match(/([\d]+)\s+([\d\.]+)\s+([\d\.]+)\s+([\d]+)\s+([\d]+)\s+([\d\-]+)\s+(.*)/)
        fatal "Can't parse node declaration - #{l}"
        exit -1
      end
      if (pa = m.to_a[1 .. -1]).length != 7
        fatal "Expected 7 parameters in node declaration, but got '#{pa.length}' - #{l}"
        exit -1
      end
      # [NodeID]  [x-coord]  [y-coord]  [inDegree] [outDegree] [ASid]  [type]
      n = {}
      [[:id, :i], [:x, :f], [:y, :f], nil, nil, nil, [:type]].each_with_index do |k, i|
        next if k.nil?

        v = pa[i]
        case k[1]
        when :i
          v = v.to_i
        when :f
          v = v.to_f
        else
          v.strip!
        end
        #puts "name: #{name} i: #{i}"
        n[k[0]] = v
      end
      create_node(n)
      #puts "NODES - #{n}"
    end

    def _parse_edges(l, i)
      return if i == 0
      unless m = l.match(/([\d]+)\s+([\d]+)\s+([\d]+)\s+([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)\s+([\d\-]+)\s+([\d\-]+)\s+([^\s]+)\s+([^\s]+)/)
        fatal "Can't parse edge declaration - #{l}"
        exit -1
      end
      if (pa = m.to_a[1 .. -1]).length != 10
        fatal "Expected 10 parameters in edge declaration, but got '#{pa.length}' - #{pa}"
        exit -1
      end
      # [EdgeID]  [fromNodeID]  [toNodeID]  [Length]  [Delay]  [Bandwidth]  [ASFromNodeID]  [ASToNodeID]  [EdgeType]  [Direction]
      e = {}
      [[:id, :i], [:from, :i], [:to, :i], [:length, :f], [:delay, :f], [:bw, :f], nil, nil, [:type], [:direction]].each_with_index do |k, i|
        next if k.nil?

        v = pa[i]
        case k[1]
        when :i
          v = v.to_i
        when :f
          v = v.to_f
        else
          v.strip!
        end
        #puts "name: #{name} i: #{i}"
        e[k[0]] = v
      end
      create_edge(e)
      #@edges << e
      #puts "EDGES - #{e}"
    end

  end
end

