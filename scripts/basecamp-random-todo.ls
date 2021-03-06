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
#   What <pattern> to do? -- picks a random todo matching an optional pattern and assigned to yourself or nobody.
#
# URLS:
#
# Authors:
#   divide

require! async
{map, flatten, filter, words, first} = require 'prelude-ls'

const leisure =
  "a nice cup of coffee"
  "a relaxing walk in the park"
  "a lunch break"

choose_random = (list) ->
  index = Math.floor Math.random! * list.length
  list[index]

basecamp = (http) ->
  username = process.env.BASECAMP_USERNAME
  password = process.env.BASECAMP_PASSWORD
  base_url = "https://basecamp.com/#{process.env.HUBOT_BASECAMP_ACCOUNT}/api/v1/"
  http = http(base_url).auth(username, password)
  scope = (path) -> http.scope(path)
  get = scope >> (.get!)

  {
    todolists: (cb) -> get('todolists.json')(-> cb JSON.parse(&.2))

    remaining-todos: (cb) ->
      lists <- @todolists!
      (err, results) <- async.parallel (lists |> map (.url) |> map get)
      todolists = results |> map ((.1) >> JSON.parse)
      todos = todolists.map ((list) ->
        list.todos.remaining |> map ->
          (it.list = list.name; it) # add list name to todos
      ) |> flatten
      todos |> cb

    delete-todo: (todo, cb) ->
      (res, resp, body) <- scope(todo).delete!!
      cb (resp.statusCode < 300)
  }

api-to-ui-url = (- /api\/v1\//) >> (- /\.json$/)

format-todo = (todo) ->
  todo.content && "#{todo.content} : #{api-to-ui-url todo.url} " || todo

contains = (pattern, str) -->
  !!str.match(new RegExp pattern, 'i')

# http://en.wikipedia.org/wiki/You_talkin'_to_me%3F
youTalkinToMe = (msg) ->
  input = msg.message.text.toLowerCase!
  name = msg.robot.name.toLowerCase!
  input.indexOf(name) != -1

const MAX_PATTERN_WORDS = 3
const MAX_RELATED_MS = 5 * 60 * 1000

give-random-todo = (msg, pattern) ->
  todos <- basecamp(msg.robot.http).remaining-todos!
  if pattern then todos = todos |> filter ((todo) ->
    (todo.content |> contains pattern) || (todo.list |> contains pattern)
  )
  todos = todos |> filter ((todo) ->
    !todo.assignee? || (todo.assignee.name == msg.message.user.name)
  )
  todo = choose_random todos ++ choose_random leisure
  msg.robot.brain.set \basecamp-random-todo, do
    todo: todo
    user: msg.message.user
    pattern: pattern
    time: Date.now!
  msg.send "#{first words msg.message.user.name}, how about #{format-todo todo}?"

operations = ->
  @hear /what ((.*) )?to do\??/i, (msg)->
    return unless youTalkinToMe msg
    pattern = msg.match[2]
    return if (words pattern || []).length > MAX_PATTERN_WORDS
    give-random-todo msg, pattern

  @hear /something else/i, (msg) ->
    last = msg.robot.brain.get \basecamp-random-todo
    return if Date.now! - last.time > MAX_RELATED_MS
    return unless msg.message.user == last.user
    give-random-todo msg, last.pattern

  @respond /nuke it/i, (msg) ->
    last = msg.robot.brain.get \basecamp-random-todo
    return if Date.now! - last.time > MAX_RELATED_MS
    todo = last.todo
    if (todo?.url?)
      ok <- basecamp(msg.robot.http).delete-todo todo
      if ok
        msg.send "#{todo.content} is no more!"
        msg.robot.brain.set \last-todo, void
      else
        msg.send "no proliferation"
    else
      msg.send "I honestly have no idea what you're talking about"

module.exports = -> operations.call it
