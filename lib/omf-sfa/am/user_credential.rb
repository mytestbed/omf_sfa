
require 'omf-sfa/am/credential'

module OMF::SFA::AM
  class UserCredential < OMF::Common::LObject

    include OMF::SFA::Resource

    attr_reader :user_urn, :user_uuid

    def self.unmarshall(cert_s)
      cert = OpenSSL::X509::Certificate.new(cert_s)
      #puts cert
      unless OpenSSL::SSL::SSLContext::DEFAULT_CERT_STORE.verify(cert)
        raise OMF::SFA::AM::InsufficientPrivilegesException.new("Non valid user cert")
      end
      self.new(cert)
    end

    def initialize(cert)
      @cert = cert

      @cert.extensions.each do |e|
        if e.oid == 'subjectAltName'
          #URI:urn:publicid:IDN+topdomain:subdomain+user+pi, URI:urn:uuid:759ae077-2fda-4d02-8921-ab0235a09920
          e.value.split(',').each do |u|
            u.slice!('URI:')
            @user_urn = u.strip if u.start_with?('urn:publicid:IDN')
            @user_uuid = u.match(/^urn:uuid:(.*)/)[1] if u.start_with?('urn:uuid')
          end
          #e.value.split('URI:urn:').each do |u|
          #  str = u.split('+')
          #  if str.include?('publicid:IDN')
          #    @user_urn = str[-3..-1].join('+').chomp(', ')
          #  end
          #  str = u.split(':')
          #  if str.include?('uuid')
          #    @user_uuid = str.last
          #  end
          #end
        end
      end
    end

    def subject 
      @cert.subject
    end

    def valid_at?(time = Time.now)
      debug "valid?  #{@cert.not_before} < #{time} < #{@cert.not_after}"
      time >= @cert.not_before && time <= @cert.not_after      
    end

  end # UserCredential
end # OMF::SFA::AM

