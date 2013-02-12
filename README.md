This directory contains the implementations of various SFA APIs and services.

Aggregate Manager
=================

To start a AM from this directory, run the following:

    % cd $OMF_HOME/omf-sfa
    % ruby -I lib/omf_common/ruby -I lib lib/omf-sfa/am/am_server.rb --dm-db sqlite:/tmp/test.sq3 --dm-auto-upgrade --test-load-am --print-options start

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

Then run the 'gcf-test' app in another shell

    $ python src/gcf-test.py --am https://0.0.0.0:8001/RPC2
    INFO:gcf-test:CH Server is https://127.0.0.1:8000/. Using keyfile ~/.gcf/alice-key.pem, certfile ~/.gcf/alice-cert.pem
    INFO:gcf-test:AM Server is https://0.0.0.0:8001/RPC2. Using keyfile ~/.gcf/alice-key.pem, certfile ~/.gcf/alice-cert.pem
    Slice Creation SUCCESS: URN = urn:publicid:IDN+geni:gpo:gcf+slice+34ac-b58:127.0.0.1%3A8000
    Testing GetVersion... passed
    Testing ListResources... passed
    Testing CreateSliver... passed

Using OMNI
==========

Create Sliver
-------------

    $ python src/omni.py -a https://0.0.0.0:8001 -q createsliver test1 $OMF_HOME/omf-sfa/test/req-sfa.xml
    ...
    INFO:omni:Asked https://0.0.0.0:8001 to reserve resources. Result:
    INFO:omni:<?xml version="1.0" ?>
    INFO:omni:<!-- Reserved resources for:
            Slice: test1
            At AM:
            URL: https://0.0.0.0:8001
     -->
    INFO:omni:<rspec expires="2012-04-30T11:54:39-03:00" generated="2012-04-30T11:44:39-03:00" type="advertisement" xmlns="http://www.protog
    eni.net/resources/rspec/2" xmlns:omf="http://schema.mytestbed.net/sfa/rspec/1">  
        <node component_id="urn:publicid:IDN+mytestbed.net+node+aea0b9a5-e90e-5fd6-9224-847f0a1b37cb" component_manager_id="authority+am" component_name="n0" id="aea0b9a5-e90e-5fd6-9224-847f0a1b37cb" omf:href="/resources/aea0b9a5-e90e-5fd6-9224-847f0a1b37cb">    
            <available now="true"/>    
        </node>  
    </rspec>

Sliver Status
-------------

    $ python src/omni.py -a https://0.0.0.0:8001 -q sliverstatus test1
    INFO:omni:Loading config file omni_config
    INFO:omni:Using control framework my_gcf
    WARNING:omni:Slice urn:publicid:IDN+geni:gpo:gcf+slice+test1 expires in <= 3 hours
    INFO:omni:Slice urn:publicid:IDN+geni:gpo:gcf+slice+test1 expires on 2012-04-30 14:58:08 UTC
    INFO:omni:Status of Slice urn:publicid:IDN+geni:gpo:gcf+slice+test1:
    INFO:omni:Sliver status for Slice urn:publicid:IDN+geni:gpo:gcf+slice+test1 at AM URL https://0.0.0.0:8001
    INFO:omni:{'geni_resources': [{'geni_status': 'unknown',
                         'geni_urn': 'urn:publicid:IDN+mytestbed.net+node+n0'}],
     'geni_status': 'unknown',
     'geni_urn': 'urn:publicid:IDN+geni:gpo:gcf+slice+test1'}
 
 


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
