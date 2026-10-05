# NoProcrastinate

Task planning and focus support for young adults managing independent study.

## Stage 1

StudyTask, FocusSession, StudyRepository, PlanStudyTask and nine mock-repository tests. Task planning checks the title, start, deadline and focus duration.

## Design

SwiftUI Views → ViewModels → Use Cases → StudyRepository → Core Data.

Core Data is planned for private, offline study records. StudyTask has many FocusSessions.

| Planned extension | Purpose |
| --- | --- |
| WidgetKit | Next task and focus timer on the Home Screen. |
| Share | Import study links and text into task planning. |
| Device Activity Monitor | End focus restrictions without reopening the app. |

Planned App Group: `group.com.drivenligret.NoProcrastinate`.

## Setup

Open `NoProcrastinate.xcodeproj` in Xcode 16 or later. Select an iOS 17 or later simulator and run tests with the `NoProcrastinateCore` scheme.

Repository: https://github.com/DrivenLigret/NoProcrastinate
