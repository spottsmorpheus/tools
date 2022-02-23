private getProperties(obj) {
     
    def propertyString = obj.properties
        .sort{it.key}
        .collect{it}
        .findAll{!['class', 'active']
        .contains(it.key)}
        .join('\n')
    
    return 'Class Type ' + obj.getClass() + '\n' + propertyString
}


