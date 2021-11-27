state("Jazz2") {}

init {
    (vars as IDictionary<string, object>).Clear();
    vars.initialized = false;

    var w1 = vars.memoryWatcherList1 = new MemoryWatcherList();
    var w2 = vars.memoryWatcherList2 = new MemoryWatcherList();
    var patterns = new dynamic[,] {
        { w1, "menuItem"     , 11, "C7 05 ?? ?? ?? ?? 01 00 00 00 A3 ?? ?? ?? ?? A3 ?? ?? ?? ??" },
        { w2, "fullScreenImg",  6, "BF ?? ?? ?? ?? A3 ?? ?? ?? ?? 83 C4 08" },
        { w1, "demo"         ,  4, "8B C6 8B 0D ?? ?? ?? ?? 85 C9" },
        { w2, "inGame"       , 12, "C7 05 ?? ?? ?? ?? 05 00 00 00 89 35 ?? ?? ?? ?? E8 ?? ?? ?? ??" },
        { w2, "levelFinished",  3, "7E 42 A1 ?? ?? ?? ?? 85 C0" },
        { w2, "levelEndTimer",  6, "A3 ?? ?? ?? ?? A3 ?? ?? ?? ?? 8B 75 24" }
    };

    // Find variables
    var scanTarget = new SigScanTarget();
    for (int i = 0; i < patterns.GetLength(0); ++i) {
        var offset  = patterns[i, 2];
        var pattern = patterns[i, 3];
        scanTarget.AddSignature(offset, pattern);
    }
    var mainModule = modules.First();
    var addrs = new SignatureScanner(game, mainModule.BaseAddress, mainModule.ModuleMemorySize).ScanAll(scanTarget).ToArray();
    if (addrs.Length != scanTarget.Signatures.Count) {
        print("ScanAll failed");
        return;
    }

    // Create memory watchers
    for (int i = 0; i < patterns.GetLength(0); ++i) {
        var watcherList = patterns[i, 0];
        var name        = patterns[i, 1];
        if (addrs[i] == IntPtr.Zero) {
            print("Cannot determine address of \"" + name + "\"");
            return;
        }
        var watcher = new MemoryWatcher<int>(memory.ReadPointer(addrs[i]));
        watcherList.Add(watcher);
        (vars as IDictionary<string, object>).Add(name, watcher);
    }

    vars.initialized = true;
}

update {
    if (!vars.initialized) return false;
    vars.memoryWatcherList2.UpdateAll(game);
}

start {
    vars.memoryWatcherList1.UpdateAll(game);
    var inGame = vars.inGame;
    return vars.menuItem.Current == 0 && vars.demo.Current == 0 && inGame.Current > inGame.Old;
}

isLoading {
    return vars.fullScreenImg.Current != 0 && vars.inGame.Current != 0;
}

split {
    int cmpEndTimer;
    switch ((int)vars.levelFinished.Current) {
        case 1: cmpEndTimer = 32828; break;
        case 2: cmpEndTimer = 32780; break;
        default: return false;
    }
    var endTimer = vars.levelEndTimer;
    return endTimer.Current >= cmpEndTimer && endTimer.Old < cmpEndTimer;
}
