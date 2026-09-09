# CLAUDE.md

Guidelines for AI-assisted development.

## 1. Think Before Coding

Understand the task before changing code.

* State important assumptions.
* If the request is ambiguous in a way that affects the implementation, ask.
* Prefer the simplest interpretation that satisfies the goal.
* Surface relevant tradeoffs instead of silently choosing a complex approach.

For multi-step tasks, briefly state the plan and how you will verify success.

## 2. Keep It Simple

Write the minimum code needed to solve the requested problem.

* Do not add features that were not requested.
* Avoid unnecessary abstractions or configurability.
* Prefer clear, direct code over clever code.
* Reuse existing project patterns before introducing new ones.

If a small solution works, do not build a framework.

## 3. Make Surgical Changes

When modifying existing code, change only what is necessary.

* Do not refactor unrelated code.
* Match the repository's existing style and structure.
* Do not clean up unrelated comments, formatting, or dead code.
* Remove imports or code made unused by your own changes.

Every changed line should have a clear reason tied to the task.

## 4. Build in Verifiable Steps

Turn requests into concrete outcomes and verify them.

Examples:

* Bug fix → reproduce the bug, fix it, confirm it no longer occurs.
* New feature → define expected behavior, implement it, test it.
* Refactor → confirm behavior is unchanged before and after.

Run the most relevant tests, checks, or example workflow available in the repository.

Do not claim something works if you have not verified it.

## 5. Optimize for Workshop Iteration

This repository is used for hands-on workflow building.

* Treat the README as the source of truth for project goals and scope.
* Prefer small, runnable increments.
* Keep examples easy to inspect and modify.
* Suggest a commit after each small, working increment so changes are easy to inspect, compare, and revert. Only create commits when explicitly requested.
* Update the README and .gitignore as the project evolves.
* Document important implementation decisions and briefly explain non-obvious choices.
* When something fails, diagnose the cause before adding workarounds.
* Preserve intermediate functionality so users can experiment after each step.
* Do not add functionality outside the stated scope unless requested.

The goal is not only to produce working code, but code that is understandable, inspectable, and extendable.
