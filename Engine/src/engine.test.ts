import assert from "node:assert/strict";
import { test } from "node:test";
import { runSkill } from "./engine";

test("a skill gets text and returns text", () => {
  const code = "function run(input) { return input.split(',').map(Number).reduce((a, b) => a + b, 0).toString(); }";
  assert.deepEqual(runSkill({ code, input: "1,2,39" }), { ok: true, output: "42" });
});

test("a skill sees none of Node", () => {
  // `console` exists in every V8 context and writes nowhere here, so it is not in the list.
  for (const name of ["process", "require", "module", "fetch", "setTimeout", "globalThis.process", "Buffer"]) {
    const answer = runSkill({ code: `function run() { return typeof ${name}; }`, input: "" });
    assert.deepEqual(answer, { ok: true, output: "undefined" }, name);
  }
});

test("code made from text is refused", () => {
  const answer = runSkill({ code: "function run() { return String(eval('1+1')); }", input: "" });
  assert.equal(answer.ok, false);
});

test("an endless loop ends at the limit", () => {
  const started = Date.now();
  const answer = runSkill({ code: "function run() { for (;;) {} }", input: "", ms: 200 });
  assert.equal(answer.ok, false);
  assert.ok(Date.now() - started < 2000);
});

test("anything but text is an error, and so is a throw or no run function", () => {
  assert.equal(runSkill({ code: "function run() { return 42; }", input: "" }).ok, false);
  assert.equal(runSkill({ code: "function run() { throw new Error('made up'); }", input: "" }).error, "made up");
  assert.equal(runSkill({ code: "const x = 1;", input: "" }).ok, false);
});
