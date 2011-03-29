require 'nokogiri'
require 'json'

if ARGV.size < 2
  puts "Takes two args, input file and output file"
  exit
end

f = File.open(ARGV[0]).read
doc = Nokogiri::XML(f)

n = doc.xpath('//node')

nodes = {}
n.each{|x| nodes[x.attributes['id'].value] = [x.attributes['lat'].value.to_f, x.attributes['lon'].value.to_f, []]}

w = doc.xpath('//way')

w.each do |x|
  tag = x.xpath('tag[@k="highway"]')
  if tag && tag[0]
    nds = x.xpath('nd')
    previous = nds[0].attributes['ref'].value
    nds[1..-1].each do |nd|
      node = nd.attributes['ref'].value
      nodes[node][2] << previous
      nodes[previous][2] << node
      previous = node
    end
  end
end

nodes.delete_if do |id,n|
  n[2].size == 0
end

File.open(ARGV[1], "w+") do |w|
  w.write nodes.to_json
end
