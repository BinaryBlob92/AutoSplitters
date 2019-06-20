state("Jazz2", "v1.20") {
    int menuItem      : 0x0CE514;
    int fullScreenImg : 0x144E40;
    int demo          : 0x145060;
    int inGame        : 0x1B8524;
    int levelFinished : 0x1B8464;
    int levelEndTimer : 0x1B8468;
}

state("Jazz2", "v1.20 s Shareware") {
    int menuItem      : 0x0CC2D4;
    int fullScreenImg : 0x142C00;
    int demo          : 0x142E20;
    int inGame        : 0x1B62E4;
    int levelFinished : 0x1B6224;
    int levelEndTimer : 0x1B6228;
}

state("Jazz2", "v1.22") {
    int menuItem      : 0x0E609C;
    int fullScreenImg : 0x15C860;
    int demo          : 0x15CA80;
    int inGame        : 0x1D00C4;
    int levelFinished : 0x1D0004;
    int levelEndTimer : 0x1D0008;
}

state("Jazz2", "v1.23") {
    int menuItem      : 0x0E606C;
    int fullScreenImg : 0x15CA40;
    int demo          : 0x15CC60;
    int inGame        : 0x1D0284;
    int levelFinished : 0x1D01C4;
    int levelEndTimer : 0x1D01C8;
}

state("Jazz2", "v1.23 s Shareware") {
    int menuItem      : 0x0E4FDC;
    int fullScreenImg : 0x15B9A0;
    int demo          : 0x15BBC0;
    int inGame        : 0x1CF1E4;
    int levelFinished : 0x1CF124;
    int levelEndTimer : 0x1CF128;
}

state("Jazz2", "v1.23 se Special Edition Shareware") {
    int menuItem      : 0x0E4FFC;
    int fullScreenImg : 0x15B9C0;
    int demo          : 0x15BBE0;
    int inGame        : 0x1CF204;
    int levelFinished : 0x1CF144;
    int levelEndTimer : 0x1CF148;
}

state("Jazz2", "v1.24") {
    int menuItem      : 0x0E06B4;
    int fullScreenImg : 0x180060;
    int demo          : 0x180280;
    int inGame        : 0x1F38A4;
    int levelFinished : 0x1F37E4;
    int levelEndTimer : 0x1F37E8;
}

state("Jazz2", "v1.24 (LK Avalon)") {
    int menuItem      : 0x0E0714;
    int fullScreenImg : 0x1800C0;
    int demo          : 0x1802E0;
    int inGame        : 0x1F3904;
    int levelFinished : 0x1F3844;
    int levelEndTimer : 0x1F3848;
}

state("Jazz2", "v1.24 x Christmas Chronicles '99 (LK Avalon)") {
    int menuItem      : 0x0E05DC;
    int fullScreenImg : 0x17FFA0;
    int demo          : 0x1801C0;
    int inGame        : 0x1F37E4;
    int levelFinished : 0x1F3724;
    int levelEndTimer : 0x1F3728;
}

init {
    var versions = new dynamic[,]
    {
        { 0x352D28C2, 0x0C8, "v1.20" },
        { 0x352D2937, 0x0C8, "v1.20 s Shareware" },
        { 0x35AE2E29, 0x0C8, "v1.22" },
        { 0x35D00674, 0x0C8, "v1.23" },
        { 0x35D006DE, 0x0C8, "v1.23 s Shareware" },
        { 0x36068ADE, 0x0C8, "v1.23 se Special Edition Shareware" },
        { 0x36D13F77, 0x0F0, "v1.24" },
        { 0x376A194C, 0x110, "v1.24 (LK Avalon)" },
        { 0x383A85E8, 0x110, "v1.24 x Christmas Chronicles '99 (LK Avalon)" }
    };
    var baseAddr = modules.First().BaseAddress;
    for (int i = 0; i < versions.GetLength(0); ++i)
    {
        var timestamp = versions[i, 0];
        IntPtr posTimestamp = baseAddr + versions[i, 1];
        var name = versions[i, 2];
        if (memory.ReadValue<int>(posTimestamp) == timestamp)
        {
            version = name;
            break;
        }
    }
}

update {
    return version != "";
}

start {
    return current.menuItem == 0 && current.demo == 0 && current.inGame != 0;
}

isLoading {
    return current.fullScreenImg != 0 && current.inGame != 0;
}

split {
    if(current.levelFinished == 1)
        return current.levelEndTimer >= 32828 && old.levelEndTimer < 32828;
    else if(current.levelFinished == 2)
        return current.levelEndTimer >= 32780 && old.levelEndTimer < 32780;
    else
        return false;
}
