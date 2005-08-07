use Test::More tests => 4;
BEGIN { use_ok('Linux::Smaps') };

my $s=Linux::Smaps->new($$);

ok $s, 'constructor';

ok scalar grep( {$_->file_name=~/perl/} $s->vmas), 'perl found';

my $dirty=$s->private_dirty;
{
  no warnings qw{void};
  "a"x(1024*1024);
}
$s->update;
print "# dirty grows from $dirty to ".$s->private_dirty."\n";
ok $s->private_dirty>$dirty+1024, 'dirty has grown'