mongoose = require("mongoose")

before((done) ->
  mongoose.connect("localhost", "unit-testing")

  mongoose.connection.once("open", =>
    conn = mongoose.connection
    console.log "Connected to MongoDB: #{conn.host}:#{conn.port}/#{conn.db.databaseName}"

    done()
  )
)

after((done) ->
  mongoose.connection.close()
  done()
)
