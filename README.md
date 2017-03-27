# A Homebrew Tap for Pony and its dependencies

## Usage
To install an item from this repository, for example LLVM 3.8:
```bash
brew install killerswan/pony/pcre2
```

Formulas available include:
* libressl
* pcre2
* llvm@3.8


## Formula update process

Here are some checklists to follow when adding or updating a formula, so new binary bottles are created.

The submitter should:
```
- [ ] Make a request containing the version to build, removing old bottle SHAs.
- [ ] If this is a new formula, update `.travis.yml`, too.
```

An admin should:
```
- [ ] Confirm that bottles were built OK (though not deployed) by Travis CI.
- [ ] Review the code.
- [ ] Merge to _staging_ so bottles are built AND deployed to Bintray.
- [ ] Make another commit inserting SHAs into the formula.
- [ ] Merge to master.
```

This means that for a pull req. the first bottle builds (with unreviewed code) won't be deployed [to Bintray](https://dl.bintray.com/killerswan/bottles).  But `master` will still (due to `staging`) always have up-to-date SHAs.  If master always refers to up-to-date bottles, users will have fast binary installs!


## References

Feel free to ask questions!

* the Pony ticket discussing this Tap: [ponyc#1732](https://github.com/ponylang/ponyc/issues/1732)
* [Bottles](http://docs.brew.sh/Bottles.html)
* [Taps (third-party repositories)](http://docs.brew.sh/brew-tap.html) (like this one)
* RubyDoc for [the Formula class](http://www.rubydoc.info/github/Homebrew/brew/master/Formula)
* [Formula Cookbook](http://docs.brew.sh/Formula-Cookbook.html)
* a Travis hint [about timeouts](https://docs.travis-ci.com/user/common-build-problems/#My-builds-are-timing-out)
* [jq](https://stedolan.github.io/jq/)
