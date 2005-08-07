use 5.008;
use ExtUtils::MakeMaker;

die "ERROR: /proc/$$/smaps not found.\n",
    "       Maybe your kernel lacks the appropriate patch.\n",
    "       linux-2.6.13-rc4-mm1 is known to work good with this module.\n"
  unless( -f "/proc/$$/smaps" );

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
);
