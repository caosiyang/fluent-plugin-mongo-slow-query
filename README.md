fluent-plugin-mongo-slow-query
==============================
# Usage
It will be helpful to find out the slow operations of MongoDB and ayalyze the query prototype.  
The usage is almost same as **in_tail**.

# Install
```$ fluent-gem install fluent-plugin-mongo-slow-query```

# Configure
```
<source>
    type mongo_slow_query
    path /path/to/mongodb/logfile
<source>
```

# Notice
The configuration parameters of **in_mongo_slow_query** are same to **in_tail**.  
The **format** is designed for MongoDB log record. 
```
format /(?<time>.*) \[\w+\] (?<op>[^ ]+) (?<ns>[^ ]+) ((?<detail>(query: (?<query>\{.+\}) update: \{.*\}))|((?<detail>(query: (?<query>\{.+\}))) planSummary: .*)|((?<detail>query: (?<query>\{.+\})))) .* (?<ms>\d+)ms/
```

- **time** the local time of host that the MongoDB instance running on
- **op** the type of operation, for example: query update remove
- **ns** the namespace that is consist by both database and collection
- **detail** the content of operation
- **query**  
    the prototype of query, for example:  
    { address: { country: "China", city: "Beijing" } } => { address.country, address.city }  
    { ts: { $gt: 1411029300, $lt: 1411029302 } => { ts.$gt, ts.$lt }  
    With the prototype, it's convenient to stat the slow query.
- **ms** the time cost of operation, unit: ms

