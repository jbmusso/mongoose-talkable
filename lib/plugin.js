var prequire = require("parent-require");
var mongoose = prequire("mongoose");
var Q = require("q");

var Conversations = require("./models/conversation");

/*
 * Make one your model, typically a "user" model ('this') with a "name" field
 * able to engage in a conversation with other "user model(s)".
 */
module.exports = function(schema, options) {
  var fields = {
    conversation: {
      requests: {
        type: [mongoose.Schema.Types.ObjectId],
        ref: "User"
      },
      allowed: {
        type: [mongoose.Schema.Types.ObjectId],
        ref: "User"
      }
    },
    ignored: {
      type: [mongoose.Schema.Types.ObjectId],
      ref: "User"
    },
    inbox: {
      type: [mongoose.Schema.Types.ObjectId],
      ref: "Conversation"
    }
  };

  schema.add(fields);

  /*
   * Check if supplied "user" is allowed to converse with "this" user.
   * @return {Boolean}
   */
  schema.method("canConverseWith", function(user) {
    if (this.conversation.allowed.indexOf(user !== null ? user._id.toString() : void 0) >= 0) {
      return true;
    }
    return false;
  });

  /*
   * Check if "this" user as received a conversation request from "user"
   * @return {Boolean}
   */
  schema.method("hasConversationRequestFrom", function(user) {
    if (this.conversation.requests.indexOf(user !== null ? user._id.toString() : void 0) >= 0) {
      return true;
    }
    return false;
  });

  /*
   * Make "this" user ask a potential "grantor" for permission to talk.
   */
  schema.method("askPermission", function(grantorId, callback) {
    var self = this;
    return this.model("User").findById(grantorId, function(err, grantor) {
      var mongoQuery, mongoUpdate;

      if (err) {
        return callback(err);
      }

      if (grantor.conversation.requests.indexOf(self._id) >= 0) {
        return Conversations.findPrivateConversation([self, grantorId], function(err, conversation) {
          return callback(err, conversation);
        });
      } else {
        mongoQuery = {
          _id: grantorId
        };

        mongoUpdate = {
          $addToSet: {
            "conversation.requests": self._id
          }
        };

        return Q.all([
          Q.ninvoke(self.model("User"), "update", mongoQuery, mongoUpdate),
          Q.ninvoke(Conversations, "findOrCreate", self, [self, grantorId])
          ]).then(function(results) {
          var result = {
            code: 0,
            conversation: results[1]
          };

          self.notify(grantor, "conversationPermissionAsked");

          return callback(null, result);
        }).fail(function(err) {
          return callback(err);
        });
      }
    });
  });

  /*
   * Update Grantor (remove requester, add allowed) and start the conversation.
   */
  schema.method("grantPermission", function(requester, callback) {
    var requesterId,
      self = this;

    if (typeof requester === "string") {
      requesterId = mongoose.Types.ObjectId(requester);
    } else {
      requesterId = requester._id;
    }

    return Conversations.findPrivateConversation([requester, this], function(err, conversation) {
      var updateGrantor, updateRequester;

      if (err) {
        return callback(err);
      }

      updateGrantor = {
        $pull: {
          "conversation.requests": requesterId
        },
        $addToSet: {
          "conversation.allowed": requesterId
        }
      };

      updateRequester = {
        $addToSet: {
          "conversation.allowed": self._id
        }
      };

      return Q.all([
        Q.ninvoke(self.model("User"), "update", { _id: self }, updateGrantor),
        Q.ninvoke(self.model("User"), "update", { _id: requester}, updateRequester),
        Q.ninvoke(conversation, "start")
      ]).then(function(results) {
        var result;

        self.model("User").findById(requester, function(err, requester) {
          if (!err) {
            return self.notify(requester, "conversationPermissionGranted");
          }
        });

        result = {
          code: results[0],
          conversation: results[2]
        };
        return callback(null, result);
      }).fail(function(err) {
        return callback(err);
      });
    });
  });

  /*
   * Deny a "requester" permission to engage in a conversation with "this" user
   */
  schema.method("denyPermission", function(requester, callback) {
    var requesterId,
      self = this;

    if (typeof requester === "string") {
      requesterId = mongoose.Types.ObjectId(requester);
    } else {
      requesterId = requester._id;
    }

    return Conversations.findPrivateConversation([this, requester], function(err, conversation) {
      var updateDenier;

      if (err) {
        return callback(err);
      }

      updateDenier = {
        $pull: {
          "conversation.requests": requesterId
        }
      };

      return Q.all([
        Q.ninvoke(self.model("User"), "update", {_id: self}, updateDenier),
        Q.ninvoke(conversation, "deny")
      ]).then(function(results) {
        var result;
        result = {
          code: results[0],
          conversation: results[1]
        };
        return callback(null, result);
      }).fail(function(err) {
        return callback(err);
      });
    });
  });

  /*
   * Find all pending conversation requests received (ie. requests not yet
   * accepted by "this" user).
   */
  schema.method("findConversationRequestsReceived", function(callback) {
    var query = {
      status: "requested",
      "participants.ids": this._id,
      "createdBy.id": {
        $ne: this._id
      }
    };

    return Conversations.find(query, function(err, conversationRequests) {
      if (err) {
        return callback("ERROR: An error occured while retrieving conversation requests sent to " + user.name + " (" + err + ")");
      } else {
        return callback(null, conversationRequests);
      }
    });
  });

  /*
   * Sends a private message to another User.
   * Will internally check first if users can talk to each other, or will send
   * otherwise a conversation request from "this" to "recipient" user (note
   * that in the latter case, the initial message will be discarded - for now).
   */
  schema.method("sendPrivateMessage", function(recipient, message, callback) {
    var participants,
        recipientId,
        self = this;

    if (message.trim().length === 0) {
      return callback("ERROR: You can't send an empty message");
    }

    if (typeof recipient === "string") {
      recipientId = mongoose.Types.ObjectId(recipient);
    } else {
      recipientId = recipient._id;
    }

    if (this._id.equals(recipientId)) {
      return callback("ERROR: Talking to yourself again?");
    }

    participants = [this._id, recipientId];

    return Conversations.findPrivateConversation(participants, function(err, conversation) {
      if (err) {
        return callback(err);
      }

      if (conversation !== null) {
        return conversation.addMessage(self, message, function(err, conversation) {
          if (err) {
            return callback(err);
          }

          self.model("User").findById(recipientId, function(err, user) {
            if (!err) {
              return self.notify(user, "privateMessageReceived", {
                message: message
              });
            }
          });

          return callback(null, conversation);
        });
      } else {
        return self.askPermission(recipientId, function(err, result) {
          if (err) {
            return callback(err);
          } else {
            return callback(null, result.conversation);
          }
        });
      }
    });
  });

  /*
   * Get "this" user inbox as an array of Conversation documents
   */
  return schema.method("getInbox", function(callback) {
    var self = this;
    var query = {
      "participants.ids": {
        $in: [mongoose.Types.ObjectId(this.id)]
      },
      status: "started",
      messages: {
        $not: {
          $size: 0
        }
      }
    };

    return Conversations.find(query).sort({ modified: -1 })
    .exec(function(err, inbox) {
      inbox.owner = self;
      return callback(err, inbox);
    });
  });
};
