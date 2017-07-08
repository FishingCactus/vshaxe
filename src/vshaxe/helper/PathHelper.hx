package vshaxe.helper;

import haxe.io.Path;
using StringTools;

class PathHelper {
    public static function absolutize(path:String, cwd:String):String {
        return Path.normalize(if (Path.isAbsolute(path)) {
            path;
        } else {
            Path.join([cwd, path]);
        });
    }

    public static function containsFile(directory:String, file:String):Bool {
        directory = Path.normalize(directory) + "/";
        var fileDirectory = Path.normalize(Path.directory(file)) + "/";

        if (Sys.systemName() == "Windows") {
            directory = directory.toLowerCase();
            fileDirectory = fileDirectory.toLowerCase();
        }

        return fileDirectory.startsWith(directory);
    }
}