process.env.NODE_ENV = "test"

should = require("should")
Conversations = require("../lib/models/conversation")
Users = User = require("../example/models/user")


describe "Conversation.statics.findOrCreate()", ->
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


  storedConversation = null

  describe "when creating a conversation between 2 users", ->
    it "should create a conversation with no message", (done) ->
      Conversations.findOrCreate users[0], users, (err, conversation) ->
        storedConversation = conversation
        should.not.exist(err)
        should.exist(conversation)
        storedConversation.status.should.equal("requested")

        conversation.participants.ids.should.have.lengthOf(users.length)
        conversation.participants.names.should.have.lengthOf(users.length)
        for user in users
          conversation.participants.ids.should.include(user._id)
          conversation.participants.names.should.include(user.name)

        conversation.messages.should.have.lengthOf(0)
        done()


  describe "when starting the conversation", ->
    it "should start the conversation", (done) ->
      storedConversation.start (err, conversation) ->
        should.not.exist(err)
        should.exist(conversation)
        storedConversation.status.should.equal("started")
        done()


  describe "when adding a message", ->
    it "should add a message to the conversation", (done) ->
      message = "First post!"
      # console.log storedConversation
      storedConversation.addMessage users[0], message, (err, conversation) ->
        should.not.exist(err)
        should.exist(conversation)
        conversation.messages.should.have.lengthOf(1)
        conversation.messages[0].body.should.equal(message)
        done()


  describe "when looking for a user inbox", ->
    it "should have added 1 conversations to User0's inbox", (done) ->
      users[0].getInbox((err, inbox) ->
        should.not.exist(err)
        should.exist(inbox)
        inbox.should.be.an.instanceOf(Array)
        inbox.should.have.lengthOf(1)
        done()
      )

    it "should have added 1 conversation to User1's inbox", (done) ->
      users[0].getInbox((err, inbox) ->
        should.not.exist(err)
        should.exist(inbox)
        inbox.should.be.an.instanceOf(Array)
        inbox.should.have.lengthOf(1)
        done()
      )


  describe "when ending a conversation", ->
    it "should end the conversation", (done) ->
      storedConversation.end (err, conversation) ->
        should.not.exist(err)
        should.exist(conversation)
        conversation.status.should.equal("ended")
        done()

