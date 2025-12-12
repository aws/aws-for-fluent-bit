-- replace_dots.lua
-- Configurable dot replacement using record_modifier configuration
-- Replaces dots in field names with specified character (default: "_")
--
-- Usage Examples:
--
-- 1. Simple usage (default "_" replacement):
--    [FILTER]
--        Name lua
--        Match *
--        Script /fluent-bit/filters/replace_dots.lua
--        Call filter
--
-- 2. Custom replacement per log type:
--    [FILTER]
--        Name record_modifier
--        Match kubernetes.*
--        Record _replace_dots_with _
--    
--    [FILTER]
--        Name record_modifier
--        Match app.*
--        Record _replace_dots_with -
--    
--    [FILTER]
--        Name lua
--        Match *
--        Script /fluent-bit/filters/replace_dots.lua
--        Call filter
--
-- Input:  {"kubernetes.pod_name": "web-123", "app.config": {"db.host": "localhost"}}
-- Output: {"kubernetes_pod_name": "web-123", "app_config": {"db_host": "localhost"}}

local default_replacement = "_"

-- Get replacement character from record configuration
function get_replacement_char(record)
    if record and record["_replace_dots_with"] then
        return tostring(record["_replace_dots_with"])
    end
    return default_replacement
end

-- Recursively process nested tables/objects
function replace_dots_recursive(obj, replacement_char)
    if type(obj) == "table" then
        local new_obj = {}

        for key, value in pairs(obj) do
            -- Skip only the config field
            if key ~= "_replace_dots_with" then
                -- Replace dots only in string keys
                local new_key = type(key) == "string" 
                    and string.gsub(key, "%.", replacement_char) 
                    or key

                new_obj[new_key] = type(value) == "table" 
                    and replace_dots_recursive(value, replacement_char) 
                    or value
            end
        end

        return new_obj
    else
        return obj
    end
end

-- Main filter function called by Fluent Bit
function filter(tag, timestamp, record)
    local replacement_char = get_replacement_char(record)
    local new_record = replace_dots_recursive(record, replacement_char)
    return 1, timestamp, new_record
end
