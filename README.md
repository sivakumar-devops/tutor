# TNPSC Group 4 AI Tutor

A responsive, single-file frontend prototype for a TNPSC Group 4 learning workspace. Open **`index.html`** directly in a browser. No installation, build step, dev server, API key or database is required.

## Frontend

- Persistent top navigation, collapsible sidebar with a streamlined Workspace group, Syllabus Details and Previous-Year Questions groups, account menu, notifications, light and dark themes.
- Personal dashboard with a command-center layout: today's focus action, exam readiness score, AI study coach recommendation, locally recorded learning goals, topic completion, mock results and revision priorities.
- Tamil, General Studies and Aptitude in priority order, with topic-specific inline tutor conversations and a guided study journey.
- Current Affairs remains reachable inside General Studies under Syllabus Details, and Previous-Year Questions remains reachable through Full Year Papers and Syllabus-wise Questions.
- Mock tests, weekly contest previews, user profile, login and payment preview screens.
- Community with For You, Discussions, Study Circles and Achievements tabs.

## Guided Learning

On Syllabus Tutor, **Start learning with AI** begins the first guided lesson in Tamil Grammar. Returning learners see **Continue learning with AI** and resume their saved plan. The sequence covers 16 learning topics: the 15 syllabus units plus an integrated Current Affairs lesson, in Tamil, General Studies and Aptitude order. Current Affairs is taught at the end of General Studies, before Aptitude. The inline **Study plan** also allows direct topic selection. Existing saved lessons remain intact; learners who previously finished all 15 lessons can continue with Current Affairs.

All AI Tutor surfaces now use the same compact learning layout. The Syllabus Tutor uses a centered ChatGPT-style transcript, subtle AI/student message styling and a bottom-centered composer, matching the Previous-Year Questions tutor pattern. The topic, progress, language, completion state, audio action, study-plan/support toggle and **Focus** control sit in concise header rows. Supplementary panels are collapsed by default, can be reopened, and automatically collapse after a lesson or PYQ practice session starts. Focus Mode hides the sidebar and supporting panels while keeping the tutor conversation and input visible. Focus and support-panel preferences are stored locally under `tnpsc-tutor-focus` and `tnpsc-tutor-support`.

Each syllabus card opens a topic conversation with **Learn topic**. Inside the chat, **Start this topic** begins teaching without requiring a typed question. A lesson progresses through a concept, worked example, multiple-choice knowledge check and recap. Incorrect answers can be retried or reviewed. Passing the check unlocks the recap; only the learner's explicit **Complete topic** action marks the topic studied. **Next topic** continues the journey, and **Review this topic** revisits a completed lesson without erasing previous completion.

The always-visible **Current Affairs** entry under **Syllabus Details** opens its own inline welcome conversation. Its syllabus card uses **Start learning** to open the same conversation; **Start this topic** begins the introductory English/Tamil lesson using the archived SpaDeX docking event as a worked example. Current Affairs is labeled **Within GS**, has no independent question allocation, and is counted as a learning topic within General Studies rather than a fourth exam subject. The exam distribution remains Tamil 100, General Studies 75, Aptitude 25. The Workspace Current Affairs archive link is unchanged.

The application-level header language selector supports Tamil and English only. The selected language applies across navigation, tutor pages, questions, explanations and instructions, persists locally under `tnpsc-app-language`, and falls back to English wherever a Tamil string has not yet been authored. The usual chat and voice controls remain available for questions. Topic conversations, drafts and lesson progress are stored locally under `tnpsc-tutor-conversations-v1` and `tnpsc-guided-v1`. Quick checks do not create mock scores or contest results.

These are representative, scripted introductory lessons for demonstrating the complete frontend workflow, not exhaustive coverage of every syllabus subtopic or an adaptive LLM course. Production lesson content, mastery checks, authenticated cross-device progress and real AI teaching require backend integration and academic review.

## Community

- Follow subjects, search posts, filter unanswered or accepted discussions, and save posts.
- Publish questions or achievements in Tamil or English, recover drafts, reply, mark helpful contributions and accept answers on your own discussions.
- Join or leave study circles, post to joined circles and check in once per local calendar day.
- Join a five-day revision challenge with one self-reported check-in per day. Completing it does not automatically publish an achievement.
- Share milestones only with explicit consent. Attached scores are hidden by default and can only be attached from an existing local mock attempt after opting in.
- Preview public profiles, control bio visibility, hide attached scores, block members, report posts and restore locally hidden content.
- Spoiler-marked contest discussions stay concealed until revealed. Sample instructor explanations are labeled as examples, not live verification.

