// The module 'vscode' contains the VS Code extensibility API
// Import the module and reference it with the alias vscode in your code below
import * as vscode from 'vscode';
import { register_commands } from "./commands";
import * as lc from 'vscode-languageclient/node';
import { ServerOptions } from 'https';

let client: lc.LanguageClient;

// This method is called when your extension is activated
// Your extension is activated the very first time the command is executed
export function activate(context: vscode.ExtensionContext) {

	// Use the console to output diagnostic information (console.log) and errors (console.error)
	// This line of code will only be executed once when your extension is activated
	console.log('Congratulations, your extension "wrenlsp" is now active!');

	vscode.window.showInformationMessage('Wren LSP Client is now active.');

	register_commands(context);

	// note(Dragos): these server options are for debugging purposes. We need a way to figure out this path. Probably a config file or a user-option
	let server_options: lc.ServerOptions = {
		command: 'c:/dev/wreno/wrenls.exe',
		args: [],
		options: {
			cwd: 'c:/dev/wreno',
		},
	};

	let client_options: lc.LanguageClientOptions = {
		documentSelector: [{scheme: 'file', language: 'odin'}],
		outputChannel: vscode.window.createOutputChannel("Wren Language Server"),
	};

	client = new lc.LanguageClient(
		'wrenls',
		'Wren Language Server Client',
		server_options,
		client_options,
	);

	client.setTrace(lc.Trace.Compact);
	client.start();
}

// This method is called when your extension is deactivated
export function deactivate() {
	vscode.window.showInformationMessage('Goodbye, wrenlsp!');
	client.stop();
}
