use 5.008;
use ExtUtils::MakeMaker;

warn <<"EOF" unless( -f "/proc/$$/smaps" );
WARNING: /proc/$$/smaps not found. Maybe your kernel lacks the feature.
Maybe the proc filesystem is mounted on another location. A few tests
will be ommitted during "make test".
EOF

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Linux::Smaps',
    VERSION_FROM      => 'lib/Linux/Smaps.pm', # finds $VERSION
    PREREQ_PM         => {
			  'Class::Member'=>1.3,
			 }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Linux/Smaps.pm', # retrieve abstract from module
       AUTHOR         => 'Torsten Foertsch <torsten.foertsch@gmx.net>') : ()),
    dist              => {
			  PREOP => './mk_README.sh',
			 },
    PMLIBDIRS         => ['lib'],
);

sub MY::postamble {
  return <<'EOF';
README: lib/Linux/Smaps.pm mk_README.sh
	./mk_README.sh

rpm: dist
	rpmbuild -ba perl-Linux-Smaps.spec
EOF
}
