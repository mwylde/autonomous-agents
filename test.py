import random
import math

import cocos
from cocos.actions import *

class HelloWorld(cocos.layer.ColorLayer):
  is_event_handler = True
  def __init__(self):
    super( HelloWorld, self ).__init__(255, 255, 255, 255)

    # a cocos.text.Label is a wrapper of pyglet.text.Label
    # with the benefit of being a cocosnode
    label = cocos.text.Label('Hello, World!',
                             font_name='Times New Roman',
                             font_size=32,
                             anchor_x='center', anchor_y='center')

    label.position = 320,240
    self.add(label)

    self.car = Car()
    self.car.position = 320,240
    self.add(self.car, z=1)

  def on_key_press(self, key, modifiers):
    if key == 32: # space bar
      self.car.newLocation()

class Car(cocos.sprite.Sprite):
  def __init__(self):
    super(Car, self).__init__('sprites/car.png')

  def newLocation(self):
    (nx, ny) = (random.randint(0, 800), random.randint(0, 600))
    (x, y) = self.position
    angle = math.atan((float(y)-ny)/(float(x)-nx)) * (180/math.pi)
    move_rotate = MoveTo((nx, ny), 5) | RotateTo(angle, 3)
    self.do(move_rotate)

if __name__ == "__main__":
  # director init takes the same arguments as pyglet.window
  cocos.director.director.init()

  # We create a new layer, an instance of HelloWorld
  hello_layer = HelloWorld ()

  # A scene that contains the layer hello_layer
  main_scene = cocos.scene.Scene (hello_layer)

  # And now, start the application, starting with main_scene
  cocos.director.director.run (main_scene)
