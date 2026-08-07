# Jenkins 流水线 — 移除 SafeMode 后重建

> 日期：2026-08-01 | 工具：oc
> 当前状态：代码回滚已 staged，待用户提交 push 后执行。
> 目标：所有 22 个服务的 Dockerfile 已移除 SafeMode，需重建 test 环境让新 Dockerfile 进入镜像。
> 注意：SafeMode 只在 test 有，uat/prod 从未部署，无需处理。

---

## test 环境批量重建

新建 Pipeline 任务，贴下面脚本，点"立即构建"。

```groovy
pipeline {
    agent none

    options {
        disableConcurrentBuilds()
    }

    stages {
        stage('移除 SafeMode - 重建 test') {
            steps {
                script {
                    def jobs = [
                        'scm-auth-web-test',
                        'scm-gateway-web-test',
                        'scm-gateway-mall-web-test',
                        'scm-ifs-web-test',
                        'scm-ifs-schedule-web-test',
                        'scm-source-web-test',
                        'scm-order-web-test',
                        'scm-product-web-test',
                        'scm-srm-web-test',
                        'scm-contract-web-test',
                        'scm-report-web-test',
                        'scm-ubm-web-test',
                        'scm-ubm-mall-web-test',
                        'scm-file-web-test',
                        'scm-professor-web-test',
                        'scm-scheduling-web-test',
                        'scm-devops-web-test',
                        'scm-workflow-web-test',
                        'scm-fee-web-test',
                        'scm-dps-service-web-test',
                        'scm-dps-web-test',
                        'scm-dpscore-web-test'
                    ]

                    for (jobName in jobs) {
                        echo "开始重建：${jobName}"
                        build job: jobName, wait: true, propagate: true
                    }
                }
            }
        }
    }
}
```

- 22 个服务，顺序执行，一个失败则整条流水线停下。
- 网关（auth、gateway、gateway-mall）排在前面，避免业务服务无网关可用。

## UAT / Prod

**不需要处理** — SafeMode 从未合并到 uat 和 prod 分支，这两个环境的 Dockerfile 里本来就没有 `JAVA_TOOL_OPTIONS` 那行。回滚代码 merge 到 uat/prod 后也不用重建。

## 验证

任选一个服务进 Pod 确认：

```bash
tr '\0' '\n' </proc/1/environ | grep JAVA_TOOL_OPTIONS
```

预期输出为空（SafeMode 已移除）。如果还有 `-Dfastjson.parser.safeMode=true`，说明该服务没拉到新镜像。
