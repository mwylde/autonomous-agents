import cocos
from cocos.actions import *

class Display(cocos.layer.ColorLayer):
  is_event_handler = True
  
  def __init__(self, map):
    super(Display, self).__init__(255, 255, 255, 255)
    self._map = map
  
