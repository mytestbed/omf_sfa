

require 'omf-sfa/am/credential'

module OMF::SFA::AM
  class UserCredential < OMF::Common::MObject
    
    def self.unmarshall(cert_s)
      cert = OpenSSL::X509::Certificate.new(cert_s)
      unless OpenSSL::SSL::SSLContext::DEFAULT_CERT_STORE.verify(cert)
        raise "Non valid user cert"
      end
      self.new(cert)
    end
    
    def initialize(cert)
      @cert = cert
    end
    
    def get_user
      require 'omf-sfa/resource/user'
      User.first(:urn => user_urn())
    end

    def subject 
      @cert.subject
    end
    
    def user_urn
      unless @user_urn
        @cert.extensions.each do |e|
          if e.oid == 'subjectAltName'
            return @user_urn = e.value.split('URI:')[-1]
          end
        end
      end
      @user_urn      
    end
  end # UserCredential
end # OMF::SFA::AM
    