# Run `spotifyd` outside `brew services`

## `spotifyd` had poor performance on my MacBook
I had installed `spotifyd` via brew (`brew cask install spoityfd`) and started the daemon using `brew services`:
```
brew services start spotifyd
```
Whenever I used use [`spotify-tui`](https://github.com/Rigellute/spotify-tui)...
My fairly old MacBook Pro `spotifyd` was having performance issues on my old MacBook Pro

## Getting and Testing the Runner Script
...fetch
./spotifyd-runner.sh; ctrl-c a few times

## Manually Starting `spotifyd` from Terminal
nohup spotifyd-runner.sh 2>&1 &

## Starting Upon Login
