# NoProcrastinate

Task planning and focus support for young adults managing independent study.

## Stage 6

Plan tasks, run focus sessions, complete tasks and review progress. Supervision adds postponement, adaptive focus suggestions, local reminders and optional app limits. Records persist through app relaunch.

Focus restores its saved deadline. Expired sessions are saved at their scheduled end on return; stopping early records an interruption. Timer duration and task completion remain separate.

After two postponements, smart supervision suggests 15 minutes and a shorter reminder follow-up. Starting focus or completing a task removes its study prompts. Notification taps open the task.

The Home Screen widget supports small and medium sizes. It shows the next task or active focus countdown; the medium size also shows today's progress. Taps open the matching task, Focus or Progress.

Share a web link or text to NoProcrastinate from another app. Save it to Inbox, then choose a start, deadline and focus duration. The task retains its source. Cancelling leaves it pending; deletion requires confirmation.

## Design

SwiftUI Views → ViewModels → Use Cases → StudyRepository → Core Data.

Core Data stores private, offline study records. StudyTask has many FocusSessions. The repository queries incomplete tasks with a start earlier than now. Views and ViewModels use domain values.

| Extension | Purpose |
| --- | --- |
| WidgetKit | Next task, focus countdown and today's progress on the Home Screen. |
| Share | Capture study links and text for task planning. |
| Device Activity Monitor | End focus restrictions without reopening the app. |

App Group: `group.com.drivenligret.NoProcrastinate`. The app and monitor coordinate access to the focus lease. The monitor releases restrictions when iOS delivers the end callback.

The app publishes a compact widget snapshot after successful saves and requests a timeline reload. The widget reads the App Group file; refresh timing is controlled by iOS.

The share extension writes one atomic Inbox file per resource before dismissing. Import saves through the repository before removing that file. Retrying uses the resource ID to prevent duplicate tasks.

## Setup

Open `NoProcrastinate.xcodeproj` in Xcode 16 or later. Select an iOS 17 or later simulator and run the `NoProcrastinate` scheme. Select your signing team for a device build.

Use the same signing team for the app and monitor. Register their App Group and enable Family Controls. In Supervision, authorize access, choose apps, then enable During focus. App limits require a signed physical iPhone; distribution requires Apple's Family Controls approval for both targets.

Use the same signing team and App Group for all extensions. Run the app once, then add NoProcrastinate from the Home Screen widget gallery. Choose NoProcrastinate in the system share sheet; it may appear under More.

The `NoProcrastinate` scheme runs mock-repository use-case tests, persistence and shared-file integration tests, and UI tests. GitHub Actions tests on a simulator and compiles for a device. Actual shielding and background release still require physical-device verification.

Repository: https://github.com/DrivenLigret/NoProcrastinate
