sexpr = require \./index.js
{ parse } = sexpr

test = (name, func) ->
  (require \tape) name, (t) ->
    func.call t   # Make `this` refer to tape's asserts
    t.end!        # Automatically end tests

# Because writing out all the '{ type : \list content : [ ... ]  }' stuff would
# be boring and unreadable, here's a dead simple DSL for simplifying that.
convert = ->
  switch typeof! it
  | \Null   => null
  | \Array  => type : \list content : it.map convert
  | \String =>
    if it instanceof Object then type : \string content : it.to-string!
                            else type : \atom   content : it

  | otherwise =>
    throw Error "Test error; invalid convenience template (got #that)"

to = (input, output, description) -->
  output = convert output
  test description, -> input |> parse |> @deep-equals _, output

#
# Basics
#

''    `to` null          <| "empty input"
' \t' `to` null          <| "empty input (just whitespace)"
'a'   `to` \a            <| "atom"
'"a"' `to` new String \a <| "string"
'()'  `to` []            <| "empty list"
' a ' `to` \a            <| "whitespace is insignificant"
'((a b c)(()()))'   `to` [[\a \b \c] [[] []]] <| "nested lists"
'((a b c) (() ()))' `to` [[\a \b \c] [[] []]] <| "nested lists with spacing"

'(a\nb)' `to` [\a \b] <| "newlines are not part of atoms"

#
# Quoting operators
#

[ [\' \quote] [\` \quasiquote] [\, \unquote] [\,@ \unquote-splicing] ]
  .for-each ([c, name]) ->
    "#{c}a"      `to` [name, \a]              <| "#name'd atom"
    "#c\"a\""    `to` [name, new String \a]   <| "#name'd string"
    "#c()"       `to` [name, []]              <| "#name'd empty list"
    "#c(a b c)"  `to` [name, [\a \b \c]]      <| "#name'd list with contents"
    "(#{c}a)"    `to` [[name, \a]]            <| "#name'd atom in a list"
    "(a #c b)"   `to` [\a [name, \b]]         <| "whitespaced #name"
    "(a #c#c b)" `to` [\a [name, [name, \b]]] <| "consecutive #{name}s nest"
    "(a#{c}b)"   `to` [\a [name, \b]]         <| "#{name} acts as delimiter"

    test "#name with nothing to apply to is an error" ->
      (-> parse "(#c)") `@throws` sexpr.SyntaxError

#
# Special characters and escaping
#

char-escape = ->
  switch it
  | \\n => "\\n"
  | \\t => "\\t"
  | \\r => "\\r"
  | _   => it

[ \' \` \" \; \\ " " '"' "\n" "\t" ] .for-each (c) ->
  "a\\#{c}b" `to` "a#{c}b"
    <| "escaped #{char-escape c} in an atom should parse"

[ \" "\\" ] .for-each (c) ->
  "\"a\\#{c}b\"" `to` new String "a#{c}b"
    <| "escaped #{char-escape c} in a string should parse"

[ [\b "\b"] [\f "\f"] [\n "\n"] [\r "\r"] [\t "\t"] [\v "\v"] [\0 "\0"] ]
  .for-each ([char, escapedChar]) ->
    "\"a\\#{char}b\"" `to` new String "a#{escapedChar}b"
    <| "strings may contain \\#{char} escape"

test "special characters work" ->
  <[ + / * £ $ % ^ & あ ]>.for-each ->
    it `to` it <| "special character #it works as atom"

#
# Comments
#

";hi" `to` null           <| "only 1 comment"
";hi\n;yo" `to` null      <| "only comments"
"(\n; a\n;b\n\n)" `to` [] <| "empty list with comments inside"
"();hi" `to` []           <| "comment immediately following list"
"a;hi" `to` "a"           <| "comment immediately following atom"
";(a comment)" `to` null  <| "comment looking like a form"
"(a ;)\nb)" `to` [\a \b]  <| "form with close-paren-looking comment between"
'("a ;)"\n)' `to` [new String "a ;)"] <| "can't start comment in string"

#
# Form errors
#

test "stuff after the end is an error" ->
  [ "()" "a" ")" ].for-each ~> (-> parse "()#it") `@throws` sexpr.SyntaxError

test "incomplete string is an error" ->
  (-> parse '"a') `@throws` sexpr.SyntaxError

test "incomplete form due to comment is an error" ->
  (-> parse '(a;)') `@throws` sexpr.SyntaxError

