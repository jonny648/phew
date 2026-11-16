"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.runSkill = runSkill;
// Phew's helper: runs one self-made skill and exits. Started by Swift (Phew/Brain/SkillBox.swift) under a macOS
// sandbox profile with no network, no file writes and no child programs. That profile is the lock; nothing in this
// file is one. The skill gets text and returns text. One request on stdin, one answer on stdout, both JSON.
const node_fs_1 = require("node:fs");
const node_vm_1 = __importDefault(require("node:vm"));
const outsideHeap = [
    "ArrayBuffer", "SharedArrayBuffer", "DataView", "WebAssembly", "Atomics", "Int8Array", "Uint8Array", "Uint8ClampedArray",
    "Int16Array", "Uint16Array", "Int32Array", "Uint32Array", "Float16Array", "Float32Array", "Float64Array", "BigInt64Array",
    "BigUint64Array",
];
function runSkill(request) {
    try {
        // A fresh context: the language's own objects only. No `process`, `require`, `fetch`, timers or console.
        // The object behind the context has no prototype: with one, `this.constructor.constructor` would be the outer
        // Function and hand out `process`. The input goes in as plain text, so nothing of the outer realm is reachable.
        const sandbox = Object.create(null);
        sandbox.input = String(request.input);
        const context = node_vm_1.default.createContext(sandbox, { codeGeneration: { strings: false, wasm: false } });
        // Memory outside the JavaScript heap is not under Node's heap limit: take away the ways to ask for it.
        // Swift watches the process's real memory as well and ends it; that is the lock, this is the first fence.
        node_vm_1.default.runInContext(`for (const name of ${JSON.stringify(outsideHeap)}) delete globalThis[name];`, context);
        const out = node_vm_1.default.runInContext(`${request.code}\n;run(input)`, context, { timeout: request.ms ?? 4000 });
        if (typeof out !== "string")
            return { ok: false, error: "The skill did not return text." };
        return { ok: true, output: out };
    }
    catch (error) {
        // An error thrown inside the context comes from another realm: `instanceof Error` would say no.
        const message = error?.message;
        return { ok: false, error: String(message ?? error).slice(0, 300) };
    }
}
// Swift hands this file to Node as text (`node -e`), so no file is read: then there is no main module.
if (require.main === module || require.main === undefined) {
    let answer;
    try {
        answer = runSkill(JSON.parse((0, node_fs_1.readFileSync)(0, "utf8")));
    }
    catch {
        answer = { ok: false, error: "The request could not be read." };
    }
    process.stdout.write(JSON.stringify(answer) + "\n");
}
