require 'json'

module Fluent
    class MongoDBSlowQueryInput < TailInput
        # First, register the plugin. NAME is the name of this plugin
        # and identifies the plugin in the configuration file.
        Plugin.register_input('mongo_slow_query', self)

        # This method is called before starting.
        # 'conf' is a Hash that includes configuration parameters.
        # If the configuration is invalid, raise Fluent::ConfigError.
        def configure(conf)
            # load log format for MongoDB
            conf["format"] = '/^(?<time>.*?)(?:\s+\w\s\w+\s*)? \[conn\d+\] (?<op>\w+) (?<ns>\S+) (?<detail>query: (?<query>\{(?:\g<query>|[^\{\}])*\})(?: update: (?<update>\{(?:\g<update>|[^\{\}])*\}))?|command:.*?(?<command>\{(?:\g<command>|[^\{\}])*\})|.*?) (?<stat>.*?)(?: locks:\{.*\})? (?<ms>\d+)ms$/'

            # not set "time_format"
            # default use Ruby's DateTime.parse() to pase time
            #
            # be compatible for v2.2, 2.4, 2.6 and 3.0
            # difference of time format
            # 2.2: Wed Sep 17 10:00:00 [connXXX] ...
            # 2.4: Wed Sep 17 10:00:00.123 [connXXX] ...
            # 2.6: 2014-09-17T10:00:43.506+0800 [connXXX] ...
            # 3.0: 2015-03-18T15:28:44.321+0800 I QUERY    [conn5462] ...
            #unless conf.has_key?("time_format")
            #    #conf["time_format"] = '%a %b %d %H:%M:%S'
            #    #conf["time_format"] = '%a %b %d %H:%M:%S.%L'
            #    #$log.warn "load default time_format: ", conf["time_format"]
            #end
            super
        end

        def receive_lines(lines)
            es = MultiEventStream.new
            lines.each {|line|
                begin
                    line.chomp!  # remove \n
                    time, record = parse_line(line)
                    if time && record
                        if record.has_key?("query")
                            record["query"] = get_query_prototype(record["query"])
                        else
                            record["query"] = ""
                        end
                        record["ms"] = record["ms"].to_i
                        record["ts"] = time

                        case record["op"]
                        when "query"
                        when "getmore"
                            res = /ntoskip:(?<ntoskip>\d+)/.match(record["stat"])
                            if res
                                record["ntoskip"] = res["ntoskip"].to_i
                            end
                            res = /nscanned:(?<nscanned>\d+)/.match(record["stat"])
                            if res
                                record["nscanned"] = res["nscanned"].to_i
                            end
                            res = /nreturned:(?<nreturned>\d+)/.match(record["stat"])
                            if res
                                record["nreturned"] = res["nreturned"].to_i
                            end
                            res = /reslen:(?<reslen>\d+)/.match(record["stat"])
                            if res
                                record["reslen"] = res["reslen"].to_i
                            end
                        when "update"
                            res = /nscanned:(?<nscanned>\d+)/.match(record["stat"])
                            if res
                                record["nscanned"] = res["nscanned"].to_i
                            end
                            res = /nMatched:(?<nmatched>\d+)/.match(record["stat"])
                            if res # MongoDB v3.0
                                record["nmatched"] = res["nmatched"].to_i
                                res = /nModified:(?<nmodified>\d+)/.match(record["stat"])
                                if res
                                    record["nmodified"] = res["nmodified"].to_i
                                end
                            else # MongoDB v2.4
                                res = /nupdated:(?<nmodified>\d+)/.match(record["stat"])
                                if res
                                    record["nmodified"] = res["nmodified"].to_i
                                end
                            end
                        when "remove"
                            res = /ndeleted:(?<ndeleted>\d+)/.match(record["stat"])
                            if res
                                record["ndeleted"] = res["ndeleted"].to_i
                            end
                        end

                        #if record.has_key?("update")
                        #    record["update"] = get_query_prototype(record["update"])
                        #end

                        es.add(time, record)
                    end
                rescue
                    $log.warn line.dump, :error=>$!.to_s
                    $log.debug_backtrace
                end
            }

            unless es.empty?
                begin
                    Engine.emit_stream(@tag, es)
                rescue
                    #ignore errors. Engine shows logs and backtraces.
                end
            end
        end

        # extract query prototype recursively
        def extract_query_prototype(query_json_obj, parent='')
            ns_array = []
            query_json_obj.each do |key, val|
                ns = parent.empty? ? key : (parent + '.' + key)
                if val.class == Hash
                    ns_array += extract_query_prototype(val, ns)
                elsif val.class == Array
                    val.each do |item|
                        if item.class == Hash # e.g. $eq $gt $gte $lt $lte $ne $in $nin
                            ns_array += extract_query_prototype(item, ns)
                        else # e.g. $and $or $nor
                            ns_array << ns 
                            break
                        end
                    end
                else
                    ns_array << ns
                end
            end
            return ns_array
        end

        # get query prototype
        def get_query_prototype(query)
            begin
                prototype = extract_query_prototype(JSON.parse(to_json(query)))
                return '{ ' + prototype.join(', ') + ' }'
            rescue
                $log.warn $!.to_s
                return query
            end
        end

        # convert query to JSON
        def to_json(query)
            res = query
            # conversion for fieldname
            res = res.gsub(/( [^ ]+?: )/) {|fieldname| fieldname_format(fieldname)}
            # conversion for ObjectId
            res = res.gsub(/ObjectId\([^ ]+?\)/) {|objectid| to_string(objectid)}
            # conversion for Timestamp
            res = res.gsub(/Timestamp \d+\|\d+/) {|timestamp| to_string(timestamp)}
            # conversion for Date
            res = res.gsub(/new Date\(\d+\)/) {|date| to_string(date)}
            # filter regex
            res = res.gsub(/\/\^.*\//) {|pattern| to_string(pattern)}
            return res
        end

        # format fieldname in query
        # e.g.: { id: 1 } => { "id": 1 }
        def fieldname_format(fieldname)
            return ' "%s": ' % fieldname.strip.chomp(':')
        end

        # convert value of special type to string
        # so that convert query to json
        def to_string(str)
            res = str
            res = res.gsub(/"/, '\"')
            res = '"%s"' % res
            return res
        end
    end
end
