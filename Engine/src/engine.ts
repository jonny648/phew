// Phew's helper: runs one self-made skill and exits. Started by Swift (Phew/Brain/SkillBox.swift) under a macOS
// sandbox profile with no network, no file writes and no child programs. That profile is the lock; nothing in this
// file is one. The skill gets text and returns text. One request on stdin, one answer on stdout, both JSON.
import { readFileSync } from "node:fs";
import vm from "node:vm";

export interface Request {
  /** JavaScript that defines `function run(input)`, returning text. */
  code: string;
  input: string;
  /** Upper limit for the run, in milliseconds. Swift kills the process a little later whatever happens here. */
  ms?: number;
}

export interface Answer {
  ok: boolean;
  output?: string;
  error?: string;
}

export function runSkill(request: Request): Answer {
  try {
    // A fresh context: the language's own objects only. No `process`, `require`, `fetch`, timers or console.
    const context = vm.createContext({ input: String(request.input) }, { codeGeneration: { strings: false, wasm: false } });
    const out: unknown = vm.runInContext(`${request.code}\n;run(input)`, context, { timeout: request.ms ?? 4000 });
    if (typeof out !== "string") return { ok: false, error: "The skill did not return text." };
    return { ok: true, output: out };
  } catch (error) {
    // An error thrown inside the context comes from another realm: `instanceof Error` would say no.
    const message = (error as { message?: unknown } | null)?.message;
    return { ok: false, error: String(message ?? error).slice(0, 300) };
  }
}

// Swift hands this file to Node as text (`node -e`), so no file is read: then there is no main module.
if (require.main === module || require.main === undefined) {
  let answer: Answer;
  try {
    answer = runSkill(JSON.parse(readFileSync(0, "utf8")) as Request);
  } catch {
    answer = { ok: false, error: "The request could not be read." };
  }
  process.stdout.write(JSON.stringify(answer) + "\n");
}
