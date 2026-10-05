import CoreData
import Foundation

public final class CoreDataStudyRepository: StudyRepository {
    private let container: NSPersistentContainer
    private let context: NSManagedObjectContext

    public init(storeURL: URL? = nil) throws {
        let url = storeURL ?? NSPersistentContainer.defaultDirectoryURL().appendingPathComponent("NoProcrastinate.sqlite")
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        } catch {
            throw StudyError.storageUnavailable
        }
        let persistentContainer = NSPersistentContainer(name: "NoProcrastinate", managedObjectModel: Self.studyModel())
        let store = NSPersistentStoreDescription(url: url)
        store.shouldAddStoreAsynchronously = false
        store.shouldMigrateStoreAutomatically = true
        store.shouldInferMappingModelAutomatically = true
        persistentContainer.persistentStoreDescriptions = [store]
        var loadError: Error?
        persistentContainer.loadPersistentStores { _, error in loadError = error }
        guard loadError == nil else { throw StudyError.storageUnavailable }
        container = persistentContainer
        context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    public func tasks() throws -> [StudyTask] {
        try perform { try taskRecords().map(studyTask) }
    }

    public func task(id: UUID) throws -> StudyTask? {
        try perform {
            guard let record = try record(entity: "StudyTask", id: id) else { return nil }
            return try studyTask(record)
        }
    }

    public func overdueTasks(at date: Date) throws -> [StudyTask] {
        try perform {
            let predicate = NSPredicate(format: "completedAt == nil AND plannedStart < %@", date as NSDate)
            return try taskRecords(predicate: predicate).map(studyTask)
        }
    }

