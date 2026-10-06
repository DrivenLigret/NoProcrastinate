# NoProcrastinate

Task planning and focus support for young adults managing independent study.

## Stage 4

Plan tasks, run focus sessions, complete tasks and review progress. Supervision adds postponement, adaptive focus suggestions, local reminders and optional app limits. Records persist through app relaunch.

Focus restores its saved deadline. Expired sessions are saved at their scheduled end on return; stopping early records an interruption. Timer duration and task completion remain separate.

After two postponements, smart supervision suggests 15 minutes and a shorter reminder follow-up. Starting focus or completing a task removes its study prompts. Notification taps open the task.

## Design

SwiftUI Views → ViewModels → Use Cases → StudyRepository → Core Data.

Core Data stores private, offline study records. StudyTask has many FocusSessions. The repository queries incomplete tasks with a start earlier than now. Views and ViewModels use domain values.

| Extension | Purpose |
| --- | --- |
| WidgetKit (planned) | Next task and focus timer on the Home Screen. |
| Share (planned) | Import study links and text into task planning. |
| Device Activity Monitor | End focus restrictions without reopening the app. |

App Group: `group.com.drivenligret.NoProcrastinate`. The app and monitor coordinate access to the focus lease. The monitor releases restrictions when iOS delivers the end callback.

## Setup

Open `NoProcrastinate.xcodeproj` in Xcode 16 or later. Select an iOS 17 or later simulator and run the `NoProcrastinate` scheme. Select your signing team for a device build.

Use the same signing team for the app and monitor. Register their App Group and enable Family Controls. In Supervision, authorize access, choose apps, then enable During focus. App limits require a signed physical iPhone; distribution requires Apple's Family Controls approval for both targets.

The `NoProcrastinate` scheme runs mock-repository use-case tests, persistence and shared-file integration tests, and UI tests. GitHub Actions tests on a simulator and compiles for a device. Actual shielding and background release still require physical-device verification.

Repository: https://github.com/DrivenLigret/NoProcrastinate
