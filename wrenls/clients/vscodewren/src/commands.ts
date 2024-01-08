import * as vscode from 'vscode';

type Command = {
	name: string;
	callback: (...args: any[]) => any;
};

const COMMAND_PREFIX = "wrenls.";

const commands: Command[] = [
	{
		name    : "helloWorld",
		callback: cmd_hello_world,
	},
];


export function register_commands(context: vscode.ExtensionContext) {
	commands.forEach((command, index) => {
		let disposable = vscode.commands.registerCommand(COMMAND_PREFIX + command.name, command.callback);
		context.subscriptions.push(disposable);
	});
}

function cmd_hello_world(...args: any[]): any {
	vscode.window.showInformationMessage('Hello there. WrenLS is active.');
}