import Foundation
import FoundationModels

/// Narrows a structured result's string fields to a fixed list of values, so the model can't
/// write anything else. This is how plans are held to the exercise library: every
/// `exerciseID` field may only be one of the ids offered.
///
/// It works on the schema's JSON form, so it applies to any `@Generable` type, however deeply
/// the field is nested.
public enum SchemaConstraint {
    public static func restrict(
        _ schema: GenerationSchema, allowedValues: [String: [String]], arrayCounts: [String: Int] = [:]
    ) throws -> GenerationSchema {
        guard !allowedValues.isEmpty || !arrayCounts.isEmpty else { return schema }
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(schema))
        let patched = patch(json, allowedValues: allowedValues, arrayCounts: arrayCounts)
        let data = try JSONSerialization.data(withJSONObject: patched)
        return try JSONDecoder().decode(GenerationSchema.self, from: data)
    }

    /// Walks the JSON schema, adding an `enum` to every string property with a restricted name
    /// and fixing the length of every array property with a counted name.
    static func patch(_ node: Any, allowedValues: [String: [String]], arrayCounts: [String: Int] = [:]) -> Any {
        if let array = node as? [Any] {
            return array.map { patch($0, allowedValues: allowedValues, arrayCounts: arrayCounts) }
        }
        guard var object = node as? [String: Any] else { return node }
        for (key, value) in object {
            object[key] = patch(value, allowedValues: allowedValues, arrayCounts: arrayCounts)
        }
        if var properties = object["properties"] as? [String: Any] {
            restrictValues(in: &properties, allowedValues)
            fixCounts(in: &properties, arrayCounts)
            object["properties"] = properties
        }
        return object
    }

    static func restrictValues(in properties: inout [String: Any], _ allowedValues: [String: [String]]) {
        for (name, values) in allowedValues {
            guard var property = properties[name] as? [String: Any] else { continue }
            if property["type"] as? String == "string" {
                property["enum"] = values
            } else if property["type"] as? String == "array", var items = property["items"] as? [String: Any],
                items["type"] as? String == "string"
            {
                items["enum"] = values
                property["items"] = items
            }
            properties[name] = property
        }
    }

    static func fixCounts(in properties: inout [String: Any], _ arrayCounts: [String: Int]) {
        for (name, count) in arrayCounts {
            guard var property = properties[name] as? [String: Any], property["type"] as? String == "array" else {
                continue
            }
            property["minItems"] = count
            property["maxItems"] = count
            properties[name] = property
        }
    }
}
