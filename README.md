# A Homebrew Tap for Pony and its dependencies

## Usage
To install an item from this repository, for example LLVM 3.8:
```bash
brew install killerswan/pony/llvm@3.8
```

Each item available can be found in this repository's `/Formula/` directory.


## Updates

Updates to our formulas should also be built into new binary bottles.

1. To do this, first update the formula in the tap.  (You can comment out the bottle SHAs.)
1. Then update .travis.yml's expected version (and revision) of the package to start a new bottle build.
1. Travis will build bottles for various macOS versions and deploy them to Bintray.
1. Finally you can update the tap to refer to these new bottles' SHAs.


## References

Feel free to ask questions!

* [Bottles](http://docs.brew.sh/Bottles.html)
* [Taps (third-party repositories)](http://docs.brew.sh/brew-tap.html) (like this one)
* RubyDoc for [the Formula class](http://www.rubydoc.info/github/Homebrew/brew/master/Formula)
* [Formula Cookbook](http://docs.brew.sh/Formula-Cookbook.html)
* the Pony ticket discussing this Tap: [ponyc#1732](https://github.com/ponylang/ponyc/issues/1732)
