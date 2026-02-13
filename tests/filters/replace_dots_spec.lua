-- Load the filter module
package.path = package.path .. ";aws-for-fluent-bit/filters/?.lua"
dofile("aws-for-fluent-bit/filters/replace_dots.lua")

describe("replace_dots filter", function()
    -- 2021-12-01 12:00:00 UTC
    local TEST_TIMESTAMP = 1638360000
    local TEST_TAG = "test"
    describe("basic field replacement", function()
        it("should replace dots in simple field names", function()
            local record = {["kubernetes.pod_name"] = "web-123"}
            local code, timestamp, result = filter(TEST_TAG, TEST_TIMESTAMP, record)

            assert.equals("web-123", result["kubernetes_pod_name"])
            assert.is_nil(result["kubernetes.pod_name"])
        end)

        it("should handle multiple dots in single field name", function()
            local record = {["field.with.many.dots"] = "value"}
            local code, timestamp, result = filter(TEST_TAG, TEST_TIMESTAMP, record)
            
            assert.equals("value", result["field_with_many_dots"])
            assert.is_nil(result["field.with.many.dots"])
        end)

        it("should leave fields without dots unchanged", function()
            local record = {
                simple_field = "value",
                another_field = 123
            }
            local code, timestamp, result = filter(TEST_TAG, TEST_TIMESTAMP, record)

            assert.equals("value", result["simple_field"])
            assert.equals(123, result["another_field"])
        end)
    end)

    describe("nested structures", function()
        it("should handle nested objects with dots", function()
            local record = {
                ["app.config"] = {
                    ["db.host"] = "localhost",
                    ["db.port"] = 5432
                }
            }
            local code, timestamp, result = filter(TEST_TAG, TEST_TIMESTAMP, record)

            assert.equals("localhost", result["app_config"]["db_host"])
            assert.equals(5432, result["app_config"]["db_port"])
            assert.is_nil(result["app.config"])
        end)

        it("should handle multiple levels of nesting", function()
            local record = {
                ["level1.field"] = {
                    ["level2.field"] = {
                        ["level3.field"] = "deep_value"
                    }
                }
            }
            local code, timestamp, result = filter(TEST_TAG, TEST_TIMESTAMP, record)

            assert.equals("deep_value", result["level1_field"]["level2_field"]["level3_field"])
            assert.is_nil(result["level1.field"])
        end)
    end)

    describe("type preservation", function()
        it("should preserve string, number, and boolean types", function()
            local record = {
                ["string.field"] = "value",
                ["number.field"] = 42,
                ["boolean.field"] = true
            }
            local code, timestamp, result = filter(TEST_TAG, TEST_TIMESTAMP, record)

            assert.equals("value", result["string_field"])
            assert.equals(42, result["number_field"])
            assert.is_true(result["boolean_field"])
        end)

        it("should preserve array structures", function()
            local record = {
                ["array.field"] = {"item1", "item2", "item3"}
            }
            local code, timestamp, result = filter(TEST_TAG, TEST_TIMESTAMP, record)

            assert.same({"item1", "item2", "item3"}, result["array_field"])
            assert.is_nil(result["array.field"])
        end)
    end)

    describe("custom replacement character", function()
        it("should use custom replacement character when specified", function()
            local record = {
                ["_replace_dots_with"] = "-",
                ["kubernetes.pod.name"] = "web-123"
            }
            local code, timestamp, result = filter(TEST_TAG, TEST_TIMESTAMP, record)

            assert.equals("web-123", result["kubernetes-pod-name"])
            assert.is_nil(result["_replace_dots_with"])
            assert.is_nil(result["kubernetes.pod.name"])
        end)

        it("should apply custom replacement to nested structures", function()
            local record = {
                ["_replace_dots_with"] = "::",
                ["service.name"] = "api",
                ["metrics.data"] = {
                    ["cpu.usage"] = 75.5,
                    ["memory.usage"] = 60.2
                }
            }
            local code, timestamp, result = filter(TEST_TAG, TEST_TIMESTAMP, record)

            assert.equals("api", result["service::name"])
            assert.equals(75.5, result["metrics::data"]["cpu::usage"])
            assert.equals(60.2, result["metrics::data"]["memory::usage"])
            assert.is_nil(result["_replace_dots_with"])
        end)
    end)

    describe("edge cases", function()
        it("should handle empty records", function()
            local record = {}
            local code, timestamp, result = filter(TEST_TAG, TEST_TIMESTAMP, record)

            assert.is_nil(next(result))
        end)

        it("should return correct code and timestamp", function()
            local record = {["test.field"] = "value"}
            local test_ts = 12345
            local code, timestamp, result = filter(TEST_TAG, test_ts, record)

            assert.equals(1, code)
            assert.equals(test_ts, timestamp)
            assert.equals("value", result["test_field"])
        end)
    end)

    describe("real-world scenarios", function()
        it("should handle complex Kubernetes log structure", function()
            local record = {
                ["kubernetes.pod_name"] = "web-123",
                ["kubernetes.namespace_name"] = "production",
                ["app.config"] = {
                    ["db.host"] = "localhost",
                    ["db.port"] = 5432,
                    ["cache.settings"] = {
                        ["redis.host"] = "redis-server",
                        ["redis.port"] = 6379
                    }
                },
                log = "Application started successfully"
            }
            local code, timestamp, result = filter(TEST_TAG, TEST_TIMESTAMP, record)

            assert.equals("web-123", result["kubernetes_pod_name"])
            assert.equals("production", result["kubernetes_namespace_name"])
            assert.equals("localhost", result["app_config"]["db_host"])
            assert.equals(5432, result["app_config"]["db_port"])
            assert.equals("redis-server", result["app_config"]["cache_settings"]["redis_host"])
            assert.equals(6379, result["app_config"]["cache_settings"]["redis_port"])
            assert.equals("Application started successfully", result["log"])

            assert.is_nil(result["kubernetes.pod_name"])
            assert.is_nil(result["kubernetes.namespace_name"])
            assert.is_nil(result["app.config"])
        end)
    end)
end)
