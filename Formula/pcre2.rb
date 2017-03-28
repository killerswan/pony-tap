class Pcre2 < Formula
  desc "Perl compatible regular expressions library with a new API"
  homepage "http://www.pcre.org/"
  url "https://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre2-10.22.tar.bz2"
  mirror "https://www.mirrorservice.org/sites/downloads.sourceforge.net/p/pc/pcre/pcre2/10.21/pcre2-10.22.tar.bz2"
  sha256 "b2b44619f4ac6c50ad74c2865fd56807571392496fae1c9ad7a70993d018f416"
  head "svn://vcs.exim.org/pcre2/code/trunk"

  bottle do
    root_url "https://dl.bintray.com/killerswan/bottles/"
    cellar :any
    rebuild 1
    sha256 "247b5aae4fdbc9139e261c8a39ad7cc14d3de1fc3989ffff7745cba5c1da745c" => :sierra
    sha256 "649431f7d418aa3ac5666c0a20533c8556bdd43bb95266f26e6f924d268fbd94" => :el_capitan
    sha256 "20a579441b23b165cd6e7d38dfc05151bd9974fe3bb0c4b1df5e2f521a9c6ca6" => :yosemite
  end

  def install
    system "./configure", "--disable-dependency-tracking",
                          "--prefix=#{prefix}",
                          "--enable-pcre2-16",
                          "--enable-pcre2-32",
                          "--enable-pcre2grep-libz",
                          "--enable-pcre2grep-libbz2",
                          "--enable-jit"
    system "make"
    system "make", "check"
    system "make", "install"
  end

  test do
    system bin/"pcre2grep", "regular expression", prefix/"README"
  end
end
