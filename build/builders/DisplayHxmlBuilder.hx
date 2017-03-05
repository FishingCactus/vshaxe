package builders;

class DisplayHxmlBuilder extends BaseBuilder {
    override public function build(config:Config) {
       var classPaths = [];
       var defines = [];
       var haxelibs = [];
       forEachTarget(resolveTargets(config.targets), function(target) {
            classPaths = classPaths.concat(target.classPaths.get().map(function(cp) {
                return if (target.workingDirectory == null) cp else haxe.io.Path.join([target.workingDirectory, cp]);
            }));
            defines = defines.concat(target.defines.get());
            haxelibs = haxelibs.concat(target.haxelibs.get().map(function(name) return name));
        });
        var hxml = ['# ${Warning.Message}'];
        for (cp in classPaths) hxml.push('-cp $cp');
        for (define in defines) hxml.push('-D $define');
        for (lib in haxelibs) hxml.push('-lib $lib');

        var hxml = hxml.filterDuplicates(function(s1, s2) return s1 == s2);
        // TODO: get rid of these hacks
        hxml.push("-cp build");
        hxml.push("-lib hxnodejs");
        hxml.push("-lib jstack");
        hxml.push("-js some.js");

        hxml.push("-debug"); // we usually always want -debug in display configs

        cli.saveContent("complete.hxml", hxml.join("\n"));
    }

    function forEachTarget(targets:Array<Target>, callback:Target->Void) {
        for (target in targets) {
            callback(target);
            forEachTarget(resolveTargets(target.targetDependencies.get()), callback);
        }
    }
}