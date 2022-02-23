import static groovy.json.JsonOutput.*

try {
    if (customOptions) {
        println("==== customOptions =========")
        println(prettyPrint(toJson(customOptions)))
    } else {
        println("No CustomOptions variable defined")
    }
} catch(ex) {
    println("customOptions Exception ${ex.message}")
}


try {
    if (instance) {
        println("==== instance ==============")
        println(prettyPrint(toJson(instance)))
    } else {
        println("No instance variable defined")
    }
} catch(ex) {
    println("instance Exception ${ex.message}")
}


try {
    if (server) {
        println("==== server ================")
        println(prettyPrint(toJson(server)))
    } else {
        println("No server variable defined")
    }
} catch(ex) {
    println("server Exception ${ex.message}")
}

try {
    if (zone) {
        println("==== zone ==================")
        println(prettyPrint(toJson(zone)))
    } else {
        println("No zone variable defined")
    }
} catch(ex) {
    println("zone Exception ${ex.message}")
}