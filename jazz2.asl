state("jazz2") {
    int menuItem        : 0x000E0714;
    int inGameInclLoads : 0x0012AA22;
    int inGameExclLoads : 0x001F3904;
    int levelFinished   : 0x001F3844;
    int levelEndTimer   : 0x001F3848;
}

start {
    return current.menuItem == 0 && current.inGameExclLoads > old.inGameExclLoads;
}

isLoading {
	return current.inGameExclLoads > current.inGameInclLoads;
}

split {
	if(current.levelFinished == 1)
		return current.levelEndTimer >= 32828 && old.levelEndTimer < 32828;
	else if(current.levelFinished == 2)
		return current.levelEndTimer >= 32780 && old.levelEndTimer < 32780;
	else
		return false;
}