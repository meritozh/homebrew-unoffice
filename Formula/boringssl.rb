class Boringssl < Formula
  desc "Google fork of OpenSSL"
  homepage "https://boringssl.googlesource.com/boringssl"
  url "https://boringssl.googlesource.com/boringssl.git",
      :revision => "b29b21a81b32ec273f118f589f46d56ad3332420"
  version "10.0.6"
  head "https://boringssl.googlesource.com/boringssl.git"

  keg_only <<~EOS
    Apple provides an old OpenSSL, which conflicts with this.
    It also conflicts with Homebrew's shipped OpenSSL and LibreSSL
  EOS

  depends_on "cmake" => :build
  depends_on "go" => :build
  depends_on "ninja" => :build

  def install
    doc.mkpath
    cd "util" do
      system "go", "build", "doc.go"
      system "./doc", "--config", "--out", doc
    end

    mkdir "build" do
      system "cmake", "-GNinja", "..", "-DBUILD_SHARED_LIBS=1", *std_cmake_args
      system "ninja"
      system "go", "run", buildpath/"util/all_tests.go"

      # Workaround https://github.com/Homebrew/brew/issues/4792.
      libcrypto = MachO::MachOFile.new(buildpath/"build/crypto/libcrypto.dylib").dylib_id
      MachO::Tools.change_install_name("tool/bssl", libcrypto, "#{opt_lib}/libcrypto.dylib")
      libssl = MachO::MachOFile.new(buildpath/"build/ssl/libssl.dylib").dylib_id
      MachO::Tools.change_install_name("tool/bssl", libssl, "#{opt_lib}/libssl.dylib")
      MachO::Tools.change_install_name("ssl/libssl.dylib", libcrypto, "#{opt_lib}/libcrypto.dylib")

      # There's no real Makefile as such. We have to handle this manually.
      bin.install "tool/bssl"
      lib.install "crypto/libcrypto.dylib", "ssl/libssl.dylib"
    end

    include.install Dir["include/*"]
  end

  test do
    (testpath/"testfile.txt").write "This is a test file"
    expected_checksum = "e2d0fe1585a63ec6009c8016ff8dda8b17719a637405a4e23c0ff81339148249"
    assert_match expected_checksum, shell_output("#{bin}/bssl sha256sum testfile.txt")
  end

end