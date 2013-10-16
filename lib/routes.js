var ensureLoggedIn = require("connect-ensure-login").ensureLoggedIn;
var Q = require("q");

var Conversations = require("./models/conversation");

module.exports = function(app, options) {
  app.post("/conversations/permission/ask", ensureLoggedIn("/login"), function(req, res, next) {
    var requester = req.user;
    var grantor = req.body.recipient;

    return requester.askPermission(grantor, function(err, result) {
      if (err) {
        return res.format({
          html: function() {
            req.flash("error", err);
            return res.redirect("back");
          },
          json: function() {
            return res.json(err, 500);
          }
        });
      } else {
        return res.format({
          html: function() {
            req.flash("message", result);
            return res.redirect("back");
          },
          json: function() {
            return res.json(result);
          }
        });
      }
    });
  });


  app.post("/conversations/permission/grant", ensureLoggedIn("/login"), function(req, res, next) {
    var grantor = req.user;
    var requester = req.body.requester;

    return grantor.grantPermission(requester, function(err, result) {
      if (err) {
        return res.format({
          html: function() {
            req.flash("error", err);
            return res.redirect("back");
          },
          json: function() {
            return res.json(err, 500);
          }
        });
      } else {
        return res.format({
          html: function() {
            req.flash("message", result);
            return res.redirect("back");
          },
          json: function() {
            return res.json(result);
          }
        });
      }
    });
  });


  app.post("/conversations/permission/deny", ensureLoggedIn("/login"), function(req, res, next) {
    var denier = req.user;
    var requester = req.body.requester;

    return denier.denyPermission(requester, function(err, result) {
      if (err) {
        return res.format({
          html: function() {
            req.flash("error", err);
            return res.redirect("back");
          },
          json: function() {
            return res.json(err, 500);
          }
        });
      } else {
        return res.format({
          html: function() {
            req.flash("message", result);
            return res.redirect("back");
          },
          json: function() {
            return res.json(result);
          }
        });
      }
    });
  });


  app.get("/conversations/requests", ensureLoggedIn("/login"), function(req, res, next) {
    return req.user.findConversationRequestsReceived(function(err, requests) {
      if (err) {
        res.format({
          html: function() {
            return res.render("error500.html");
          }
        });
      } else {

      }
      return res.format({
        html: function() {
          return res.render(options.requests.template, {
            requests: requests
          });
        }
      });
    });
  });


  app.get("/account/messages", ensureLoggedIn("/login"), function(req, res, next) {
    return req.user.getInbox(function(err, inbox) {
      if (err) {
        return res.format({
          html: function() {
            return res.send("Sorry, we can't access your inbox right now :(" + err, 500);
          },
          json: function() {
            return res.json("error", 500);
          }
        });
      } else {
        return res.format({
          html: function() {
            return res.render(options.inbox.template, {
              inbox: inbox
            });
          },
          json: function() {
            return res.json(inbox);
          }
        });
      }
    });
  });


  app.post("/account/messages", ensureLoggedIn("/login"), function(req, res, next) {
    return req.user.sendPrivateMessage(req.body.recipient, req.body.message, function(err, conversation) {
      var errorMessage;
      if (err) {
        errorMessage = "Sorry, we can't send this private message right now: " + err;
        return res.format({
          html: function() {
            req.flash("error", errorMessage);
            return res.redirect("back");
          },
          json: function() {
            return res.json(errorMessage, 500);
          }
        });
      } else {
        if (conversation) {
          return res.format({
            html: function() {
              return res.redirect("/account/messages");
            },
            json: function() {
              return res.json("Message was successfully posted to the conversation!");
            }
          });
        }
      }
    });
  });


  app.get("/conversations/:id", ensureLoggedIn("/login"), function(req, res, next) {
    return Conversations.findById(req.params.id, function(err, conversation) {
      var error;

      if (err) {
        error = "Sorry, an error occured while retrieving this conversations.";
        return res.format({
          html: function() {
            res.status(500);
            return res.render("error500.html");
          },
          json: function() {
            return res.json(errorMessage, 500);
          }
        });
      }

      if (conversation.hasParticipant(req.user)) {
        return res.format({
          html: function() {
            return res.render("conversations/view.html", {
              conversation: conversation
            });
          },
          json: function() {
            return res.json(conversation);
          }
        });
      } else {
        error = "Could not find this conversation. It may or may not exist, but you need to login before.";
        res.status(404);
        return res.format({
          html: function() {
            return res.render("error404.html");
          },
          json: function() {
            return res.json(error);
          }
        });
      }
    });
  });


  return app.post("/conversations/:id/messages", ensureLoggedIn("/login"), function(req, res, next) {
    return Q.ninvoke(Conversations, "findById", req.params.id).then(function(conversation) {
      if (conversation.hasParticipant(req.user)) {
        return Q.ninvoke(conversation, "addMessage", req.user, req.body.message);
      } else {
        throw "Could not add a message to this conversation. It may or may not exist, but you need to login before.";
      }
    }).then(function(conversation) {
      return res.format({
        html: function() {
          return res.redirect("back");
        },
        json: function() {
          return res.json("Message added to conversation " + conversation.id);
        }
      });
    }).fail(function(err) {
      var error;
      error = "Sorry, an error occured on our side while retrieving this conversations.";
      return res.format({
        html: function() {
          res.status(500);
          return res.render("error500.html");
        },
        json: function() {
          return res.json(err, 500);
        }
      });
    });
  });
};
