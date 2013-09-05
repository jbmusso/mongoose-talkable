express = require("express")
talkable = require("../lib/routes")


app = express()
talkable.use(app)


module.exports = app