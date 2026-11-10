# Stand-in windows for the screenshots

`harbor.html` (an agent workspace) and `relay.html` (a team chat) are static
pages with invented names and content. Opened as app windows they stand in for
apps that would otherwise show real projects and conversations:

```sh
google-chrome-stable --user-data-dir="$(mktemp -d)" --app="file://$PWD/harbor.html"
```

The recordings were made in demo mode, which limits the overview to one
monitor and a few workspaces and numbers them from 1:

```sh
hyprctl eval 'mac_mission_control.demo("eDP-1", { 5, 6, 7 }, true)'   # and  mac_mission_control.demo()  to end it
```