Sample members and activity are fictional and labeled. Community actions are stored in `localStorage` on the current browser under `tnpsc-community-v1`. They do not alter private dashboard results or the contest scoreboard. Stored data is not synced across devices, browsers, or different origins. Drafts and test data should not contain sensitive information.

## Current Affairs and Previous-Year Questions

**Current Affairs** (`#affairs`) includes six dated, source-linked historical briefs, English and Tamil summaries, revision notes, month/topic/search filters, saved briefs, explicit read markers, individual knowledge checks and monthly revision quizzes. Monthly results distinguish correct, incorrect and unanswered questions. Items cover January 2024 through April 2025 and are labeled as a curated archive, not a current or live news feed. Sources are ISRO and India's Press Information Bureau, linked on each brief.

**Previous-Year Questions** (`#previous-years`) now opens as an embedded AI Tutor workspace instead of a direct paper list. The two visible study paths are **Full-Year Papers** and **Syllabus-wise Questions**. Both use the same ChatGPT-style centered conversation layout with a compact Teaching/Practice mode switch, subtle tutor/student message styling, quick-choice chips below the relevant tutor message, a vertically scrollable transcript and a bottom-centered composer with microphone, speaker and send controls. Full-Year Papers opens in Teaching Mode by default, asks which year the learner wants, and accepts either the year buttons or a typed year in the message box.

Both PYQ paths support **Practice Mode** and **Teaching Mode**. Practice Mode runs questions sequentially with answer selection, previous/next movement and an end-of-session summary. Teaching Mode reveals step-by-step explanation, a shortcut or memory hook and the correct answer discussion. The embedded tutor also accepts typed follow-up questions and includes browser speech input/output controls.

**Syllabus-wise Questions** opens the same stripped-down embedded tutor as a conversational flow. The tutor asks for the question-paper year, then the syllabus area, then runs in Teaching Mode by default while allowing Practice Mode at any time. The only syllabus choices shown are Tamil, General Studies, and Aptitude and Mental Ability; Current Affairs is handled inside General Studies. The current prototype offers eight **original sample questions**, not transcribed or verified PYQs. Each sample is explicitly labeled and has no invented exam year or official question number. Importing a verified, licensed past-paper question bank with original year and question-number metadata remains backend/content work.

Below Syllabus Details, the separate **Previous-Year Questions** sidebar group now provides only **Full-Year Papers** and **Syllabus-Wise Questions**. The right-side PYQ practice/classification panels were removed so the embedded AI Tutor can use the full available width. The selection, year and learning mode are reflected in the URL for reloads and browser history. Current Affairs syllabus-card **Practice** opens Syllabus-wise Questions through General Studies because Current Affairs is not a separate exam subject. Both lower sidebar groups share one scroll area and are hidden together when the sidebar is minimized.

