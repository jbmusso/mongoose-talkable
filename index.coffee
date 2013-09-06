plugin = require("./lib/plugin")
model = require("./lib/models/conversation")


module.exports =
  routes: (app) ->
    require("./lib/routes")(app)
    
  plugin: plugin

  model: model
