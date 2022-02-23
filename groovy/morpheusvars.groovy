import static groovy.json.JsonOutput.*

if (customOptions) {
    println("==== customOptions =========")
    print(prettyPrint(toJson(customOptions)))
} else {
    println("No CustomOptions variable defined")
}
if (instance) {
    println("==== instance ==============")
    print(prettyPrint(toJson(instance)))
} else {
    println("No instance variable defined")
}

if (server) {
    println("==== server ================")
    print(prettyPrint(toJson(server)))
} else {
    println("No server variable defined")
}

if (zone) {
    println("==== zone ==================")
    print(prettyPrint(toJson(zone)))
} else {
    println("No zone variable defined")
}
