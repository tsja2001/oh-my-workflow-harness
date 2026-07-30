#!/usr/bin/env node
// Bound and redact text returned by internal read-only probes.

"use strict";

const mode = process.argv[2] || "redact";
let input = "";

process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
  input += chunk;
});
process.stdin.on("end", () => {
  if (mode === "keys") {
    process.stdout.write(extractKeys(input));
    return;
  }
  if (mode === "errors") {
    const matched = input
      .split(/\r?\n/)
      .filter((line) =>
        /(\b(ERROR|WARN|FATAL|FAILED|FAILURE|CRASHLOOPBACKOFF|UNHEALTHY|TIMEOUT|FORBIDDEN|UNAUTHORIZED|OOMKILLED)\b|Exception(?::|\s)|Caused by:|connection refused|timed out|no such|not found|cannot|could not|back-?off)/i.test(
          line,
        ),
      );
    input = collapseErrorLines(matched);
  }
  process.stdout.write(redact(input));
});

function isSecretKey(key) {
  return /(password|passwd|pwd|secret|token|authorization|cookie|cred(?:ential|id)?|creid|access[-_.]?key|private[-_.]?key|client[-_.]?secret)/i.test(
    key,
  );
}

function redact(text) {
  let output = text;

  output = output.replace(
    /([a-z][a-z0-9+.-]*:\/\/)([^/\s:@]+):([^@\s/]+)@/gi,
    "$1[REDACTED]:[REDACTED]@",
  );
  output = output.replace(
    /\b(Bearer|Basic)\s+[A-Za-z0-9+/._=-]+/gi,
    "$1 [REDACTED]",
  );
  output = output.replace(
    /\b[A-Za-z0-9_-]{18,}\.[A-Za-z0-9_-]{18,}\.[A-Za-z0-9_-]{18,}\b/g,
    "[REDACTED_JWT]",
  );
  output = output.replace(
    /([?&](?:token|access_token|password|passwd|pwd|secret|signature)=)[^&#\s]*/gi,
    "$1[REDACTED]",
  );
  output = output.replace(
    /((?:password|passwd|pwd|secret|token|authorization|cookie|credential|creid|access[-_.]?key|private[-_.]?key|client[-_.]?secret)\s*[:=]\s*)([^\s,;}\]]+)/gi,
    "$1[REDACTED]",
  );
  output = output.replace(
    /("[^"]*(?:password|passwd|pwd|secret|token|authorization|cookie|credential|creid|access[-_.]?key|private[-_.]?key|client[-_.]?secret)[^"]*"\s*:\s*)("(?:\\.|[^"])*"|[^,}\s]+)/gi,
    '$1"[REDACTED]"',
  );
  output = output.replace(
    /(CurrentUserResolverHandler[^\r\n]*?\buser:)[^,\r\n]*/gi,
    "$1[REDACTED_USER]",
  );
  output = output.replace(
    /(CurrentUserResolverHandler[^\r\n]*?\bbody:).*?(,queryString:|$)/gi,
    "$1[REDACTED_BODY]$2",
  );

  output = output
    .split(/\r?\n/)
    .map((line) => {
      const yaml = line.match(
        /^(\s*(?:-\s*)?["']?([^"'=:]+?)["']?\s*:\s*)(.*)$/,
      );
      if (yaml && isSecretKey(yaml[2])) {
        return `${yaml[1]}[REDACTED]`;
      }

      const property = line.match(/^(\s*([^#=\s][^=]*?)\s*=\s*)(.*)$/);
      if (property && isSecretKey(property[2])) {
        return `${property[1]}[REDACTED]`;
      }

      const json = line.match(/^(\s*"([^"]+)"\s*:\s*)(.*?)(,?\s*)$/);
      if (json && isSecretKey(json[2])) {
        return `${json[1]}"[REDACTED]"${json[4]}`;
      }
      return line;
    })
    .join("\n");

  return output;
}

function collapseErrorLines(lines) {
  const kept = [];
  const seen = new Map();

  for (const line of lines) {
    const signature = line
      .replace(/^\S+Z\s+/, "")
      .replace(
        /^\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}(?:\.\d+)?\s+/,
        "",
      )
      .replace(/@[0-9a-f]{6,}/gi, "@#")
      .replace(/-?\d{5,}/g, "#");

    const existing = seen.get(signature);
    if (existing) {
      existing.count += 1;
      continue;
    }
    const record = { line, count: 1 };
    seen.set(signature, record);
    kept.push(record);
  }

  const output = [];
  for (const record of kept.slice(0, 120)) {
    output.push(record.line);
    if (record.count > 1) {
      output.push(`[同类日志重复 ${record.count} 次，已折叠]`);
    }
  }
  if (kept.length > 120) {
    output.push(`[另有 ${kept.length - 120} 类错误行未输出]`);
  }
  return output.join("\n");
}

function extractKeys(text) {
  const trimmed = text.trim();
  if (!trimmed) {
    return "";
  }

  try {
    const parsed = JSON.parse(trimmed);
    const keys = new Set();
    walkJson(parsed, "", keys);
    return `${[...keys].sort().join("\n")}\n`;
  } catch (_error) {
    // Nacos commonly stores YAML or .properties. Fall through.
  }

  const keys = new Set();
  const stack = [];

  for (const originalLine of text.split(/\r?\n/)) {
    if (!originalLine.trim() || /^\s*[#!]/.test(originalLine)) {
      continue;
    }

    const property = originalLine.match(/^\s*([A-Za-z0-9_.-]+)\s*=/);
    if (property) {
      keys.add(property[1]);
      continue;
    }

    const yaml = originalLine.match(
      /^(\s*)(?:-\s*)?["']?([A-Za-z0-9_.-]+)["']?\s*:(?:\s*(.*))?$/,
    );
    if (!yaml) {
      continue;
    }

    const indent = yaml[1].replace(/\t/g, "  ").length;
    const key = yaml[2];
    while (stack.length && stack[stack.length - 1].indent >= indent) {
      stack.pop();
    }
    const path = [...stack.map((item) => item.key), key].join(".");
    keys.add(path);

    const value = (yaml[3] || "").trim();
    if (!value || value === "|" || value === ">") {
      stack.push({ indent, key });
    }
  }

  return `${[...keys].sort().join("\n")}\n`;
}

function walkJson(value, prefix, keys) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return;
  }
  for (const [key, child] of Object.entries(value)) {
    const path = prefix ? `${prefix}.${key}` : key;
    keys.add(path);
    walkJson(child, path, keys);
  }
}
