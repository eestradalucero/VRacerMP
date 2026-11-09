# RaceMP Guidelines

## Lua Style
- Use `local` for all variables and functions
- Log with `log('D', logTag, ...)` not `print()`
- Favor human readability, method names should be descriptive:
-- prettyTime is a bad method name, but getPrettyTime is good because it describes that we are getting it.
-- For long functions, use smaller funcions as indexes, for example:
DoSomething():
    var myLocalVariable = 434
    DoFirstThing()
    processedVariable = processSpeed(myLocalVariable)
    if processedVariable:
        doActionOne()
    else
        doActionTwo()
    return value


-- IF any questions, follow Uncle Bob's "Clean Code" book standards.
- Let's try to avoid repetition, if please suggest how we can avoid it in a logical manner.
- Split files per responsability.