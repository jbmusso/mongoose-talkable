ensureLoggedIn = require("connect-ensure-login").ensureLoggedIn


module.exports = (app, options) ->
  app.post("/conversations/permission/ask", ensureLoggedIn("/login"), (req, res, next) ->
    requester = req.user
    grantor = req.body.recipient

    requester.askPermission(grantor, (err, result) ->
      if err
        res.format(
          html: ->
            req.flash("error", err)
            res.redirect("back")
          json: ->
            res.json(err, 500)
        )
      else
        res.format(
          html: ->
            req.flash("message", result)
            res.redirect("back")
          json: ->
            res.json(result)
        )
    )
  )


  app.post("/conversations/permission/grant", ensureLoggedIn("/login"), (req, res, next) ->
    grantor = req.user
    requester = req.body.requester

    grantor.grantPermission(requester, (err, result) ->
      if err
        res.format(
          html: ->
            req.flash("error", err)
            res.redirect("back")
          json: ->
            res.json(err, 500)
        )
      else
        res.format(
          html: ->
            req.flash("message", result)
            res.redirect("back")
          json: ->
            res.json(result)
        )
    )
  )


  app.post("/conversations/permission/deny", ensureLoggedIn("/login"), (req, res, next) ->
    denier = req.user
    requester = req.body.requester

    denier.denyPermission(requester, (err, result) ->
      if err
        res.format(
          html: ->
            req.flash("error", err)
            res.redirect("back")
          json: ->
            res.json(err, 500)
        )
      else
        res.format(
          html: ->
            req.flash("message", result)
            res.redirect("back")
          json: ->
            res.json(result)
        )
    )
  )


  app.get("/conversations/requests", ensureLoggedIn("/login"), (req, res, next) ->
    req.user.findConversationRequestsReceived((err, requests) ->
      if err
        console.log err
      else
      res.format(
        html: ->
          res.render(options.requests.template, {requests})
      )
    )
  )


  # View inbox
  app.get("/account/messages", ensureLoggedIn("/login"), (req, res, next) ->
    req.user.getInbox((err, inbox) ->
      if err
        res.format(
          html: ->
            res.send("Sorry, we can't access your inbox right now :("+err, 500)
          json: ->
            res.json("error", 500)
        )
      else
        res.format(
          html: ->
            res.render(options.inbox.template, {inbox})
          json: ->
            res.json(inbox)
        )
    )
  )

  # Send a new private message
  app.post("/account/messages", ensureLoggedIn("/login"), (req, res, next) ->
    req.user.sendPrivateMessage(req.body.recipient, req.body.message, (err, conversation) ->
      if err
        errorMessage = "Sorry, we can't send this private message right now: #{err}"
        res.format(
          html: ->
            req.flash("error", errorMessage)
            res.redirect("back")
          json: ->
            res.json(errorMessage, 500)
        )
      else
        if conversation
          res.format(
            html: ->
              res.redirect("/account/messages")
            json: ->
              res.json("Message was successfully posted to the conversation!")
          )
    )
  )
