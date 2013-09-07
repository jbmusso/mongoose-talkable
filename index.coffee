plugin = require("./lib/plugin")
model = require("./lib/models/conversation")


module.exports =
  routes: (app, options) ->
    require("./lib/routes")(app, options)
    
  plugin: plugin

  model: model
