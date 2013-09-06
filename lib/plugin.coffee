prequire = require("parent-require")
mongoose = prequire("mongoose")

Q = require("q")

Conversations = require("./models/conversation")


module.exports = (schema, options) ->
  fields =
    conversation:
      requests:
        type: [mongoose.Schema.Types.ObjectId]
        ref: "User"
      allowed:
        type: [mongoose.Schema.Types.ObjectId]
        ref: "User"

    ignored:
      type: [mongoose.Schema.Types.ObjectId]
      ref: "User"

    inbox:
      type: [mongoose.Schema.Types.ObjectId]
      ref: "Conversation"


  schema.add(fields)

  schema.method("canConverseWith", (user) ->
    if @conversation.allowed.indexOf(user?._id.toString()) >= 0
      return true
    return false
  )


  schema.method("hasConversationRequestFrom", (user) ->
    if @conversation.requests.indexOf(user?._id.toString()) >= 0
      return true
    return false
  )


  schema.method("askPermission", (grantorId, callback) ->
    @model("User").findById(grantorId, (err, grantor) =>
      if err
        return callback(err)
  
      if grantor.conversation.requests.indexOf(@_id) >= 0
        # Requester already asked permission to this grantor before
        Conversations.findPrivateConversation([this, grantorId], (err, conversation) ->
          return callback(err, conversation)
        )
      else
        # Requester never asked permission grantor
        mongoQuery = { _id: grantorId }
        mongoUpdate = { $addToSet: { "conversation.requests": @_id }}

        # Update Grantor (append this) and create pending conversation
        Q.all([
          Q.ninvoke(@model("User"), "update", mongoQuery, mongoUpdate),
          Q.ninvoke(Conversations, "findOrCreate", this, [this, grantorId])
        ])
        .then((results) =>
          grantor.emit("conversationPermissionAsked", {sender: this})

          result =
            code: 0
            conversation: results[1]
          return callback(null, result)
        )
        .fail((err) ->
          return callback(err)
        )
    )
  )


  """
  Update Grantor (remove requester, add allowed) and start conversation.
  """

  # TODO: SECURITY: make sure that requester actually requested... (avoid requesterId spoofing)
  schema.method("grantPermission", (requester, callback) ->
    if typeof requester is "string"
      requesterId = mongoose.Types.ObjectId(requester)
    else
      requesterId = requester._id

    # Requester's id should be:
    # - added to grantor's list allowed
    # - removed from grantor's list of requests
    # Grantor's id should be:
    # - added to requester's list of allowed
    
    Conversations.findPrivateConversation([requester, this], (err, conversation) =>
      if err
        return callback(err)

      updateGrantor =
        $pull:
          "conversation.requests": requesterId
        $addToSet:
          "conversation.allowed": requesterId
      updateRequester =
        $addToSet:
          "conversation.allowed": @_id

      Q.all([
        Q.ninvoke(@model("User"), "update", {_id: this}, updateGrantor),
        Q.ninvoke(@model("User"), "update", {_id: requester}, updateRequester),
        Q.ninvoke(conversation, "start")
      ])
      .then((results) =>
        @model("User").findById(requester, (err, user) =>
          if not err
            user.emit("conversationPermissionGranted", {sender: this})
        )

        result =
          code: results[0]
          conversation: results[2]
        return callback(null, result)
      )
      .fail((err) ->
        return callback(err)
      )
    )
  )


  schema.method("denyPermission", (requester, callback) ->
    if typeof requester is "string"
      requesterId = mongoose.Types.ObjectId(requester)
    else
      requesterId = requester._id


    Conversations.findPrivateConversation([this, requester], (err, conversation) =>
      if err
        return callback(err)

      updateDenier =
        $pull:
          "conversation.requests": requesterId

      Q.all([
        Q.ninvoke(@model("User"), "update", {_id: this}, updateDenier),
        Q.ninvoke(conversation, "deny")
      ])
      .then((results) ->
        result =
          code: results[0]
          conversation: results[1]
        return callback(null, result)
      )
      .fail((err) ->
        return callback(err)
      )
    )
  )


  schema.method("findConversationRequestsReceived", (callback) ->
    query =
      status: "requested"
      "participants.ids": @_id
      "createdBy.id":
        $ne: @_id

    Conversations.find(query, (err, conversationRequests) ->
      if err
        callback("ERROR: An error occured while retrieving conversation requests sent to #{user.name} (#{err})")
      else
        callback(null, conversationRequests)
    )
  )


  schema.method("sendPrivateMessage", (recipient, message, callback) ->
    if message.trim().length is 0
      return callback("ERROR: You can't send an empty message")

    if typeof recipient is "string"
      recipientId = mongoose.Types.ObjectId(recipient)
    else
      recipientId = recipient._id
    
    if @_id.equals(recipientId)
      return callback("ERROR: Talking to yourself again?")

    participants = [@_id, recipientId]
    Conversations.findPrivateConversation(participants, (err, conversation) =>
      if err
        return callback(err)

      if conversation?
        # Found conversation
        conversation.addMessage(this, message, (err, conversation) =>
          if err
            return callback(err)

          @model("User").findById(recipientId, (err, user) =>
            if not err
              user.emit("privateMessageReceived", {sender: this, message})
          )

          return callback(null, conversation)
        )
      else
        # Conversation not found: ask user for permission to talk
        @askPermission(recipientId, (err, result) ->
          if err
            return callback(err)
          else
            return callback(null, result.conversation)
        )
    )
  )


  schema.method("getInbox", (callback) ->
    query =
      "participants.ids":
        $in: [mongoose.Types.ObjectId(@id)]
      status: "started"
      messages:
        $not:
          $size: 0

    # Get inbox as an array of conversations
    Conversations.find(query, (err, inbox) ->
      callback(err, inbox)
    )
  )
