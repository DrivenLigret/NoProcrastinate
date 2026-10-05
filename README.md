# NoProcrastinate

Task planning and focus support for young adults managing independent study.

## Stage 3

Plan tasks, run focus sessions, complete tasks and review progress. Five screens: Plan, New task, Task, Focus and Progress. Records persist through app relaunch.

Focus restores its saved deadline. Expired sessions are saved at their scheduled end on return; stopping early records an interruption. Timer duration and task completion remain separate.

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

The `NoProcrastinate` scheme runs mock-repository use-case tests, separate persistence tests, and UI tests covering task creation, focus restoration, completion and progress after app relaunch. The `NoProcrastinateCore` scheme runs domain and persistence checks.

Repository: https://github.com/DrivenLigret/NoProcrastinate
