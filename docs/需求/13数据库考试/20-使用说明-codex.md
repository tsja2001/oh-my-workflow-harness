# MySQL CSV 导入导出脚本使用说明

- 日期：2026-08-14
- 工具：codex
- 当前状态：脚本已实现，凭据已迁移到受 Git 忽略保护的 `ai-docs/creds.env`。
- 下一步：考试时提供数据库名、表名和 CSV 路径，由 AI 运行脚本并核对结果。

## 脚本位置

```text
docs/需求/13数据库考试/mysql-csv.sh
```

## 三条命令

在工作区根目录 `/home/t/projects/work-wsl` 执行：

```bash
# 只检查数据库连接和 CSV 导入开关
bash docs/需求/13数据库考试/mysql-csv.sh test

# CSV 导入已经存在的 MySQL 表
bash docs/需求/13数据库考试/mysql-csv.sh import <数据库名> <表名> <CSV文件>

# 指定表完整导出为 CSV
bash docs/需求/13数据库考试/mysql-csv.sh export <数据库名> <表名> <CSV文件>
```

导出目标已经存在时，脚本默认停止，确认覆盖后在最后增加 `--force`：

```bash
bash docs/需求/13数据库考试/mysql-csv.sh export <数据库名> <表名> <CSV文件> --force
```

WSL 路径和带引号的 Windows 路径都支持，例如：

```text
/mnt/c/Users/29455/Desktop/student.csv
C:\Users\29455\Desktop\student.csv
```

## 导入 CSV 的要求

1. 目标表必须已经存在，脚本不会擅自建表。
2. CSV 第一行必须是数据库真实字段名；顺序可以与 MySQL 表不同。
3. 保存格式选“CSV UTF-8（逗号分隔）”。
4. 脚本会在导入前检查每行列数和字段是否存在；数据库允许 `LOCAL INFILE` 时走高速导入，否则自动改用事务批量 `INSERT`，不需要管理员改配置。
5. 重复主键默认跳过并显示 MySQL 警告，不覆盖原有记录。
6. 导入结束要看 `before_rows`、`after_rows` 和警告，不能只看“命令执行成功”。

## 导出 CSV 的行为

- 导出指定表的全部字段和全部数据。
- 第一行自动写字段名。
- 逗号、双引号、中文和字段内换行会正确转义。
- `NULL` 写成空单元格。
- 文件带 UTF-8 BOM，可直接用 Excel 打开。

## 凭据位置

账号、密码、地址和端口只允许放在：

```text
ai-docs/creds.env
```

使用以下四个变量：

```text
MYSQL_EXAM_HOST
MYSQL_EXAM_PORT
MYSQL_EXAM_USER
MYSQL_EXAM_PASSWORD
```

该文件已被 Git 忽略。脚本不会把密码打印出来，也不会把密码放进命令参数。
