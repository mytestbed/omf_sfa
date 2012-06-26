var w = 960,
    h = 500,
    fill = d3.scale.category20();

var vis = d3.select("#chart")
  .append("svg:svg")
    .attr("width", w)
    .attr("height", h);

d3.json("http://0.0.0.0:8001/resources?json", function(json) {
  var resources = json['resources_response']['resources']
  var i2n = {};
  var nodes = _.filter(resources, function(n) {
	if (n['sfa_class'] == "node") {
		 _.each(n['interfaces'], function(i) {
			 i2n[i['href']] = n;
		 });
		 return true;
	}
	return false;
  });
  
  var links = _.filter(resources, function(l) {
    if (l['sfa_class'] == "link") {
    	var src = l.interfaces[0].href;
    	var tgt = l.interfaces[1].href;
    	l.source = i2n[src];
    	l.target = i2n[tgt];
    	return l.source && l.target;
    } 
    return false;
  });
  
  var force = d3.layout.force()
      .charge(-1000)
      .distance(100)
      .nodes(nodes)
      .links(links)
      .size([w, h])
      .start();

  var link = vis.selectAll("line.link")
      .data(links)
    .enter().append("svg:line")
      .attr("class", "link")
      .attr("x1", function(d) { 
    	  return d.source.x; 
       })
      .attr("y1", function(d) { return d.source.y; })
      .attr("x2", function(d) { return d.target.x; })
      .attr("y2", function(d) { return d.target.y; });

  var node = vis.selectAll("circle.node")
      .data(nodes)
    .enter().append("svg:circle")
      .attr("class", "node")
      .attr("cx", function(d) { return d.x; })
      .attr("cy", function(d) { return d.y; })
      .attr("r", 20)
      .style("fill", function(d) { return fill(d.group); })
      .call(force.drag);

  node.append("svg:title")
      .text(function(d) { 
    	  return d.component_name; 
      });

  vis.style("opacity", 1e-6)
    .transition()
      .duration(1000)
      .style("opacity", 1);

  force.on("tick", function() {
    link.attr("x1", function(d) { return d.source.x; })
        .attr("y1", function(d) { return d.source.y; })
        .attr("x2", function(d) { return d.target.x; })
        .attr("y2", function(d) { return d.target.y; });

    node.attr("cx", function(d) { return d.x; })
        .attr("cy", function(d) { return d.y; });
  });
});
