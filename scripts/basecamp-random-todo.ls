# Description:
#   Chooses a random basecamp todo.
#
# Dependencies:
#
# Configuration:
#   * Note: These don't start with HUBOT so the getenv script will hide them.
#
#   BASECAMP_USERNAME     -  Your Hubot's username
#   BASECAMP_PASSWORD     -  The associated password
#
#   * You can get these from a url like https://basecamp.com/11111111/projects/22222222-my-project-name
#   HUBOT_BASECAMP_ACCOUNT      -  Your basecamp account, 11111111 in the above url
#   HUBOT_BASECAMP_PROJECT      -  Your basecamp project, 22222222 in the above url
#
# Commands:
#
# URLS:
#
# Authors:
#   divide

HttpClient     = require 'scoped-http-client'
require! async
{map, flatten} = require 'prelude-ls'

http = (url) -> HttpClient.create(url)\
    .header('User-Agent', "Hubot/#{@version}")

choose_random = (list) ->
  index = Math.floor Math.random! * list.length
  list[index]

basecamp = (http) ->
  username = process.env.BASECAMP_USERNAME
  password = process.env.BASECAMP_PASSWORD
  base_url = "https://basecamp.com/#{process.env.HUBOT_BASECAMP_ACCOUNT}/api/v1/"
  http = http(base_url).auth(username, password)
  get = (path) -> http.scope(path).get!

  {
    todolists: (cb) -> get('todolists.json')(-> cb JSON.parse(&.2))

    remaining-todos: (cb) ->
      lists <- @todolists!
      (err, results) <- async.parallel (lists |> map (.url) |> map get)
      results |> map ((.1) >> JSON.parse >> (.todos.remaining)) |> flatten |> cb
  }

api-to-ui-url = (.replace /api\/v1\//,'') >> (.replace /\.json$/,'')

format-todo = (todo) ->
  "#{todo.content} <#{api-to-ui-url todo.url}>"

operations = ->
  @respond /todo/i, (msg)->
    todos <- basecamp(msg.robot.http).remaining-todos!
    todo = choose_random todos
    console.log todo
    msg.send format-todo todo

module.exports = -> operations.call it