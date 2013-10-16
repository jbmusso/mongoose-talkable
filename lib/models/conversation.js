var prequire = require("parent-require");
var mongoose = prequire("mongoose");
var _ = require("underscore");
var troop = require("mongoose-troop");


/*
 * Sub message document Schema
 */
var MessageSchema = new mongoose.Schema({
  body: String,
  sender: {
    name: String,
    id: {
      type: [mongoose.Schema.Types.ObjectId],
      ref: "User"
    }
  }
});

/*
 * Attach created and update timestamp fields
 */
MessageSchema.plugin(troop.timestamp, {
  useVirtual: false
});


var ConversationSchema = new mongoose.Schema({
  participants: {
    ids: {
      type: [mongoose.Schema.Types.ObjectId],
      ref: "User",
      index: true
    },
    names: {
      type: [String]
    }
  },
  messages: {
    type: [MessageSchema],
    index: true
  },
  status: {
    type: String,
    "default": "requested",
    index: true
  },
  createdBy: {
    id: {
      type: [mongoose.Schema.Types.ObjectId],
      ref: "User"
    },
    name: {
      type: String
    }
  }
});

/*
 * Attach created and updated timestamp fields
 */
ConversationSchema.plugin(troop.timestamp, {
  useVirtual: false
});

/*
 * Find a conversation with participating "participants", or create a new one.
 * Checks that all "participants" are valid (ie. exist) before.
 */
ConversationSchema.statics.findOrCreate = function(creator, participants, callback) {
  var self = this;

  return creator.model("User").findByIds(participants, function(err, existingUsers) {
    if (err) {
      return callback(err);
    }

    if (participants.length > existingUsers.length) {
      return callback("ERROR: Tried adding invalid or non-existent user(s) to the conversation");
    }

    if (existingUsers.length < 2) {
      return callback("ERROR: Not enough valid participants");
    }

    participants = existingUsers;
    return self.findPrivateConversation(participants, function(err, conversation) {
      var doc, participant, _i, _len;

      if (err) {
        return callback(err);
      }

      doc = {
        createdBy: {
          id: creator._id,
          name: creator.name
        },
        participants: {
          ids: [],
          names: []
        },
        status: "requested"
      };

      for (_i = 0, _len = participants.length; _i < _len; _i++) {
        participant = participants[_i];
        doc.participants.ids.push(participant.id);
        doc.participants.names.push(participant.name);
      }

      if (!(conversation !== null)) {
        conversation = new self();
      }

      _.extend(conversation, doc);

      return conversation.save(function(err, conversation) {
        return callback(err, conversation);
      });
    });
  });
};

/*
 * Flag the conversation as "started" (ie. everyone agreed to talk to each
 * other)
 */
ConversationSchema.methods.start = function(callback) {
  var self = this;

  return this.update({
    status: "started"
  }, function(err, success) {
    if (err) {
      return callback(err);
    } else {
      self.status = "started";
      return callback(null, self);
    }
  });
};

/*
 * Flag the conversation as "ended" (participants can't talk to each other
 * any more).
 */
ConversationSchema.methods.end = function(callback) {
  var self = this;

  return this.update({
    status: "ended"
  }, function(err, success) {
    if (err) {
      return callback(err);
    } else {
      self.status = "ended";
      return callback(null, self);
    }
  });
};

/*
 * Mark this conversation as "denied", ie the grantor refused to grant the
 * requester permission to talk.
 */
ConversationSchema.methods.deny = function(callback) {
  var self = this;

  return this.update({
    status: "denied"
  }, function(err, success) {
    if (err) {
      return callback(err);
    } else {
      self.status = "denied";
      return callback(null, self);
    }
  });
};

/*
 * Add a "message" from "user" to the conversation.
 * First checks if the user is allowed to participate in the conversation.
 */
ConversationSchema.methods.addMessage = function(user, message, callback) {
  if (!this.hasParticipant(user)) {
    return callback("ERROR: User " + user.name + " (" + user._id + ") is not allowed to participate in the conversation with participants " + this.participants);
  }

  message = {
    body: message,
    sender: {
      name: user.name,
      id: user._id
    }
  };

  this.messages.push(message);

  return this.save(function(err, conversation) {
    return callback(err, conversation);
  });
};

/*
 * Find a private conversation, ie. a conversation between a maximum of 2
 * participants.
 */
ConversationSchema.statics.findPrivateConversation = function(participants, callback) {
  var query = {
    "participants.ids": {
      $size: 2,
      $all: participants
    }
  };

  return this.findOne(query, function(err, conversation) {
    if (err) {
      return callback("ERROR: We could not find this conversation (" + err + ")");
    } else {
      return callback(null, conversation);
    }
  });
};

/*
 * Get the name of the participants withouth the supplied participant/user's
 * name.
 */
ConversationSchema.methods.getParticipantsWithout = function(user) {
  return _.without(this.participants.names, user.name);
};

/*
 * Get the latest message sent to the conversation, no matter who sent it.
 */
ConversationSchema.methods.getLatestMessage = function() {
  return _.last(this.messages);
};

/*
 * Check if "participant" is registered as a participant in the conversation.
 * Ie, useful for checking if participant is allowed to participate.
 */
ConversationSchema.methods.hasParticipant = function(participant) {
  if (this.participants.ids.indexOf(participant.id) < 0) {
    return false;
  }
  return true;
};


module.exports = mongoose.model("Conversation", ConversationSchema);
