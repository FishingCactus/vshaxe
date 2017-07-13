package vshaxe.display;

class HaxeDisplayArgumentsProvider {
    var context:ExtensionContext;
    var statusBarItem:StatusBarItem;
    var provideArguments:Array<String>->Void;

    public var description(default,never):String = "built-in, using haxe.displayConfigurations";

    public function new(context:ExtensionContext, api:Vshaxe) {
        this.context = context;

        statusBarItem = window.createStatusBarItem(Left, 4);
        statusBarItem.tooltip = "Select Haxe configuration";
        statusBarItem.command = SelectDisplayConfiguration;
        context.subscriptions.push(statusBarItem);

        context.registerHaxeCommand(SelectDisplayConfiguration, selectConfiguration);

        context.subscriptions.push(workspace.onDidChangeConfiguration(onDidChangeConfiguration));
        context.subscriptions.push(window.onDidChangeActiveTextEditor(onDidChangeActiveTextEditor));

        fixIndex();
        updateStatusBarItem();
        api.registerDisplayArgumentsProvider("Haxe", this);
    }

    public function activate(provideArguments) {
        this.provideArguments = provideArguments;
        provideArguments(getConfiguration());
    }

    public function deactivate() {
        this.provideArguments = null;
    }

    function fixIndex() {
        var index = getIndex();
        var configs = getConfigurations();
        if (configs == null || index >= configs.length)
            setIndex(0);
    }

    function selectConfiguration() {
        var configs = getConfigurations();
        if (configs == null || configs.length == 0) {
            window.showErrorMessage("No Haxe display configurations are available. Please provide the haxe.displayConfigurations setting.", ({title: "Edit settings"} : vscode.MessageItem)).then(function(button) {
                if (button == null)
                    return;
                workspace.openTextDocument(workspace.rootPath + "/.vscode/settings.json").then(function(doc) window.showTextDocument(doc));
            });
            return;
        }
        if (configs.length == 1) {
            window.showInformationMessage("Only one Haxe display configuration found: " + configs[0].join(" "));
            return;
        }

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

        window.showQuickPick(items, {matchOnDescription: true, placeHolder: "Select Haxe display configuration"}).then(function(choice:DisplayConfigurationPickItem) {
            if (choice == null || choice.index == getIndex())
                return;
            setIndex(choice.index);
        });
    }

    function onDidChangeConfiguration(_) {
        fixIndex();
        updateStatusBarItem();
        notifyConfigurationChange();
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
                statusBarItem.text = configs[index].join(" ");
                statusBarItem.show();
                return;
            }
        }

        statusBarItem.hide();
    }

    inline function getConfigurations():Array<Array<String>> {
        return workspace.getConfiguration("haxe").get("displayConfigurations");
    }

    public inline function getConfiguration():Array<String> {
        return getConfigurations()[getIndex()];
    }

    public inline function getIndex():Int {
        return context.workspaceState.get("haxe.displayConfigurationIndex", 0);
    }

    function setIndex(index:Int) {
        context.workspaceState.update("haxe.displayConfigurationIndex", index);
        updateStatusBarItem();
        notifyConfigurationChange();
    }

    inline function notifyConfigurationChange() {
        if (provideArguments != null)
            provideArguments(getConfiguration());
    }
}

private typedef DisplayConfigurationPickItem = {
    >QuickPickItem,
    var index:Int;
}
