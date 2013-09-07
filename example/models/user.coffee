mongoose = require("mongoose")
findbyids = require("mongoose-findbyids")

talkable = require("../../lib/plugin")


UserSchema = mongoose.Schema(
  name:
    type: String
)

UserSchema.plugin(findbyids)
UserSchema.plugin(talkable)


module.exports = mongoose.model("User", UserSchema)
