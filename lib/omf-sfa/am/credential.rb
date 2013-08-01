require 'nokogiri'
require 'omf_base/lobject'

module OMF::SFA::AM
  class Credential < OMF::Common::LObject


    @config = OMF::Common::YAML.load('omf-sfa-am', :path => [File.dirname(__FILE__) + '/../../../etc/omf-sfa'])[:omf_sfa_am]

    rpc = @config[:endpoints].select { |v| v[:type] == 'xmlrpc' }.first
    trusted_roots = File.expand_path(rpc[:trusted_roots])
    certs = Dir.entries(trusted_roots)
    certs.delete("..")
    certs.delete(".")
    @@root_certs = certs.collect do |v|
      v = File.join(trusted_roots, v)
    end

    @@xmlsec = 'xmlsec1'
   
    # <?xml version="1.0"?>
    # <signed-credential>
      # <credential xml:id="ref0">
        # <type>privilege</type>
        # <serial>8</serial>
        # <owner_gid>-----BEGIN CERTIFICATE-----...-----END CERTIFICATE-----</owner_gid>
        # <owner_urn>urn:publicid:IDN+geni:gpo:gcf+user+alice</owner_urn>
        # <target_gid>-----BEGIN CERTIFICATE-----...-----END CERTIFICATE-----</target_gid>
        # <target_urn>urn:publicid:IDN+geni:gpo:gcf+slice+2c93-4a3:127.0.0.1%3A8000</target_urn>
        # <uuid/>
        # <expires>2012-02-01T03:03:33</expires>
        # <privileges>
          # <privilege><name>refresh</name><can_delegate>true</can_delegate></privilege>
          # <privilege><name>embed</name><can_delegate>true</can_delegate></privilege>
          # <privilege><name>bind</name><can_delegate>true</can_delegate></privilege>
          # <privilege><name>control</name><can_delegate>true</can_delegate></privilege>
          # <privilege><name>info</name><can_delegate>true</can_delegate></privilege>
        # </privileges>
      # </credential>
      # <signatures>
        # <Signature xmlns="http://www.w3.org/2000/09/xmldsig#" xml:id="Sig_ref0">
          # ...
        # </Signature>
      # </signatures>
    # </signed-credential>

    def self.unmarshall(xml_text)
      signer_urn = verify_signed_xml(xml_text)
      cred = Nokogiri::XML.parse(xml_text)
      unless cred.root.name == 'signed-credential'
        raise "Expected 'signed-credential' but got '#{cred.root}'"
      end
      #puts @doc.to_xml
      unless (type_el =  cred.xpath('//credential/type')[0])
        raise "Credential doesn't contain 'type' element"
      end
      self.verify_type(type_el.content)
      
      #<owner_urn>urn:publicid:IDN+geni:gpo:gcf+user+alice</owner_urn>
      self.new(cred, signer_urn)
    end
    
    # The xml _content_ (provided as string) should
    # contain a _Signature_ tag. 
    #
    # Returns urn of signer if signature is valid,  otherwise throw an exception
    #
    def self.verify_signed_xml(content)
      tf = nil
      begin
        #debug "Verifying: ", content
        tf = Tempfile.open('omf-am-rpc')
        tf << content
        tf.close
        trusted_pems = @@root_certs.map do |r|
          "--trusted-pem #{r}"
        end.join(' ')
        cmd = "#{@@xmlsec} verify --enabled-key-data 'x509' #{trusted_pems} --print-xml-debug #{tf.path} 2> /dev/null"
        #cmd = "#{@@xmlsec} verify --trusted-pem #{@@root_certs} --print-xml-debug #{tf.path} 2> /dev/null"
        out = []
        result = nil
        IO.popen(cmd) do |so| 
          result = Nokogiri::XML.parse(so)
          #debug result
        end 
        unless (result.xpath('/VerificationContext')[0]['status'] == 'succeeded')
          raise OMF::SFA::AM::InsufficientPrivilegesException.new("Error: Signature doesn't verify")#\n#{@signature.to_xml}"
        end
          # <Certificate>
          #   <SubjectName>/CN=geni//gpo//gcf.authority.sa</SubjectName>
          #   <IssuerName>/CN=geni//gpo//gcf.authority.sa</IssuerName>
          #   <SerialNumber>3</SerialNumber>
          # </Certificate>        
        signer = result.xpath('//Certificate/SubjectName')[0].content
        debug "Signer of cert is '#{signer}'"
        return signer
      ensure
        tf.close! if tf
      end
    end
    
    def self.verify_type(type)
      raise "Implement 'verify_type' in '#{self}'"
    end


    attr_reader :owner_urn
    attr_reader :target_urn    
    attr_reader :signer_urn 
    attr_reader :valid_until

    def valid_at?(time = Time.now)
      #debug ">>>> #{valid_until}"
      time <= @valid_until     
    end

    protected
    
    # Create a credential described in +description_doc+
    #
    def initialize(description_doc, signer_urn)
      unless el = description_doc.xpath('//credential/owner_urn')[0]
        raise "Missing element 'owner_urn' in credential"
      end
      #URI:urn:publicid:IDN+topdomain:subdomain+user+pi
      #@owner_urn = el.content[el.content.index('+')+1..el.content.length]
      @owner_urn = el.content
      unless el = description_doc.xpath('//credential/target_urn')[0]
        raise "Missing element 'target_urn' in credential"
      end
      #URI:urn:publicid:IDN+topdomain:subdomain+slice+test
      #@target_urn = el.content[el.content.index('+')+1..el.content.length]
      @target_urn = el.content

      unless el = description_doc.xpath('//credential/expires')[0]
        raise "Missing element 'expires' in credential"
      end
      @valid_until = Time.parse(el.content)
      
      @signer_urn = signer_urn
    end

    
  end # Credential                     
end # OMF::GENI::AM
