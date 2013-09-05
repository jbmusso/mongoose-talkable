mongoose = require("mongoose")
talkable = require("../../lib/plugin")

findbyids = require("mongoose-findbyids")


UserSchema = mongoose.Schema(
  name:
    type: String
)

UserSchema.plugin(findbyids)
UserSchema.plugin(talkable)


try
  mongoose.model("User", UserSchema)

module.exports = mongoose.model("User")
