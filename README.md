This directory contains the implementations of various SFA APIs and services.

Aggregate Manager
=================

Installation
------------

At this stage the best course of action is to clone the repository

    % git clone https://github.com/mytestbed/omf_sfa.git
    % cd omf_sfa
    % export OMF_SFA_HOME=`pwd`
    % bundle install
    
Starting a Test AM
------------------

To start an AM with a some pre-populated resources ('--test-load-am') from this directory, run the following:

    % cd $OMF_SFA_HOME
    % ruby -I lib lib/omf-sfa/am/am_server.rb --dm-db sqlite:/tmp/test.sq3 --dm-auto-upgrade --test-load-am start
    
which should result into something like:

    DEBUG AMServer: options: {:app_name=>"am_server", :chdir=>"/Users/max/src/omf_sfa", :environment=>"development", :address=>"0.0.0.0", :port=>8001, :timeout=>30, :log=>"/tmp/am_server_thin.log", :pid=>"/tmp/am_server.pid", :max_conns=>1024, :max_persistent_conns=>512, :require=>[], :wait=>30, :rackup=>"/Users/max/src/omf_sfa/lib/omf-sfa/am/config.ru", :static_dirs=>["./resources", "/Users/max/src/omf_sfa/lib/omf_common/thin/../../../share/htdocs"], :static_dirs_pre=>["./resources", "/Users/max/src/omf_sfa/lib/omf_common/thin/../../../share/htdocs"], :handlers=>{:pre_rackup=>#<Proc:0x007fd254b979a8@/Users/max/src/omf_sfa/lib/omf-sfa/am/am_server.rb:116 (lambda)>, :pre_parse=>#<Proc:0x007fd254b97980@/Users/max/src/omf_sfa/lib/omf-sfa/am/am_server.rb:118 (lambda)>, :pre_run=>#<Proc:0x007fd254b97958@/Users/max/src/omf_sfa/lib/omf-sfa/am/am_server.rb:127 (lambda)>}, :dm_db=>"sqlite:/tmp/test.sq3", :dm_log=>"/tmp/am_server-dm.log", :load_test_am=>true, :dm_auto_upgrade=>true, :ssl=>true, :ssl_key_file=>"/Users/max/.gcf/am-key.pem", :ssl_cert_file=>"/Users/max/.gcf/am-cert.pem", :ssl_verify=>true}
    INFO Server: >> Thin web server (v1.3.1 codename Triple Espresso)
    DEBUG Server: >> Debugging ON
    DEBUG Server: >> Tracing ON
    INFO Server: >> Maximum connections set to 1024
    INFO Server: >> Listening on 0.0.0.0:8001, CTRL+C to stop
    
Depending on your environment you may see some warning messages like the following one which you can safely ignore at this point

    WARN AMServer: Can't find trusted root cert '~/.sfi/topdomain.subdomain.authority.cred'
    WARN AMServer: Can't find trusted root cert '/etc/sfa/trusted_roots/topdomain.gid'

Testing REST API
----------------

The easiest way to interact with the AM is through it's REST API. Start with listing all resources:

    $ curl -k https://localhost:8001/resources
    {
      "resource_response": {
        "resources": [
          {
            "uuid": "c76a1862-d9ff-40d3-bb7d-3e480624864f",
            "href": "/resources/c76a1862-d9ff-40d3-bb7d-3e480624864f",
            "name": "l",
            "type": "link",
      ...
    
Please note the -k (or --insecure) option as we are using SSL but the server by default is not using a
cert signed by a public CA.

To list information about a specific resource 'n1', use the following:

    $ curl -k https://localhost:8001/resources/n1
    {
      "resource_response": {
        "resource": {
          "uuid": "ddb2170e-e4aa-45c8-bb63-242134e98a11",
          "href": "/resources/ddb2170e-e4aa-45c8-bb63-242134e98a11",
          "name": "n1",
          "type": "node",
          "available": true,
          "interfaces": [
            {
              "uuid": "fd527e07-7a9a-45dd-b6f3-dcc2abeb6e75",
              "href": "/resources/fd527e07-7a9a-45dd-b6f3-dcc2abeb6e75",
              "name": "n1:if0",
              "type": "interface"
            }
          ],
          "domain": "mytestbed.net",
          "status": "unknown"
        },
        "about": "/resources/n1"
      }
    }

Listing all slices can be achieved through:

    $ curl -k https://localhost:8001/slices
    {
      "accounts_response": {
        "about": "/slices",
        "accounts": [
          {
            "name": "foo",
            "urn": "urn:publicid:IDN+mytestbed.net+foo",
            "uuid": "97019720-601a-4a08-9888-a17d32e2105d",
            "href": "/slices/97019720-601a-4a08-9888-a17d32e2105d"
          }
        ]
      }
    }
    
Ignore the references to 'accounts'. The resource model in OMF has no notion of 'slice', but it's 'account' 
is the most closest.

Like with resources, getting more information on a slice maps into:

    $ curl -k https://localhost:8001/slices/foo
    {
      "account_response": {
        "about": "/slices/97019720-601a-4a08-9888-a17d32e2105d",
        "type": "account",
        "properties": {
          "expires_at": "Tue, 04 Jun 2013 09:33:44 +1000"
        },
        "resources": {
          "href": "/slices/97019720-601a-4a08-9888-a17d32e2105d/resources"
        },
        "policies": {
          "href": "/slices/97019720-601a-4a08-9888-a17d32e2105d/policies"
        },
        "assertion": {
          "href": "/slices/97019720-601a-4a08-9888-a17d32e2105d/assertion"
        }
      }
    }
    
Please note that resources can reliably be referred to by their 'uuid', but using their 'name' will work 
in most cases as long as the name is unique in the particular context.

Testing with GCF
----------------

To test the AM, you can use the GPO's GCF. However, please be aware that 'gcf-test' is not really meant to be a 
validation test for AMs and is not always kept up-to-date with evolving APIs. In other words, a failing 'gcf-test'
may not necessarily mean the the AM implementation is wrong.

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

    $ python src/omni.py -a https://0.0.0.0:8001 -q createsliver test1 $OMF_SFA_HOME/test/req-sfa.xml
    ...
    INFO:omni:Asked https://0.0.0.0:8001 to reserve resources. Result:
    INFO:omni:<?xml version="1.0" ?>
    INFO:omni:<!-- Reserved resources for:
            Slice: test1
            At AM:
            URL: https://0.0.0.0:8001
     -->
    INFO:omni:<rspec expires="2012-04-30T11:54:39-03:00" generated="2012-04-30T11:44:39-03:00" type="advertisement" xmlns="http://www.protogeni.net/resources/rspec/2" xmlns:omf="http://schema.mytestbed.net/sfa/rspec/1">  
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
