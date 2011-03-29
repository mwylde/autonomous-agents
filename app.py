import cocos
import os, sys
from optparse import OptionParser

from display import Display
from map import Map

class App:
  def __init__(self):
    self._parse_options()
    self._map = Map.from_file(self._options.map_path)

    cocos.director.director.init()
    self._display = Display(self._map)
    
  def start(self):
    cocos.director.director.run (self._display)
    

  def _parse_options(self):
    op = OptionParser()
    op.add_option('--map', dest='map_path', help='path to map json file', default='map.json')
    options, args = op.parse_args()
    self._options = options
    self._args = args

    if not options.map_path:
      op.error('no map path set')    
    
def main():
  app = App()
  app.start()

if __name__ == '__main__':
  main()
