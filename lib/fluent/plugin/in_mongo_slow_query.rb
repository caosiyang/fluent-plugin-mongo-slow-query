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
            unless conf.has_key?("format")
                #conf["format"] = '/(?<time>[^ ]+ [^ ]+ [^ ]+ [^ ]+) \[\w+\] (?<op>[^ ]+) (?<ns>[^ ]+) ((query: (?<query>{.+}) update: (?<update>{.*}))|(query: (?<query>{.+}))) .* (?<ms>\d+)ms/'
                conf["format"] = '/(?<time>[^ ]+ [^ ]+ [^ ]+ [^ ]+) \[\w+\] (?<op>[^ ]+) (?<ns>[^ ]+) ((query: (?<query>{.+}) update: {.*})|(query: (?<query>{.+}))) .* (?<ms>\d+)ms/'
                $log.warn "load default format: ", conf["format"]
            end

            unless conf.has_key?("time_format")
                conf["time_format"] = '%a %b %d %H:%M:%S.%L'
                $log.warn "load default time_format: ", conf["time_format"]
            end
            super
        end

        def receive_lines(lines)
            es = MultiEventStream.new
            lines.each {|line|
                begin
                    line.chomp!  # remove \n
                    time, record = parse_line(line)
                    if time && record
                        # get prototype
                        if record.has_key?("query")
                            record["query"] = get_query_prototype(record["query"])
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
                else
                    ns_array << ns
                end
            end
            return ns_array
        end

        # get query prototype
        def get_query_prototype(query)
            begin
                prototype = extract_query_prototype(JSON.parse(eval(query).to_json))
                return '{ ' + prototype.join(', ') + ' }'
            rescue
                $log.error $!.to_s
                return query
            end
        end
    end
end
