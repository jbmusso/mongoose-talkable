mongoose = require("mongoose")


before((done) ->
  mongoose.connect("localhost", "unit-testing")

  mongoose.connection.once("open", =>
    done()
  )
)

after((done) ->
  mongoose.connection.close()
  done()
)
