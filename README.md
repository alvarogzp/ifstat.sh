# ifstat.sh

ifstat.sh is a shell command to report network interface usage, like vmstat/iostat do for other system counters.
It works by printing the current speed at regular intervals. It also has several options to configure it.

ifstat.sh is an [ifstat](http://freecode.com/projects/ifstat) alternative completely written in bash.
I created it in 2011 because I knew no other way to monitor current network speed in real time.


## Disclaimer

I know this is not the best code one could write, not even on bash (I have [better](https://github.com/alvarogzp/badoo-challenge-2015/blob/f4e1d8b1837c7cc5ae31bb3fa808a24b60513214/03-Pattern_matcher/solution.sh) [examples](https://github.com/alvarogzp/telegram-bot/blob/2eab29b7b13c71daa1f382427ea93c2e2cceb5ae/run.sh) [over there](https://github.com/alvarogzp/poodle-challenge/blob/344c311224d062a5b9dc32a2b0391fb562827d9a/gen_inputs_outputs_tokens.sh)). I did it when I was still learning basic programming, and it is written and documented in Spanish (my native language).

But I find `ifstat.sh` very useful, use it frequently and am proud of have developed it at a so early stage in my career. So I have uploaded it here hoping it might be useful for someone as it is for me.
