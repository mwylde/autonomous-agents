import json

class Node:
  def __init__(self, lat, long):
    self.pos = (lat, long)
    self.neighbors = set()
  
class Map:
  def __init__(self, map_json):
    graph = json.loads(map_json)
    nodes = {}
    for k,v in graph.iteritems():
      # create a new node with the lat/long coordinates from the map
      nodes[k] = Node(v[0], v[1])

    # now that all of the nodes have been created, we do a second pass
    # to get all of the references
    for k,v in graph.iteritems():
      for neighbor_k in v[2]:
        nodes[k].neighbors.add(nodes[neighbor_k])

    self.map = set(nodes.values())

  @staticmethod
  def from_file(file):
    f = open(file)
    map = Map(f.read())
    f.close()
    return map
