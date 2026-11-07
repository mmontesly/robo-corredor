local CourseBuilder = require(script.Parent.CourseBuilder)
local RobotFactory = require(script.Parent.RobotFactory)
local RaceService = require(script.Parent.RaceService)

RobotFactory.install()
local pads = CourseBuilder.build()
RaceService.start(pads)
