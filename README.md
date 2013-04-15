This directory contains the implementations of various SFA APIs and services.

Aggregate Manager
=================

To start an AM from this directory, run the following:

    % cd $OMF_HOME/omf_sfa
    % bundle exec ruby -I lib lib/omf-sfa/am/am_server.rb --dm-db sqlite:/tmp/test.sq3 --dm-auto-upgrade --test-load-am --print-options start

Testing with GCF
----------------

To test the AM, you can use the GPO's GCF.

In a shell start the CF (make sure you installed the credentials in ~/.gcf):

    $ src/gcf-ch.py
    INFO:cred-verifier:Will accept credentials signed by any of 1 root certs found in ~/.gcf/trusted_roots: ['~/.gcf/trusted_roots/ch-cert.pem']
    INFO:gcf-ch:Registering AM urn:publicid:IDN+geni:gpo:gcf:am1+authority+am at http://localhost:8001
    INFO:cred-verifier:Adding trusted cert file ch-cert.pem
    INFO:cred-verifier:Combined dir of 1 trusted certs ~/.gcf/trusted_roots into file ~/.gcf/trusted_roots/CATedCACerts.pem for Python SSL support
    INFO:gcf-ch:GENI CH Listening on port 8000...

Then run the AM acceptance tests. Follow the instructions in Readme files to make sure you have set up 'omni' correctly and then run the tests 'python am_api_accept.py -a am-undertest'. Use the "requests" found under '$OMF_HOME/omf_sfa/test/sfa_requests/':

    python am_api_accept.py -a am-undertest                                           
    .............
    ----------------------------------------------------------------------
    Ran 13 tests in 959.389s

    OK

Using OMNI
==========

Create Sliver
-------------

    $ python src/omni.py -a https://0.0.0.0:8001 -q createsliver test1 $OMF_HOME/omf_sfa/test/sfa_requests/request.xml
    ...
    INFO:omni:Got return from CreateSliver for slice test1 at https://0.0.0.0:8001:
    INFO:omni:<?xml version="1.0"?>
    INFO:omni:  <!-- Reserved resources for:
            Slice: test1
            at AM:
            URN: unspecified_AM_URN
            URL: https://0.0.0.0:8001
     -->
    INFO:omni:  
    <rspec xmlns="http://www.geni.net/resources/rspec/3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:omf="http://nitlab.inf.uth.gr/schema/sfa/rspec/1" xsi:schemaLocation="http://www.geni.net/resources/rspec/3 http://www.geni.net/resources/rspec/3/manifest.xsd http://nitlab.inf.uth.gr/schema/sfa/rspec/1 http://nitlab.inf.uth.gr/schema/sfa/rspec/1/ad-reservation.xsd" type="manifest" generated="2013-04-12T19:46:05+03:00" expires="2013-04-12T19:56:05+03:00">
      <node client_id="node0" component_id="urn:publicid:IDN+omf:nitos+node+node0" component_manager_id="urn:publicid:IDN+omf:nitos+authority+am" component_name="node0" exclusive="true">
        <available now="true"/>
      </node>
    </rspec>

Sliver Status
-------------

    $ python src/omni.py -a https://0.0.0.0:8001 -q sliverstatus test1
    INFO:omni:Sliver status for Slice urn:publicid:IDN+geni:gpo:gcf+slice+test1 at AM URL https://0.0.0.0:8001
    INFO:omni:{
      "geni_urn": "urn:publicid:IDN+geni:gpo:gcf+slice+test1", 
      "geni_resources": [
        {
          "geni_urn": "urn:publicid:IDN+omf:nitos+node+node0", 
          "geni_error": "", 
          "geni_status": "unknown"
        }
      ], 
      "omf_expires_at": "20130412154532Z", 
      "geni_status": "unknown"
    }


Debugging hints
===============

Use the following command to show the content of a cert in a human readable form:

    $ openssl x509 -in ~/.gcf/alice-cert.pem -text

To verify certificates, use openssl to set up a simple SSL server as well as 
connect to it.

Server:

    % openssl s_server -cert ~/.gcf/am-cert.pem -key ~/.gcf/am-key.pem -verify on

Client:

    % openssl s_client -cert ~/.gcf/alice-cert.pem -key ~/.gcf/alice-key.pem
    % openssl s_client -connect 127.0.0.1:8001 -key ~/.gcf/alice-key.pem -cert ~/.gcf/alice-cert.pem -CAfile ~/.gcf/trusted_roots/CATedCACerts.pem
