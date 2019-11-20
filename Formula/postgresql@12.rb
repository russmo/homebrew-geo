class PostgresqlAT12 < Formula
  desc "Object-relational database system"
  homepage "https://www.postgresql.org/"
  version = "12.1"
  url "https://ftp.postgresql.org/pub/source/v#{version}/postgresql-#{version}.tar.bz2"
  sha256 "a09bf3abbaf6763980d0f8acbb943b7629a8b20073de18d867aecdb7988483ed"
  
  head do
    url "https://git.postgresql.org/git/postgresql.git", :branch => "REL_12_STABLE"

    depends_on "docbook-xsl" => :build
  end

  # keg_only :versioned_formula

  option "with-cassert", "Enable assertion checks (for debugging)"
  deprecated_option "enable-cassert" => "with-cassert"

  depends_on "pkg-config" => :build

  depends_on "e2fsprogs"
  depends_on "gettext"
  depends_on "icu4c"
  depends_on "openldap"
  depends_on "openssl"
  depends_on "readline"
  depends_on "tcl-tk"
  depends_on "llvm" => :optional

  def install
    # avoid adding the SDK library directory to the linker search path
    ENV["XML2_CONFIG"] = "xml2-config --exec-prefix=/usr"

    ENV.prepend "LDFLAGS", "-L#{Formula["openssl"].opt_lib} -L#{Formula["readline"].opt_lib}"
    ENV.prepend "CPPFLAGS", "-I#{Formula["openssl"].opt_include} -I#{Formula["readline"].opt_include}"

    args = %W[
      --disable-debug
      --prefix=#{prefix}
      --datadir=#{HOMEBREW_PREFIX}/share/postgresql
      --libdir=#{HOMEBREW_PREFIX}/lib
      --sysconfdir=#{etc}
      --docdir=#{doc}
      --enable-thread-safety
      --with-bonjour
      --with-gssapi
      --with-icu
      --with-ldap
      --with-libxml
      --with-libxslt
      --with-openssl
      --with-pam
      --with-perl
      --with-uuid=e2fs
      --enable-dtrace
      --enable-nls
      --with-python
    ]

    args += [
      "--prefix=#{prefix}",
      # "bindir=#{bin}", # if define this, will refer to /Cellar
      # "--datadir=#{share}/postgresql",
      # "--libdir=#{lib}/postgresql",
      "--datadir=#{HOMEBREW_PREFIX}/share/postgresql",
      "--libdir=#{HOMEBREW_PREFIX}/lib/postgresql",
      "--sysconfdir=#{etc}",
      "--docdir=#{doc}/postgresql",
      "--includedir=#{include}/postgresql"
    ]

    # The CLT is required to build Tcl support on 10.7 and 10.8 because
    # tclConfig.sh is not part of the SDK
    args << "--with-tcl"
    if File.exist?("#{MacOS.sdk_path}/System/Library/Frameworks/Tcl.framework/tclConfig.sh")
      args << "--with-tclconfig=#{MacOS.sdk_path}/System/Library/Frameworks/Tcl.framework"
    end

    # Add include and library directories of dependencies, so that
    # they can be used for compiling extensions.  Superenv does this
    # when compiling this package, but won't record it for pg_config.
    deps = %w[gettext icu4c openldap openssl readline tcl-tk]
    with_includes = deps.map { |f| Formula[f].opt_include }.join(":")
    with_libraries = deps.map { |f| Formula[f].opt_lib }.join(":")
    args << "--with-includes=#{with_includes}"
    args << "--with-libraries=#{with_libraries}"

    args << "--enable-cassert" if build.with? "cassert"
    args << "--with-llvm" if build.with? "llvm"

    extra_version = ""
    extra_version += "+git" if build.head?
    extra_version += " (Homebrew russmo/geo)"
    args << "--with-extra-version=#{extra_version}"

    system "./configure", *args
    system "make"
    system "make", "install-world", "datadir=#{pkgshare}",
                                    "libdir=#{lib}",
                                    "pkglibdir=#{lib}/postgresql"
  end

  def post_install
    (var/"log").mkpath
    (var/"postgres").mkpath
    unless File.exist? "#{var}/postgresql@12/PG_VERSION"
      system "#{bin}/initdb", "--locale=en_US.UTF-8", "-E", "UTF-8", "#{var}/postgresql@12"
    end
  end

  def caveats; <<~EOS
    To migrate existing data from a previous major version of PostgreSQL run:
      brew postgresql-upgrade-database
  EOS
  end

  plist_options :manual => "pg_ctl -D #{HOMEBREW_PREFIX}/var/postgresql@12 start"

  def plist; <<~EOS
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>KeepAlive</key>
      <true/>
      <key>Label</key>
      <string>#{plist_name}</string>
      <key>ProgramArguments</key>
      <array>
        <string>#{opt_bin}/postgres</string>
        <string>-D</string>
        <string>#{var}/#{name}</string>
      </array>
      <key>RunAtLoad</key>
      <true/>
      <key>WorkingDirectory</key>
      <string>#{HOMEBREW_PREFIX}</string>
      <key>StandardOutPath</key>
      <string>#{var}/log/#{name}.log</string>
      <key>StandardErrorPath</key>
      <string>#{var}/log/#{name}.log</string>
      <key>EnvironmentVariables</key>
      <dict>
        <key>LC_ALL</key>
        <string>en_US.UTF-8</string>
      </dict>
    </dict>
    </plist>
  EOS
  end

  test do
    system "#{bin}/initdb", testpath/"test"
    assert_equal "#{HOMEBREW_PREFIX}/share/postgresql", shell_output("#{bin}/pg_config --sharedir").chomp
    assert_equal "#{HOMEBREW_PREFIX}/lib", shell_output("#{bin}/pg_config --libdir").chomp
    assert_equal "#{HOMEBREW_PREFIX}/lib/postgresql", shell_output("#{bin}/pg_config --pkglibdir").chomp
  end
end