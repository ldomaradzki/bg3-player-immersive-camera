ObjC.import("Foundation");

function run(argv) {
    if (argv.length !== 1) {
        throw new Error("Expected the inputconfig_p1.json path");
    }

    const path = argv[0];
    const manager = $.NSFileManager.defaultManager;
    let config = {};

    if (manager.fileExistsAtPath(path)) {
        const data = $.NSData.dataWithContentsOfFile(path);
        const text = $.NSString.alloc.initWithDataEncoding(data, $.NSUTF8StringEncoding).js;
        config = JSON.parse(text);
    }

    config.CharacterMoveBackward = ["key:s"];
    config.CharacterMoveForward = ["key:w"];
    config.CharacterMoveLeft = ["key:a"];
    config.CharacterMoveRight = ["key:d"];

    const output = JSON.stringify(config, null, 4) + "\n";
    const string = $.NSString.alloc.initWithUTF8String(output);
    if (!string.writeToFileAtomicallyEncodingError(path, true, $.NSUTF8StringEncoding, null)) {
        throw new Error("Could not write " + path);
    }
}
