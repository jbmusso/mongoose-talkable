prequire = require("parent-require")
mongoose = prequire("mongoose")


_ = require("underscore")
troop = require("mongoose-troop")


MessageSchema = new mongoose.Schema(
  body: String

  sender:
    name: String
    id:
      type: [mongoose.Schema.Types.ObjectId]
      ref: "User"
)

MessageSchema.plugin(troop.timestamp, useVirtual: false)


ConversationSchema = new mongoose.Schema(
  participants:
    ids:
      type: [mongoose.Schema.Types.ObjectId]
      ref: "User"
      index: true
    names:
      type: [String]

  messages:
    type: [MessageSchema]
    index: true

  status:
    type: String # requested, denied, started, ended
    default: "requested"
    index: true

  createdBy:
    id:
      type: [mongoose.Schema.Types.ObjectId]
      ref: "User"
    name:
      type: String
)

ConversationSchema.plugin(troop.timestamp, useVirtual: false)


ConversationSchema.statics.findOrCreate = (creator, participants, callback) ->
  creator.model("User").findByIds(participants, (err, existingUsers) =>
    if err
      return callback(err)

    if participants.length > existingUsers.length
      # Some participants are invalid or non-existent: abort creation
      return callback("ERROR: Tried adding invalid or non-existent user(s) to the conversation")

    if existingUsers.length < 2
      # Can't start a conversation with only one participant (talking to yourself again?)
      return callback("ERROR: Not enough valid participants")

    participants = existingUsers

    @findPrivateConversation(participants, (err, conversation) =>
      if err
        return callback(err)

      doc =
        createdBy:
          id: creator._id
          name: creator.name
        participants:
          ids: []
          names: []
        status: "requested"

      for participant in participants
        doc.participants.ids.push(participant.id)
        doc.participants.names.push(participant.name)

      if not conversation?
        conversation = new this()
      _.extend(conversation, doc)

      conversation.save((err, conversation) -> return callback(err, conversation))
    )
  )


ConversationSchema.methods.start = (callback) ->
  @update({ status: "started" }, (err, success) =>
    if err
      callback(err)
    else
      @status = "started"
      callback(null, this)
  )


ConversationSchema.methods.end = (callback) ->
  @update({ status: "ended" }, (err, success) =>
    if err
      callback(err)
    else
      @status = "ended"
      callback(null, this)
  )


ConversationSchema.methods.deny = (callback) ->
  @update({ status: "denied" }, (err, success) =>
    if err
      callback(err)
    else
      @status = "denied"
      callback(null, this)
  )


ConversationSchema.methods.addMessage = (user, message, callback) ->
  # Check if user is an allowed participant
  if @participants.ids.indexOf(user._id) < 0
    return callback("ERROR: User #{user.name} (#{user._id}) is not allowed to participate in the conversation with participants #{@participants}")

  message =
    body: message
    sender:
      name: user.name
      id: user._id

  @messages.push(message)
  @save((err, conversation) -> callback(err, conversation))


ConversationSchema.statics.findPrivateConversation = (participants, callback) ->
  query =
    "participants.ids":
      $size: 2
      $all: participants

  @findOne(query, (err, conversation) ->
    if err
      callback("ERROR: We could not find this conversation (#{err})")
    else
      callback(null, conversation)
  )


module.exports = mongoose.model("Conversation", ConversationSchema)
