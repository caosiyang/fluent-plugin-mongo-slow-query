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
    path /var/log/mongo/mongod.log
    tag mongo.slow_query
<source>
```

# Notice
The configuration parameters of **in_mongo_slow_query** are same to **in_tail**.  
The **format** and **time_format** are optional. The default will be loaded unless you set them manually. If you need to reset, reset both of them.  
Default:
```
format /(?<time>[^ ]+ [^ ]+ [^ ]+ [^ ]+) \[\w+\] (?<op>[^ ]+) (?<ns>[^ ]+) ((query: (?<query>{.+}) update: {.*})|(query: (?<query>{.+}))) .* (?<ms>\d+)ms/
time_format %a %b %d %H:%M:%S.%L
```

- **time** the local time of host that the MongoDB instance running on
- **op** the type of operation, for example: query update remove
- **query**  
    the prototype of query, for example:  
    {name: "Sia", age: 29} => {name, age}  
    {name: "Sia", addr: {country: "China", city: "Beijing"}} => {name, addr.country, addr.city}  
    With the prototype, it's convenient to stat the slow query.
- **ms** the time cost of operation, unit: ms

