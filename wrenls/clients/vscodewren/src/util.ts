import * as lc from "vscode-languageclient/node";
import * as vscode from "vscode";
import { strict as nativeAssert } from "assert";
import { exec, ExecOptions, spawnSync } from "child_process";
import { inspect } from "util";

export function assert(condition: boolean, explanation: string): asserts condition {
    try {
        nativeAssert(condition, explanation);
    } catch (err) {
        log.error(`Assertion failed:`, explanation);
        throw err;
    }
}

export const log = new class {
    public enabled = true;
    private readonly output = vscode.window.createOutputChannel("Wren Language Client");


    // Hint: the type [T, ...T[]] means a non-empty array
    debug(...msg: [unknown, ...unknown[]]): void {
        if (!log.enabled) {
            return; 
        }
        log.write("DEBUG", ...msg);
    }

    info(...msg: [unknown, ...unknown[]]): void {
        log.write("INFO", ...msg);
    }

    warn(...msg: [unknown, ...unknown[]]): void {
        debugger;
        log.write("WARN", ...msg);
    }

    error(...msg: [unknown, ...unknown[]]): void {
        debugger;
        log.write("ERROR", ...msg);
        log.output.show(true);
    }

    private write(label: string, ...messageParts: unknown[]): void {
        const message = messageParts.map(log.stringify).join(" ");
        const dateTime = new Date().toLocaleString();
        log.output.appendLine(`${label} [${dateTime}]: ${message}`);
    }

    private stringify(val: unknown): string {
        if (typeof val === "string") {
            return val;
        }
        return inspect(val, {
            colors: false,
            depth: 6, // heuristic
        });
    }
};

export function is_wren_document(document: vscode.TextDocument) {
    return document.languageId === 'wren' && document.uri.scheme === 'file';
}