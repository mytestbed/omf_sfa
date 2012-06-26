# CSS: /assets/css/default.css

Objective
=========

The AM essentially manipulates collections (slivers) of resoruces and their respective properties
under certain policies.

This document proposes a RESTful alternative to the existing XML-RPC based AM API. A short descripton
of REST can be found on [Wikipedia](http://en.wikipedia.org/wiki/Representational_state_transfer).

The current proposal does not yet address access control, but hints on how to achieve that are already present.

To get a better understanding of the strength and weaknesses of this API, an experimental implementation has been 
deployed at http://srv.mytestbed.net:4040 and the (rather messy) implementation is available on the 
[OMF Repository](http://omf.mytestbed.net/projects/omf/repository/revisions/sfa/show/omf-sfa/ruby/omf-sfa/am/am-rest).

* API
* Examples
* Mapping to XML-RPC API
* Footnotes

API
===

* `/resources`
  * GET: List all resources
  * PUT: Not allowed
  * POST: Not allowed
  * DELETE: Not allowed

* `/slivers`
  * GET: List all sliver
  * PUT: Not allowed
  * POST: Not allowed
  * DELETE: Not allowed

* `/slivers/_sliver_id_`
  * GET: Status of sliver 
  * PUT(rspec): Create sliver if not already exist. Apply body to all sub collection
  * POST(rspec): Modify all sub collections according to +rspec+.
  * DELETE: Delete sliver

* `/slivers._sliver_id_/resources`
  * GET: Status of all resources in sliver 
  * PUT(rspec): Replace all resources in sliver with those described in +rspec+
  * POST(rspec): Modify resources in collection. See (1), (2)
  * DELETE: Remove all resources from sliver

* `/slivers/_slice_id_/resources/_resource_id_`
  * GET: Status of resource
  * PUT(rspec): Fully reconfigure resource. Not mentioned properties are set to their default value
  * POST(rspec): Modify names resource properties
  * DELETE: Delete resource (remove from sliver)

* `/status` (optional)
  * GET: Status of AM

* `/version`
  * GET: Information about capabilites of AM implementation

Examples
========

List all resources
------------------

    $ curl http://srv.mytestbed.net:4040/resources
    <?xml version="1.0"?>
    <resources_response xmlns="http://schema.mytestbed.net/am_rest/0.1" generated="2011-11-27T23:14:58+00:00" about="/resources">
      <resources href="/slivers/__DEFAULT__/resources">
        <node id="c-611570898" component_id="urn:publicid:IDN+mytestbed.net+node+r1" component_manager_id="authority+am" component_name="r1" href="/resources/r1">
          <available now="true"/>
          <interface_ref component_id="urn:publicid:IDN+mytestbed.net+interface+interface4"/>
          <interface_ref component_id="urn:publicid:IDN+mytestbed.net+interface+interface6"/>
          <interface_ref component_id="urn:publicid:IDN+mytestbed.net+interface+interface13"/>
          <interface_ref component_id="urn:publicid:IDN+mytestbed.net+interface+interface16"/>
        </node>
       ...

List status of a single resource
--------------------------------

    $ curl http://srv.mytestbed.net:4040/resources/r1<?xml version="1.0"?>
    <resource_response xmlns="http://schema.mytestbed.net/am_rest/0.1" generated="2011-11-27T23:17:26+00:00" about="/resources/r1">
      <node id="c-610107898" component_id="urn:publicid:IDN+mytestbed.net+node+r1" component_manager_id="authority+am" component_name="r1" href="/resources/r1">
        <available now="true"/>
        <interface_ref component_id="urn:publicid:IDN+mytestbed.net+interface+interface4"/>
        <interface_ref component_id="urn:publicid:IDN+mytestbed.net+interface+interface6"/>
        <interface_ref component_id="urn:publicid:IDN+mytestbed.net+interface+interface13"/>
        <interface_ref component_id="urn:publicid:IDN+mytestbed.net+interface+interface16"/>
      </node>
    </resource_response>

List all slivers
----------------

    $ curl http://srv.mytestbed.net:4040/slivers
    <?xml version="1.0"?>
    <slivers_response xmlns="http://schema.mytestbed.net/am_rest/0.1" generated="2011-11-27T23:29:07+00:00" about="/slivers">
      <slivers href="/slivers"/>
    </slivers_response>

Create a sliver
---------------

    $ curl -X PUT -d @req1.xml http://srv.mytestbed.net:4040/slivers/foo
    <?xml version="1.0"?>
    <sliver_response xmlns="http://schema.mytestbed.net/am_rest/0.1" generated="2011-11-27T23:30:47+00:00" about="/slivers/foo">
      <sliver href="/foo">
        <resources href="/slivers/foo/resources"/>
        <properties>
          <expires_at>Sun, 27 Nov 2011 23:40:47 +0000</expires_at>
        </properties>
        <assertion/>
        <policies/>
      </sliver>
    </sliver_response>

Status of a sliver
------------------

    $ curl http://srv.mytestbed.net:4040/slivers/foo
    <?xml version="1.0"?>
    <sliver_response xmlns="http://schema.mytestbed.net/am_rest/0.1" generated="2011-11-27T23:18:35+00:00" about="/slivers/foo">
      <sliver href="/foo">
        <resources href="/slivers/foo/resources"/>
        <properties>
          <expires_at>Sun, 27 Nov 2011 23:28:35 +0000</expires_at>
        </properties>
        <assertion/>
        <policies/>
      </sliver>
    </sliver_response>

List all resources in a sliver
------------------------------

    $ curl http://srv.mytestbed.net:4040/slivers/foo/resources
    <?xml version="1.0"?>
    <resources_response xmlns="http://schema.mytestbed.net/am_rest/0.1" generated="2011-11-27T23:20:04+00:00" about="/slivers/foo/resources">
      <resources href="/slivers/foo/resources">
        <node id="c-610782628" component_id="urn:publicid:IDN+mytestbed.net+node+r0" component_manager_id="authority+am" component_name="r0" href="/slices/foo/resources/r0">
          <available now="true"/>
          <interface_ref component_id="urn:publicid:IDN+mytestbed.net+interface+interface0"/>
          <interface_ref component_id="urn:publicid:IDN+mytestbed.net+interface+interface2"/>
          <interface_ref component_id="urn:publicid:IDN+mytestbed.net+interface+interface12"/>
          <interface_ref component_id="urn:publicid:IDN+mytestbed.net+interface+interface14"/>
        </node>
        <node id="c-610782828" component_id="urn:publicid:IDN+mytestbed.net+node+c0_0" component_manager_id="authority+am" component_name="c0_0" href="/slices/foo/resources/c0_0">
          <available now="true"/>
          <interface_ref component_id="urn:publicid:IDN+mytestbed.net+interface+interface1"/>
        </node>
        <link id="c-610790138" component_id="urn:publicid:IDN+mytestbed.net+link+la0_0" component_manager_id="authority+am" component_name="la0_0" href="/slices/foo/resources/la0_0">
          <interface_ref component_id="urn:publicid:IDN+mytestbed.net+interface+interface0"/>
          <interface_ref component_id="urn:publicid:IDN+mytestbed.net+interface+interface1"/>
        </link>
      </resources>
    </resources_response>

Modify resources in sliver
--------------------------

    $ cat req1.xml   (fetch from http://omf.mytestbed.net/projects/omf/repository/revisions/sfa/entry/omf-sfa/test/req1.xml)

    <resources xmlns="http://schema.mytestbed.net/am_rest/0.1">
      <node component_id="urn:publicid:IDN+mytestbed.net+node+r0">
        <interface_ref component_id="urn:publicid:IDN+mytestbed.net+interface+interface0"/>
        <interface_ref component_id="urn:publicid:IDN+mytestbed.net+interface+interface2"/>
      </node>
      <node component_id="urn:publicid:IDN+mytestbed.net+node+c0_0">
        <interface_ref component_id="urn:publicid:IDN+mytestbed.net+interface+interface1"/>
      </node>
      ... 

    $ curl -X PUT -d @req1.xml http://srv.mytestbed.net:4040/slivers/foo/resources
    <?xml version="1.0"?>
    <resources_response xmlns="http://schema.mytestbed.net/am_rest/0.1" generated="2011-11-27T23:21:42+00:00" about="/slivers/foo/resources">
      <resources href="/slivers/foo/resources">
        <node id="c-611144758" component_id="urn:publicid:IDN+mytestbed.net+node+r0" component_manager_id="authority+am" component_name="r0" href="/slices/foo/resources/r0">
          <available now="true"/>
          <interface_ref component_id="urn:publicid:IDN+mytestbed.net+interface+interface0"/>
          <interface_ref component_id="urn:publicid:IDN+mytestbed.net+interface+interface2"/>
          <interface_ref component_id="urn:publicid:IDN+mytestbed.net+interface+interface12"/>
          <interface_ref component_id="urn:publicid:IDN+mytestbed.net+interface+interface14"/>
        </node>
        <node id="c-611144958" component_id="urn:publicid:IDN+mytestbed.net+node+c0_0" component_manager_id="authority+am" component_name="c0_0" href="/slices/foo/resources/c0_0">
          <available now="true"/>
          <interface_ref component_id="urn:publicid:IDN+mytestbed.net+interface+interface1"/>
        </node>
        <node id="c-611145158" component_id="urn:publicid:IDN+mytestbed.net+node+c0_1" component_manager_id="authority+am" component_name="c0_1" href="/slices/foo/resources/c0_1">
          <available now="true"/>
          <interface_ref component_id="urn:publicid:IDN+mytestbed.net+interface+interface3"/>
        </node>
        .....

Delete individual resources
---------------------------

    $ curl -X DELETE http://srv.mytestbed.net:4040/slivers/foo/resources/r0
    <?xml version="1.0"?>
    <resource_response xmlns="http://schema.mytestbed.net/am_rest/0.1" generated="2011-11-27T23:27:27+00:00" about="/slivers/foo/resources/r0"/>


Delete Sliver
-------------

    $ curl -X DELETE http://srv.mytestbed.net:4040/slivers/foo
    <?xml version="1.0"?>
    <sliver_response xmlns="http://schema.mytestbed.net/am_rest/0.1" generated="2011-11-27T23:28:10+00:00" about="/slivers/foo"/>

Simply cool
-----------

<script type="text/javascript" src="http://mbostock.github.com/d3/d3.js?2.6.0s"></script>
<script type="text/javascript" src="http://mbostock.github.com/d3/d3.geom.js"></script>
<script type="text/javascript" src="http://mbostock.github.com/d3/d3.layout.js"></script>
<script type="text/javascript" src="http://documentcloud.github.com/underscore/underscore.js"></script>
    

<div id="chart"></div>
<script type="text/javascript" src="assets/network.js"></script>

Mapping to XML-RPC API
======================

GetVersion
----------

    GET /version

ListResources
-------------

    GET /resources
    GET /resources?compressed
    GET /resources?available

    GET /slivers/_sliver_id_/resources

CreateSliver
------------

    PUT /slivers/_sliver_id_

DeleteSliver
------------

    DELETE /slivers/_sliver_id_

SliverStatus
------------

    GET /slivers/_sliver_id_
    GET /slivers/_sliver_id_/resources

RenewSliver
-----------

Slivers have options (`/slivers/_sliver_id_/options`) and +expires_at+ maybe one of them which can be
manipulated through a PUT/POST operation. There is always the option to add a 'pseudo' property which
achieves the same with a simple call (e.g. `PUT /slivers/_sliver_id_/options/renew`).

Shutdown
--------

As this is adestructive command (there is no 'restart') we could simply delete the sliver.

    DELETE /slivers/_sliver_id_

An alternative is to have something like a +running+ option which can be set to false or, like
'RenewSliver' we could handle this through a 'pseudo' option (e.g. `PUT /slivers/_sliver_id_/options/shutdown`)


Footnotes:
==========

(1) Managing many resources in a sliver through a single call

    PUT /slices/_slice_id_
      <resources>
        <resource href="/slices/_slice_id_/resources/_resource_id_" op="_OP_">
          ... 
        </>
      </>

Conceptually every `<resource>` in the list results in 'redirect' to 

    _OP_ /slices/_slice_id_/resources/_resource_id_
      <resource>
          ... 
      </>

(2) Managing access control or policy properties of slivers and resources

There are two ways. One is to make it part of the PUT or POST body, the other
one is using Amazon's S3 example and using sub resources `?acl`, `?policy`.
The latter would more cleanly map onto `/slivers/_sliver_id_/(acls | policies)`



