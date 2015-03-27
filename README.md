# fluent-plugin-mongo-slow-query

It will be helpful to find out the slow operations of MongoDB and ayalyze the query prototype.
The usage is almost same as **in_tail**.

## Install

```$ fluent-gem install fluent-plugin-mongo-slow-query```

## Configuration

```
<source>
    type mongo_slow_query
    path /path/to/mongodb/logfile
<source>
```

## Description

- **time** local time of host that the MongoDB instance is running on
- **op** operation, for example: query update remove getmore command
- **ns** namespace, concatenation of the database name and the collection name
- **detail** the deatils of operation
- **query** the prototype of query, for example:  
    { address: { country: "China", city: "Beijing" } } => { address.country, address.city }  
    { ts: { $gt: 1411029300, $lt: 1411029302 } => { ts.$gt, ts.$lt }  
    It's convenient to statistics the similar slow queries with the same prototype and build indexes.
- **ms** time used, unit: millisecond
- **nscanned** number of documents scanned
- **nmatched** number of documents matched
- **nmodified** number of documents modified
- **reslen** response length

## Support

- MongoDB v2.4
- MongoDB v2.6
- MongoDB v3.0
