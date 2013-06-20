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

Also make sure you define the correct paths of the credentials in "etc/omf-sfa/omf-sfa-am.yaml"

Starting a Test AM
------------------

To start an AM with a some pre-populated resources ('--test-load-am') from this directory, run the following:

    % cd $OMF_SFA_HOME
    % bundle exec ruby -I lib lib/omf-sfa/am/am_server.rb --dm-db sqlite:/tmp/test.sq3 --dm-auto-upgrade --test-load-am start

which should result into something like:

    DEBUG AMServer: options: {:app_name=>"am_server", :chdir=>"/Users/max/src/omf_sfa", :environment=>"development", :address=>"0.0.0.0", :port=>8001, :timeout=>30, :log=>"/tmp/am_server_thin.log", :pid=>"/tmp/am_server.pid", :max_conns=>1024, :max_persistent_conns=>512, :require=>[], :wait=>30, :rackup=>"/Users/max/src/omf_sfa/lib/omf-sfa/am/config.ru", :static_dirs=>["./resources", "/Users/max/src/omf_sfa/lib/omf_common/thin/../../../share/htdocs"], :static_dirs_pre=>["./resources", "/Users/max/src/omf_sfa/lib/omf_common/thin/../../../share/htdocs"], :handlers=>{:pre_rackup=>#<Proc:0x007fd254b979a8@/Users/max/src/omf_sfa/lib/omf-sfa/am/am_server.rb:116 (lambda)>, :pre_parse=>#<Proc:0x007fd254b97980@/Users/max/src/omf_sfa/lib/omf-sfa/am/am_server.rb:118 (lambda)>, :pre_run=>#<Proc:0x007fd254b97958@/Users/max/src/omf_sfa/lib/omf-sfa/am/am_server.rb:127 (lambda)>}, :dm_db=>"sqlite:/tmp/test.sq3", :dm_log=>"/tmp/am_server-dm.log", :load_test_am=>true, :dm_auto_upgrade=>true, :ssl=>true, :ssl_key_file=>"/Users/max/.gcf/am-key.pem", :ssl_cert_file=>"/Users/max/.gcf/am-cert.pem", :ssl_verify=>true}
    INFO Server: >> Thin web server (v1.3.1 codename Triple Espresso)
    DEBUG Server: >> Debugging ON
    DEBUG Server: >> Tracing ON
    INFO Server: >> Maximum connections set to 1024
    INFO Server: >> Listening on 0.0.0.0:8001, CTRL+C to stop

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

To list information about a specific resource 'node1', use the following:

    $ curl -k https://localhost:8001/resources/node1
    {
      "resource_response": {
        "resource": {
          "uuid": "ddb2170e-e4aa-45c8-bb63-242134e98a11",
          "href": "/resources/ddb2170e-e4aa-45c8-bb63-242134e98a11",
          "name": "node1",
          "type": "node",
          "available": true,
          "interfaces": [
            {
              "uuid": "fd527e07-7a9a-45dd-b6f3-dcc2abeb6e75",
              "href": "/resources/fd527e07-7a9a-45dd-b6f3-dcc2abeb6e75",
              "name": "node1:if0",
              "type": "interface"
            }
          ],
          "domain": "mytestbed.net",
          "status": "unknown"
        },
        "about": "/resources/node1"
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

Then run the AM acceptance tests. Follow the instructions in gcf's Readme files to make sure you have set up 'omni' correctly and then run the tests. Don't forger to set your enviroment variable before running the acceptance tests. You should also copy the "requests" found under "$OMF_HOME/omf_sfa/test/sfa_requests/"
    
    export PYTHONPATH=$PYTHONPATH:$GCF/src

    python am_api_accept.py -a https://0.0.0.0:8001/RPC2
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
