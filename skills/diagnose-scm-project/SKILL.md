---
name: diagnose-scm-project
description: Project-wide read-only diagnosis for the 招采 SCM workspace. Use when tracing an API or page to its owning module, checking whether a test/UAT release reached Jenkins and K8s, diagnosing a scheduled task from its exact database execution record, comparing Nacos configuration keys across environments, locating likely code and ownership, or investigating 404/502, empty data, failed jobs, stale images, CrashLoopBackOff, and environment drift without repeatedly logging into internal platforms.
---

# Diagnose SCM Project

## Goal

Start from the user's symptom, not from a platform. The project command resolves module names and collects the shortest useful evidence chain from code, Jenkins, K8s, Nacos, the scheduling database, and guarded browser sessions.

Run from the workspace root:

```bash
PROJECT="skills/diagnose-scm-project/scripts/project.sh"
bash "$PROJECT" doctor
```

The scripts load `ai-docs/creds.env` internally. Never print it, copy it, search its values, or source it with tracing enabled.

## Safety boundary

This skill is strictly read-only.

- Never trigger Jenkins builds, restart/scale/patch/delete K8s resources, enter a container, publish Nacos configuration, execute/enable/disable a task, or write MySQL/ES data.
- Never bypass `scripts/browser/readonly-guard.js`.
- Never expose cookies, browser storage, authorization headers, passwords, tokens, keys, or full unbounded logs.
- Never guess a production namespace or promote a test value into UAT/prod.
- If evidence points to a code/config/data mutation, stop and hand the work to `enterprise-dev-workflow`, or prepare exact UI steps for the user.

## Start with a scenario command

```bash
# What module owns an API, and where is its code?
bash "$PROJECT" trace api '/gateway/d/business/order/centralPurchaseStatistics/queryPage'

# What frontend owns a URL, and which files/API strings are involved?
bash "$PROJECT" trace page '/procurementScheme/index.html#/businessManagementLedgerJC/dailyPlanStatisticsLedger'

# Did a module release reach both Jenkins stages and K8s?
bash "$PROJECT" diagnose release uat order

# Does an API exist in code, and is its service running?
bash "$PROJECT" diagnose api uat '/d/business/order/centralPurchaseStatistics/queryPage'

# Is the running workload healthy?
bash "$PROJECT" diagnose runtime uat order

# What exactly failed in a test/UAT XXL-JOB execution?
bash "$PROJECT" diagnose task uat order 216

# Which Nacos key paths differ? Values are not dumped.
bash "$PROJECT" compare config order test uat

# Which files and recent commits are related to a symbol or feature?
bash "$PROJECT" ownership order centralPurchaseStatistics
```

Use `modules` or `module <名称/接口路径>` when resolution is unclear. The catalog is [references/modules.json](references/modules.json); update it only with verified project facts.

## Drop to a platform command only when needed

The scenario command intentionally keeps output compact. Use the low-level adapter for a missing detail:

```bash
PLATFORM="skills/diagnose-scm-project/scripts/platform.sh"

bash "$PLATFORM" k8s logs uat scm-order-web --since 3h --tail 10000 --match 'centralPurchase|methodHandler|ERROR'
bash "$PLATFORM" jenkins evidence scm-order-web-uat lastBuild
bash "$PLATFORM" nacos keys uat scm-order-web-uat.yaml common
bash "$PLATFORM" scheduling jobs uat --executor 6 --desc '集采' --status all
bash "$PLATFORM" docs search '部署'
```

Browser-backed commands are serialized per browser profile. Do not run Jenkins commands in parallel against the same profile; serialization prevents page-state races but parallel calls only add waiting.

For platform names, credentials, environments, and limitations, read [references/platform-index.md](references/platform-index.md). For decision trees, read only the relevant section of [references/scenarios.md](references/scenarios.md).

## Evidence rules

Use [references/evidence-rules.md](references/evidence-rules.md) when forming the conclusion. In brief:

1. Separate observed facts from inference.
2. Connect build → image → Pod → config → task → data only as far as the symptom requires.
3. Prefer the exact task database record over the scheduling list's “失败” summary.
4. “No rows in this window” is not “never ran”; “Jenkins green” is not “rollout succeeded”.
5. Report the deepest useful cause and a few identifying timestamps/IDs, not pages of logs.

Return:

```text
结论：
直接证据：
判断：
还缺的证据（如有）：
下一步（需要用户或运维执行的写操作，如有）：
```

## Extending the skill

Keep the layers separate:

- Add verified module/application/route mappings to `references/modules.json`.
- Add cross-platform scenario orchestration to `scripts/project.sh`.
- Add one narrowly scoped, read-only platform query to `scripts/platform.sh`; never add arbitrary URL/method passthrough.

Validate after any change:

```bash
bash -n skills/diagnose-scm-project/scripts/{project,platform}.sh
node --check skills/diagnose-scm-project/scripts/{safe-output,kubesphere-password}.js
jq empty skills/diagnose-scm-project/references/modules.json
```