Current Affairs remains part of General Studies, consistent with the [official TNPSC syllabus, Code 496](https://www.tnpsc.gov.in/static_pdf/syllabus/496_Group%20IV%20Syllabus.pdf). Questions use a primary `subject` and optional Current Affairs `tag`. The same question ID is shared between the General Studies and Current Affairs filters; progress is never summed across overlapping filters.

Saved items, read markers and checked answers are validated and stored locally under `tnpsc-resources-v1`. First-try accuracy retains the first checked outcome even after a retry; unique-question counts do not grow on repeated attempts. Monthly quiz sessions and active filters are kept in memory. Archive reading and practice detail pages contribute active study time; preview answers never create official scores, mock attempts, contest results or completed syllabus topics.

Contextual discussions reuse the inline tutor, the app-wide language preference, browser audio controls, conversation persistence and a return button to the originating page. These discussions use scripted source-based summaries or sample explanations, not live LLM answers. A live news pipeline, licensed and academically reviewed PYQ ingestion, authenticated progress sync and AI services are not connected.

## Prototype Boundaries

This is a frontend design and interaction prototype, not a production service. AI replies are sample responses. Speech input/output depends on browser support and microphone permission; a browser's speech service may require internet access. Authentication, payments, shared community data, moderation, verified results and real AI responses require backend integration. No real payment is processed, no moderation report is transmitted, and no working account is created by the preview screens. Do not enter real passwords or payment details.

All frontend assets, styles and scripts are embedded in `index.html`, including the existing attributed Lucide icons. No remote fonts, scripts or image assets are loaded. A local browser file works for the interface; HTTPS hosting is preferable for testing microphone permissions.

## Repository Contents

```text
index.html                                Complete frontend prototype
README.md                                 Project notes
.gitignore                                Excludes temporary/local files
database/
  tnpsc_ai_tutor.sql                       Initial MySQL 8.4 schema
  tnpsc_ai_tutor_test_data.sql              Optional development fixtures
  README.md                               Database setup and model notes
```

The database files are optional backend design deliverables and are not connected to the HTML. The existing 37-table schema and seed data predate Community and the resource pages. Community, current-affairs publishing, PYQ provenance and related backend migrations/services have not been added in these frontend updates.

## GitHub

The repository-root `index.html` is ready to serve as a static site, including through GitHub Pages. There are no generated bundles or dependencies to upload. Commit the files above to your repository; database fixtures are fictional development data, not production records. No GitHub remote has been configured and no repository has been pushed from this workspace.

## Verification

Browser checks completed on 2026-09-14 covered the new Community workflows, persisted state, explicit sharing consent, score privacy, escaped user content, report/block restoration, spoiler protection, keyboard tabs and dialogs, and responsive layouts at 320, 390, 768, 1024 and 1440 pixels in both themes. Existing navigation, dashboard and tutor regression checks also passed. Temporary verification scripts and screenshots were removed from the final deliverable as requested.

The initial guided-learning update was tested through all 15 core syllabus lessons, ordered progression, direct topic entry, correct/incorrect answer handling, explicit completion, full-course completion and review, saved resume and drafts, delayed-reply isolation, all three language modes, the same five viewport widths in both themes, existing page navigation and unavailable-browser-storage fallback.

The resource-page update was browser-tested on 2026-09-14 at 320, 390, 768, 1024 and 1440 pixels in light and dark themes. Checks covered all eight sample practice questions and six archive quizzes, correct/incorrect feedback, retries and first-try accuracy, partial monthly quiz results, bookmarks/read markers, subject/year/month/topic/status/search filters, reload persistence, overlapping-subject deduplication, isolated page state, direct tutor links, keyboard focus and tabs, unique DOM IDs, unavailable storage, and existing navigation/guided-learning regression checks. Audio handoff was checked with a speech-synthesis stub; real microphone capture and audible playback were not tested. Screenshots were visually inspected and temporary validation files removed.

The common AI Tutor layout update was browser-tested on 2026-09-15. Checks covered the compact syllabus/current-affairs tutor shell, the PYQ tutor shell, default-collapsed support panels, manual support expansion persistence, automatic collapse after lesson/practice start, Focus Mode persistence across tutor pages, sidebar/support hiding in Focus Mode, scrollable conversation areas, fixed bottom inputs, PYQ Practice and Teaching modes, typed tutor replies, URL state and mobile responsiveness.

The PYQ tutor update was browser-tested on 2026-09-15. Checks covered Full Year Papers rendering as an embedded AI Tutor, removal of the direct paper-list view, the two visible PYQ tabs, expandable syllabus-wise sidebar group, subject shortcuts, year dropdown/manual-year handling, Practice and Teaching modes, question progression, teaching explanations, typed tutor replies, URL state, and mobile layout. Temporary test files and screenshots were removed after inspection.

The app-wide language update was browser-tested on 2026-09-15. Checks covered the header-level Tamil/English selector, removal of page-level bilingual tutor choices, local preference persistence after reload, Tamil navigation/sidebar/PYQ tutor rendering, Tamil syllabus tutor replies, English fallback switching, and absence of the removed `Tamil + English` option.
#   t u t o r 

# prompt
Remove the **Syllabus Details** section from the application sidebar. Its subject and topic navigation duplicates the filters and topic cards already available on the **Syllabus Tutor** page.

Keep syllabus browsing and topic selection within Syllabus Tutor. Students should still be able to search topics, filter by Tamil, General Studies, or Aptitude, and continue their current lesson.

After removing the section, use the freed sidebar space to make the primary navigation easier to scan. Check that links to the syllabus tutor and previous-year question pages remain easy to find on desktop and mobile.

 
 