    public func sessions() throws -> [FocusSession] {
        try perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "FocusSession")
            request.sortDescriptors = [NSSortDescriptor(key: "startedAt", ascending: true)]
            return try context.fetch(request).map(focusSession)
        }
    }

    public func save(_ task: StudyTask) throws {
        try write {
            let saved = try record(entity: "StudyTask", id: task.id) ?? NSEntityDescription.insertNewObject(forEntityName: "StudyTask", into: context)
            saved.setValue(task.id, forKey: "id")
            saved.setValue(task.title, forKey: "title")
            saved.setValue(task.plannedStart, forKey: "plannedStart")
            saved.setValue(task.deadline, forKey: "deadline")
            saved.setValue(task.focusMinutes, forKey: "focusMinutes")
            saved.setValue(task.postponeCount, forKey: "postponeCount")
            saved.setValue(task.completedAt, forKey: "completedAt")
            saved.setValue(task.source, forKey: "source")
            saved.setValue(task.createdAt, forKey: "createdAt")
        }
    }

    public func save(_ session: FocusSession) throws {
        try write {
            guard let task = try record(entity: "StudyTask", id: session.taskID) else { throw StudyError.taskMissing }
            let saved = try record(entity: "FocusSession", id: session.id) ?? NSEntityDescription.insertNewObject(forEntityName: "FocusSession", into: context)
            saved.setValue(session.id, forKey: "id")
            saved.setValue(task, forKey: "task")
            saved.setValue(session.startedAt, forKey: "startedAt")
            saved.setValue(session.plannedMinutes, forKey: "plannedMinutes")
            saved.setValue(session.endedAt, forKey: "endedAt")
            saved.setValue(session.interrupted, forKey: "interrupted")
        }
    }

    private func perform<T>(_ action: () throws -> T) throws -> T {
        do {
            return try context.performAndWait(action)
        } catch let error as StudyError {
            throw error
        } catch {
            throw StudyError.storageUnavailable
        }
    }

    private func write(_ action: () throws -> Void) throws {
        try perform {
            do {
                try action()
                try context.save()
            } catch {
                context.rollback()
                throw error
            }
        }
    }

    private func record(entity: String, id: UUID) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: entity)
        request.predicate = NSPredicate(format: "id == %@", id as NSUUID)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private func taskRecords(predicate: NSPredicate? = nil) throws -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "StudyTask")
        request.predicate = predicate
        request.sortDescriptors = [NSSortDescriptor(key: "plannedStart", ascending: true), NSSortDescriptor(key: "createdAt", ascending: true)]
        return try context.fetch(request)
    }

    private func studyTask(_ record: NSManagedObject) throws -> StudyTask {
        guard let id = record.value(forKey: "id") as? UUID,
              let title = record.value(forKey: "title") as? String,
              let start = record.value(forKey: "plannedStart") as? Date,
              let deadline = record.value(forKey: "deadline") as? Date,
              let minutes = record.value(forKey: "focusMinutes") as? NSNumber,
              let postponements = record.value(forKey: "postponeCount") as? NSNumber,
              let created = record.value(forKey: "createdAt") as? Date else { throw StudyError.storageUnavailable }
        return StudyTask(id: id, title: title, plannedStart: start, deadline: deadline, focusMinutes: minutes.intValue, postponeCount: postponements.intValue, completedAt: record.value(forKey: "completedAt") as? Date, source: record.value(forKey: "source") as? String, createdAt: created)
    }

    private func focusSession(_ record: NSManagedObject) throws -> FocusSession {
        guard let id = record.value(forKey: "id") as? UUID,
              let task = record.value(forKey: "task") as? NSManagedObject,
              let taskID = task.value(forKey: "id") as? UUID,
              let start = record.value(forKey: "startedAt") as? Date,
              let minutes = record.value(forKey: "plannedMinutes") as? NSNumber,
              let interrupted = record.value(forKey: "interrupted") as? NSNumber else { throw StudyError.storageUnavailable }
        return FocusSession(id: id, taskID: taskID, startedAt: start, plannedMinutes: minutes.intValue, endedAt: record.value(forKey: "endedAt") as? Date, interrupted: interrupted.boolValue)
    }

    private static func studyModel() -> NSManagedObjectModel {
        func attribute(_ name: String, _ type: NSAttributeType, optional: Bool = false, defaultValue: Any? = nil) -> NSAttributeDescription {
            let result = NSAttributeDescription()
            result.name = name
            result.attributeType = type
            result.isOptional = optional
            result.defaultValue = defaultValue
            return result
        }
        let task = NSEntityDescription()
        task.name = "StudyTask"
        task.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        task.properties = [attribute("id", .UUIDAttributeType), attribute("title", .stringAttributeType), attribute("plannedStart", .dateAttributeType), attribute("deadline", .dateAttributeType), attribute("focusMinutes", .integer64AttributeType), attribute("postponeCount", .integer64AttributeType, defaultValue: 0), attribute("completedAt", .dateAttributeType, optional: true), attribute("source", .stringAttributeType, optional: true), attribute("createdAt", .dateAttributeType)]
        task.uniquenessConstraints = [["id"]]
        let session = NSEntityDescription()
        session.name = "FocusSession"
        session.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        session.properties = [attribute("id", .UUIDAttributeType), attribute("startedAt", .dateAttributeType), attribute("plannedMinutes", .integer64AttributeType), attribute("endedAt", .dateAttributeType, optional: true), attribute("interrupted", .booleanAttributeType, defaultValue: false)]
        session.uniquenessConstraints = [["id"]]
        let attempts = NSRelationshipDescription()
        attempts.name = "sessions"
        attempts.destinationEntity = session
        attempts.minCount = 0
        attempts.maxCount = 0
        attempts.isOptional = true
        attempts.deleteRule = .cascadeDeleteRule
        let owner = NSRelationshipDescription()
        owner.name = "task"
        owner.destinationEntity = task
        owner.minCount = 1
        owner.maxCount = 1
        owner.isOptional = false
        owner.deleteRule = .nullifyDeleteRule
        attempts.inverseRelationship = owner
        owner.inverseRelationship = attempts
        task.properties.append(attempts)
        session.properties.append(owner)
        let model = NSManagedObjectModel()
        model.entities = [task, session]
        return model
    }
}
