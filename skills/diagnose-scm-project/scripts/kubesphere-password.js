#!/usr/bin/env node
// Encode the KubeSphere login password exactly as its web client expects.

"use strict";

let input = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
  input += chunk;
});
process.stdin.on("end", () => {
  const password = input.replace(/\r?\n$/, "");
  const key = "kubesphere";
  const raw = Buffer.from(password, "utf8").toString("base64");
  const seed =
    raw.length > key.length
      ? key + raw.slice(0, raw.length - key.length)
      : key.slice(0, raw.length);
  const bits = [];
  const chars = [];

  for (let index = 0; index < seed.length; index += 1) {
    const left = seed.charCodeAt(index);
    const right = index < raw.length ? raw.charCodeAt(index) : 64;
    const sum = left + right;
    bits.push(sum % 2 === 0 ? "0" : "1");
    chars.push(String.fromCharCode(Math.floor(sum / 2)));
  }

  process.stdout.write(
    `${Buffer.from(bits.join(""), "utf8").toString("base64")}@${chars.join("")}`,
  );
});
