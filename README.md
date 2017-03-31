# A Homebrew Tap for Pony and its dependencies

## Usage [![Mirroring status](https://travis-ci.org/killerswan/homebrew-pony.svg?branch=master)](https://travis-ci.org/killerswan/homebrew-pony/branches)

To install an item from this homebrew tap, for example pcre2:
```bash
brew install killerswan/pony/pcre2
```

## Description

This repository and it's [Travis CI setup](https://travis-ci.org/killerswan/homebrew-pony/branches) provide two things:
1. a homebrew tap for the Pony project, and
1. a mirror of bottles for formulas in this tap.

The formulas are in the `Formula` subdirectory of this repository.

And the bottles are hosted [here on Bintray](https://bintray.com/killerswan/bottles/all#files) ([direct](https://dl.bintray.com/killerswan/bottles/)).


## Formula update process

Here are some checklists to follow when adding or updating a formula, so new binary bottles are created.

The submitter should:
```
- [ ] Make a request containing an updated copy of a formula from homebrew-core.
- [ ] Modify it's root_url to refer to our bottle mirror: https://dl.bintray.com/killerswan/bottles
- [ ] Confirm mirroring and usage after merge to master.
```

An admin should:
```
- [ ] Confirm that bottle SHAs are OK and Bintray descriptor files look good on Travis CI.
- [ ] Confirm that there are deploy statements matching those uploads.  (LLVM 3.9 and 4 are large bottles!)
- [ ] Review the code.
- [ ] Merge to master.
```

Periodically, an admin should:
```
- [ ] Manually remove any binaries Pony no longer needs to keep.
```
