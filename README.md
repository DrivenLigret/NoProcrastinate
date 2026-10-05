# NoProcrastinate

Task planning and focus support for young adults managing independent study.

## Stage 2

Plan, create and review study tasks. Tasks persist through app relaunch. PlanStudyTask validates the title, start, deadline and focus duration.

## Design

SwiftUI Views → ViewModels → Use Cases → StudyRepository → Core Data.

Core Data stores private, offline study records. StudyTask has many FocusSessions. The repository queries incomplete tasks with a start earlier than now. Views and ViewModels use domain values.

| Planned extension | Purpose |
| --- | --- |
| WidgetKit | Next task and focus timer on the Home Screen. |
| Share | Import study links and text into task planning. |
| Device Activity Monitor | End focus restrictions without reopening the app. |

Planned App Group: `group.com.drivenligret.NoProcrastinate`.

## Setup

Open `NoProcrastinate.xcodeproj` in Xcode 16 or later. Select an iOS 17 or later simulator and run the `NoProcrastinate` scheme. Select your signing team for a device build.

The `NoProcrastinate` scheme tests planning with a mock repository, persistence in separate integration tests, and task creation followed by app relaunch. The `NoProcrastinateCore` scheme runs domain and persistence checks.

Repository: https://github.com/DrivenLigret/NoProcrastinate
