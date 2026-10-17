#if DEBUG
    import CoreData
    import SwiftData
    import Testing

    @testable import TransmuteCore

    struct CloudKitSchemaTests {
        /// `-initCloudKitSchema` pushes this model to CloudKit, so a model it left out would
        /// have no record type in Production.
        @Test func theSchemaModelCoversEveryModelInTheSchema() throws {
            let model = try TransmuteStore.cloudKitSchemaModel()
            let schemaNames = Set(TransmuteStore.schema.entities.map(\.name))
            #expect(!schemaNames.isEmpty)
            #expect(Set(model.entitiesByName.keys) == schemaNames)
        }

        /// SwiftData stores the nested settings as composite attributes, one column per member,
        /// not as an encoded blob, so a member added to one is a new column. That is a SchemaV2
        /// change whatever the type's `init(from:)` does with a backup that lacks it.
        @Test func theProfileKeepsItsColumns() throws {
            let profile = try #require(try TransmuteStore.cloudKitSchemaModel().entitiesByName["Profile"])
            #expect(
                profile.attributesByName.keys.sorted() == [
                    "barbellKg", "birthYear", "createdAt", "distanceUnitRaw", "equipmentRaw", "experienceRaw",
                    "goalTagsRaw", "goalText", "heightCm", "heightUnitRaw", "id", "knownLifts",
                    "limitationAreasRaw", "limitations", "plates", "preferences", "progression", "schedule",
                    "sexRaw", "sports", "unitSystemRaw", "weightUnitRaw",
                ])
            let members: [String: [String]] = [
                "schedule": ["commitments", "daysPerWeek", "preferredWeekdays", "sessionMinutes", "weeks"],
                "progression": ["heldExerciseIDs", "lowerBodyKg", "lowerBodyLb", "upperBodyKg", "upperBodyLb"],
                "preferences": [
                    "autoStartRest", "restHaptics", "restSound", "showPercentOfMax", "showRPE", "warmUpRestSeconds",
                    "warmUpSets", "workingRestSeconds",
                ],
                "plates": [
                    "barKind", "bars", "dumbbellStepKg", "heaviestDumbbellKg", "machineStepKg", "plates", "system",
                ],
            ]
            for (name, expected) in members {
                let attribute = try #require(profile.attributesByName[name] as? NSCompositeAttributeDescription)
                #expect(attribute.elements.map(\.name).sorted() == expected, "\(name)")
            }
        }
    }
#endif
