package vshaxe.dependencyExplorer;

import haxe.io.Path;
import Vscode.*;
import vscode.*;
import js.Promise;
import vshaxe.dependencyExplorer.DependencyResolver;
import vshaxe.dependencyExplorer.HxmlParser;
import vshaxe.helper.PathHelper;
using Lambda;
using vshaxe.helper.ArrayHelper;

class DependencyExplorer {
    var context:ExtensionContext;
    var displayArguments:Array<String>;
    var relevantHxmls:Array<String> = [];
    var dependencyNodes:Array<Node> = [];
    var dependencies:DependencyList;
    var refreshNeeded:Bool = true;
    var haxePath:String;

    var _onDidChangeTreeData = new EventEmitter<Node>();

    public var onDidChangeTreeData:Event<Node>;

    public function new(context:ExtensionContext, displayArguments:Array<String>) {
        this.context = context;
        this.displayArguments = displayArguments;

        onDidChangeTreeData = _onDidChangeTreeData.event;
        window.registerTreeDataProvider("haxe.dependencies", this);
        commands.registerCommand("haxe.dependencies.selectNode", selectNode);
        commands.registerCommand("haxe.dependencies.collapseAll", collapseAll);
        commands.registerCommand("haxe.dependencies.refresh", refresh);

        var hxmlFileWatcher = workspace.createFileSystemWatcher("**/*.hxml");
        context.subscriptions.push(hxmlFileWatcher.onDidCreate(onDidChangeHxml));
        context.subscriptions.push(hxmlFileWatcher.onDidChange(onDidChangeHxml));
        context.subscriptions.push(hxmlFileWatcher.onDidDelete(onDidChangeHxml));
        context.subscriptions.push(hxmlFileWatcher);

        context.subscriptions.push(workspace.onDidChangeConfiguration(onDidChangeConfiguration));
        context.subscriptions.push(window.onDidChangeActiveTextEditor(onDidChangeActiveTextEditor));
        haxePath = getHaxePath();
    }

    function onDidChangeHxml(uri:Uri) {
        for (hxml in relevantHxmls) {
            if (Path.normalize(uri.fsPath) == Path.normalize(hxml)) {
                refresh(false);
            }
        }
    }

    function onDidChangeConfiguration(_) {
        if (haxePath != getHaxePath()) {
            haxePath = getHaxePath();
            refresh();
        }
    }

    function onDidChangeActiveTextEditor(editor:TextEditor) {
        if (editor == null) return;

        function loop(nodes:Array<Node>):Bool {
            var anyMatches = false;
            for (node in nodes) {
                if (node.isDirectory && PathHelper.containsFile(node.path, editor.document.fileName)) {
                    anyMatches = true;
                    node.expand();
                    loop(node.children);
                }
            }
            return anyMatches;
        }

        if (loop(dependencyNodes)) {
            _onDidChangeTreeData.fire();
        }
    }

    function getHaxePath() {
        var haxePath = workspace.getConfiguration("haxe").get("displayServer").haxePath;
        return if (haxePath == null) "haxe" else haxePath;
    }

    function refreshDependencies():Array<Node> {
        var newDependencies = HxmlParser.extractDependencies(displayArguments, workspace.rootPath);
        relevantHxmls = newDependencies.hxmls;

        // avoid FS access / creating processes unless there were _actually_ changes
        if (dependencies != null && dependencies.libs.equals(newDependencies.libs) && dependencies.classPaths.equals(newDependencies.classPaths)) {
            return dependencyNodes;
        }
        dependencies = newDependencies;

        return updateNodes(DependencyResolver.resolveDependencies(newDependencies, haxePath));
    }

    function updateNodes(dependencyInfos:Array<DependencyInfo>):Array<Node> {
        var newNodes:Array<Node> = [];

        for (info in dependencyInfos) {
            // don't add duplicates
            if (newNodes.find(d -> d.path == info.path) != null) {
                continue;
            }

            // reuse existing nodes if possible to preserve their collapsibleState
            if (dependencies != null) {
                var oldNode = dependencyNodes.find(d -> d.path == info.path);
                if (oldNode != null) {
                    newNodes.push(oldNode);
                    continue;
                }
            }

            var node = createNode(info);
            if (node != null) {
                newNodes.push(node);
            }
        }

        return newNodes;
    }

    function createNode(info):Node {
        if (info == null) {
            return null;
        }
        var label = info.name;
        if (info.version != null) {
            label += ' (${info.version})';
        }
        return new Node(label, info.path);
    }

    public function onDidChangeDisplayArguments(displayArguments:Array<String>) {
        this.displayArguments = displayArguments;
        refresh();
    }

    function refresh(hard:Bool = true) {
        if (hard) {
            dependencies = null;
        }
        refreshNeeded = true;
        _onDidChangeTreeData.fire();
    }

    public function getTreeItem(element:Node):TreeItem {
        return element;
    }

    public function getChildren(?node:Node):Thenable<Array<Node>> {
        return new Promise(function(resolve, _) {
            if (refreshNeeded) {
                dependencyNodes = refreshDependencies();
                refreshNeeded = false;
            }

            resolve(if (node == null) dependencyNodes else node.children);
        });
    }

    function selectNode(node:Node) {
        if (node.isDirectory) {
            node.toggleState();
        } else {
            workspace.openTextDocument(node.path).then(document -> window.showTextDocument(document, {preview: true}));
        }
    }

    function collapseAll(node:Node) {
        for (node in dependencyNodes) {
            node.collapse();
        }
        _onDidChangeTreeData.fire();
    }
}
