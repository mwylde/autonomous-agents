module Driving
  # Width of a lane of a road (ie, a road is actually twice as wide)
  ROAD_WIDTH = 3.65

  # Width of an agent
  AGENT_WIDTH = 1.75
  # Length of an agent
  AGENT_LENGTH = 4.45
  # Maximum number of crumbs for an agent to record
  AGENT_MAX_CRUMBS = 200
  # How wide an agent's tires are with respect to the agent's width
  AGENT_TIRE_WIDTH = 0.1
  # How long an agent's tires are with respect to the agent's length
  AGENT_TIRE_LENGTH = 0.25
  # How frequently (per second) an agent should update its parameters
  AGENT_UPDATE_FREQ = 50.0
  
  DYNAMICAL_AGENT_RADIUS = AGENT_WIDTH / 2.0
  DYNAMICAL_OBSTACLES_AHEAD = false

  LANE_DASH_MARK_LEN = 1.0
  LANE_DASH_SPACE_LEN = 2.0

  DISPLAY_MAX_CRUMBS = 200
  WORLD_DOT_RADIUS = 0.6
  POINT_RADIUS = 2
  INIT_ZOOM = 40.0 # 2300.0
  MIN_ZOOM = 5
  MAX_ZOOM = 1000000
  DISPLAY_SLEEP_DURATION = 0.05
  INIT_FOLLOWING = true

  CRUMBS_ON = false
end
