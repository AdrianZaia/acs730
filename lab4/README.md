# Lab 4

Instructions for this section will be provided in class and on Blackboard when we reach it.

Put your work for Lab 4 in this folder.

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

## Action vs reusable workflow

- **Composite action (`python-deps`):** the dependency setup is a few steps that must run on the same runner as the tests, inside the test job, so it is an action.
- **Reusable workflow (`docker-build`):** the image build is a whole job with its own runner that needs `packages: write`, which the test job must not have, so it is a workflow.

## Build and run

    cd lab4
    docker build -t acs730-lab4:slim .
    docker run -d --name lab4 -p 8000:8000 acs730-lab4:slim
    curl http://localhost:8000/healthz    # {"status":"ok","version":"dev"}

## Image sizes

| Image | Base image | Size | Rebuild after one-line code change |
|---|---|---|---|
| naive | python:latest (1.13GB) | 1.15GB | 9s |
| slim | python:3.12-slim-bookworm (124MB) | 130MB | 2s |

- **Base image:** about 1.0GB of the roughly 1.02GB gap comes from the base image (python:latest at 1.13GB against python:3.12-slim-bookworm at 124MB). The app and dependencies add only about 20MB to naive and 6MB to slim.
- **Dependency layer:** on a code-only rebuild, pip install is CACHED in the slim image, because requirements.txt is copied and installed before app.py. In the naive image it re-runs every time, because COPY . . comes first and any code edit invalidates it and every layer after it.
- **.dockerignore:** it kept .git, .github, evidence/, *.png, *.md, __pycache__/ and the Dockerfiles out of the build context, so a careless COPY . . can't pull them in.

## Why SHA tags, not latest

A sha- tag points at one commit forever, so "which code is running in this image" always has an answer. latest points at whatever was pushed last.
