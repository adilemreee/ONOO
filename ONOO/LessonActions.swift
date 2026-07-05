//
//  LessonActions.swift
//  One — Ders Defteri
//
//  Ders kopyalama ve hızlı ders oluşturma yardımcıları.
//

import Foundation
import SwiftData

enum LessonActions {
    static func copy(_ lesson: Lesson, to date: Date, in context: ModelContext) {
        let new = Lesson(student: lesson.student,
                         date: date,
                         duration: lesson.duration,
                         status: .planned,
                         topic: lesson.topic,
                         note: lesson.note,
                         feeOverride: lesson.feeOverride)
        context.insert(new)
        new.student = lesson.student
        try? context.save()
    }

    static func copyNextWeek(_ lesson: Lesson, in context: ModelContext) {
        copy(lesson, to: lesson.date.adding(days: 7), in: context)
    }

    static func copyFourWeeks(_ lesson: Lesson, in context: ModelContext) {
        for week in 1...4 {
            let date = lesson.date.adding(days: 7 * week)
            let new = Lesson(student: lesson.student,
                             date: date,
                             duration: lesson.duration,
                             status: .planned,
                             topic: week == 1 ? lesson.topic : "",
                             note: week == 1 ? lesson.note : "",
                             feeOverride: lesson.feeOverride)
            context.insert(new)
            new.student = lesson.student
        }
        try? context.save()
    }
}
