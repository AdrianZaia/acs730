# Lab 4

Instructions for this section will be provided in class and on Blackboard when we reach it.

Put your work for Lab 4 in this folder.



## CI timings

| Step | Baseline | Cache miss | Cache hit | Worth it? |
|---|---|---|---|---|
| pip install (test 3.12) | 4s | 4s | 2s | TODO |
| setup-python step, includes cache restore (test 3.12) | 0s | 2s | 2s | TODO |
| docker build (build job) | 11s | 20s | 10s | TODO |
| Whole workflow (wall clock) | 55s | 82s | 81s | TODO |

Runs: baseline 39711565606, cache miss 39712078659, cache hit 39712260688.

- **pip cache:** TODO
- **Docker layer cache:** TODO

## CI timings

| Step | Baseline | Cache miss | Cache hit | Worth it? |
|---|---|---|---|---|
| pip install (test 3.12) | 4s | 4s | 2s | No |
| setup-python step, includes cache restore (test 3.12) | 0s | 2s | 2s | No |
| docker build (build job) | 11s | 20s | 10s | No |
| Whole workflow (wall clock) | 55s | 82s | 81s | No |

Runs: baseline 39711565606, cache miss 39712078659, cache hit 39712260688.

- **pip cache:** Not worth it here: a hit cut the install step from 4s to 2s, but the cache restore added 2s to the setup-python step, so the net saving was 0s. Flask and pytest are small enough that restoring a cache costs as much as downloading them.
- **Docker layer cache:** Not worth it here: the log shows CACHED on every layer on the hit run, yet the build step only went from 11s to 10s. The miss run took 20s because it had to export every layer (mode=max), and the whole workflow was about 26s slower with caching than without. A tiny image has too little to cache to repay that overhead.
