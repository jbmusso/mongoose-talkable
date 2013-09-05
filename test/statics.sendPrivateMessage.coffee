process.env.NODE_ENV = "test"

should = require("should")
Conversations = require("../lib/models/conversation")
Users = User = require("../example/models/user")


describe "Conversation.statics.sendPrivateMessage()", ->
  users = []

  before (done) ->
    Conversations.remove({}, -> done())

  before (done) ->
    Users.remove({}, -> done())

  before (done) ->
    users[0] = new User(name: "Alice")
    users[0].save((err, user) ->
      done()
    )

  before (done) ->
    users[1] = new User(name: "Bob")
    users[1].save((err, user) ->
      done()
    )


  messageOne = "Hello there!"

  describe "when 'Alice' sends 'Bob' a private message before asking 'Bob' for permission", ->
    storedConversation = null

    it "should ask 'Bob' for permission", (done) ->
      users[0].sendPrivateMessage(users[1], messageOne, (err, conversation) ->
        should.not.exist(err)
        should.exist(conversation)
        conversation.status.should.equal("requested")

        conversation.participants.ids.should.have.lengthOf(2)
        conversation.participants.names.should.have.lengthOf(2)
        for user in users
          conversation.participants.ids.should.include(user._id)
          conversation.participants.names.should.include(user.name)

        storedConversation = conversation
        done()
      )

    it "should create a pending conversation between 'Alice' and 'Bob'", (done) ->
      Conversations.findPrivateConversation([users[0], users[1]], (err, conversation) ->
        should.not.exist(err)
        should.exist(conversation)
        conversation.status.should.equal("requested")

        done()
      )

    it "shouldn't add a message to the conversation", (done) ->
        storedConversation.messages.should.have.lengthOf(0)
        done()


  describe "when 'Bob' grants 'Alice' permission to send him a private message", ->
    it "should start the conversation", (done) ->
      users[1].grantPermission(users[0], (err, success) ->
        should.not.exist(err)
        should.exist(success)
        conversation = success.conversation
        conversation.status.should.equal("started")
        done()
      )

    it "should add update 'Bob's (grantor) requests/allowed lists", (done) ->
      Users.findById(users[1], (err, user) ->
        user.conversation.requests.indexOf(users[0]._id).should.equal(-1)
        user.conversation.allowed.indexOf(users[0]._id).should.not.equal(-1)
        done()
      )

    it "should add update 'Alice's (requester) allowed lists", (done) ->
      Users.findById(users[0], (err, user) ->
        user.conversation.allowed.indexOf(users[1]._id).should.not.equal(-1)
        done()
      )



  describe "when 'Alice' sends a message to 'Bob'", ->
    it "should add the message to the conversation", (done) ->
      users[0].sendPrivateMessage(users[1], messageOne, (err, conversation) ->
        should.not.exist(err)
        should.exist(conversation)
        conversation.messages.should.have.lengthOf(1)
        conversation.messages[0].body.should.equal(messageOne)
        done()
      )

    it "should not create another private conversation", (done) ->
      Conversations.find({}).count().exec((err, count) ->
        should.not.exist(err)
        should.exist(count)
        count.should.equal(1)
        done()
      )


  storedConversation = null
  describe "when 'Bob' sends a reply to 'Alice'", ->
    messageTwo = "Hello, what's up?"

    it "should add the message to the conversation", (done) ->
      users[1].sendPrivateMessage(users[0], messageTwo, (err, conversation) ->
        should.not.exist(err)
        should.exist(conversation)

        conversation.messages.should.have.lengthOf(2)
        conversation.messages[1].body.should.equal(messageTwo)
        storedConversation = conversation
        done()
      )


  describe "when 'Alice' sends another private message to 'Bob'", ->
    messageThree = "How are you?"
    it "should add the message to the conversation", (done) ->
      storedConversation.addMessage(users[0], messageThree, (err, conversation) ->
        should.not.exist(err)
        should.exist(conversation)
        storedConversation = conversation
        done()
      )

    it "should not create a second conversation", (done) ->
      Conversations.find({}).count().exec((err, count) ->
        should.not.exist(err)
        should.exist(count)
        count.should.equal(1)
        done()
      )
      

    it "should add the message to the conversation", (done) ->
      storedConversation.messages.should.have.lengthOf(3)
      storedConversation.messages[2].body.should.equal(messageThree)
      done()


