import cocos
from cocos.actions import *

class Display(cocos.scene.Scene):
  is_event_handler = True

  def __init__(self, map):
    self._map = map

    bg = cocos.layer.ColorLayer(255, 255, 255, 255, 255)
    map_layer = MapLayer()
    sprite_layer = SpriteLayer()

    super(Display, self).__init__(bg, map_layer, sprite_layer)
  
