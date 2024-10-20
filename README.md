## This repository contains publicly available services for the Story node


#### Automatic installation script

This script provides the following choice of actions:
```
1. Install Story node
2. Download snapshot
3. Check sync status
4. Check logs
5. Exit
```

To start automatic installation of the node, run:
```
wget -O installer_story.sh https://raw.githubusercontent.com/lesnikutsa/story/refs/heads/main/installer_story.sh && chmod +x installer_story.sh && ./installer_story.sh
```


#### Automatic snapshots

This script provides the following choice of actions:
```
1. Source 1 (Archive, full snapshot)
2. Source 2 (Pruned)
```

To start automatic synchronization from snapshots, run:
```
wget -O autosnap_story.sh https://raw.githubusercontent.com/lesnikutsa/story/refs/heads/main/autosnap_story.sh && chmod +x autosnap_story.sh && ./autosnap_story.sh
```

To install the dashboard, follow [here](https://github.com/lesnikutsa/story/blob/main/dashboard/README.md)
