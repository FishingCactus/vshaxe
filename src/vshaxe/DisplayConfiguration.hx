package vshaxe;

import vscode.ExtensionContext;
import vscode.QuickPickItem;
import vscode.StatusBarItem;
import Vscode.*;

class DisplayConfiguration {
    var context:ExtensionContext;
    var statusBarItem:StatusBarItem;

    public function new(context:ExtensionContext) {
        this.context = context;

        fixIndex();

        statusBarItem = window.createStatusBarItem(Right);
        statusBarItem.tooltip = "Select Haxe configuration";
        statusBarItem.command = "haxe.selectDisplayConfiguration";
        context.subscriptions.push(statusBarItem);

        context.subscriptions.push(commands.registerCommand("haxe.selectDisplayConfiguration", selectConfiguration));

        context.subscriptions.push(workspace.onDidChangeConfiguration(onDidChangeConfiguration));
        context.subscriptions.push(window.onDidChangeActiveTextEditor(onDidChangeActiveTextEditor));

        updateStatusBarItem();
    }

    function fixIndex() {
        var index = getIndex();
        var configs = getConfigurations();
        if (configs == null || index >= configs.length)
            setIndex(0);
    }

    function selectConfiguration() {
        var configs = getConfigurations();
        if (configs == null || configs.length < 2)
            return;

        var items:Array<DisplayConfigurationPickItem> = [];
        for (index in 0...configs.length) {
            var args = configs[index];
            var label = args.join(" ");
            items.push({
                label: "" + index,
                description: label,
                index: index,
            });
        }

        window.showQuickPick(items, {placeHolder: "Select haxe display configuration"}).then(function(choice:DisplayConfigurationPickItem) {
            if (choice == null || choice.index == getIndex())
                return;
            setIndex(choice.index);
            updateStatusBarItem();
        });
    }

    function onDidChangeConfiguration(_) {
        fixIndex();
        updateStatusBarItem();
    }

    function onDidChangeActiveTextEditor(_) {
        updateStatusBarItem();
    }

    function updateStatusBarItem() {
        if (window.activeTextEditor == null) {
            statusBarItem.hide();
            return;
        }

        if (languages.match({language: 'haxe', scheme: 'file'}, window.activeTextEditor.document) > 0) {
            var configs = getConfigurations();
            if (configs != null && configs.length >= 2) {
                var index = getIndex();
                statusBarItem.text = '$(gear) Haxe: $index (${configs[index].join(" ")})';
                statusBarItem.show();
                return;
            }
        }

        statusBarItem.hide();
    }

    inline function getConfigurations():Array<Array<String>> {
        return workspace.getConfiguration("haxe").get("displayConfigurations");
    }

    public inline function getIndex():Int {
        return context.workspaceState.get("haxe.displayConfigurationIndex", 0);
    }

    inline function setIndex(index:Int) {
        context.workspaceState.update("haxe.displayConfigurationIndex", index);
        onDidChangeIndex(index);
    }

    public dynamic function onDidChangeIndex(index:Int):Void {}
}

private typedef DisplayConfigurationPickItem = {
    >QuickPickItem,
    var index:Int;
}