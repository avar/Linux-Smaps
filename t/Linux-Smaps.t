use Test::More tests => 34;
BEGIN { use_ok('Linux::Smaps') };

my ($s, $old);

my $fn=$0;
$fn=~s!/*t/+[^/]*$!! or die "Wrong test script location: $0";
$fn='.' unless( length $fn );

$s=Linux::Smaps->new(uninitialized=>1);
ok( !Linux::Smaps::VMA->can('size'),
    'VMA method "size" unknown before first smaps file read' );
ok( !Linux::Smaps->can('shared_dirty'),
    'Smaps method "shared_dirty" unknown before first smaps file read' );
$s->filename=$fn.'/t/smaps';
$s->lasterror=undef;
$s->update;
ok( Linux::Smaps->can('size'),
    'VMA method "size" known after first smaps file read' );
ok( Linux::Smaps->can('shared_dirty'),
    'Smaps method "shared_dirty" known after first smaps file read' );

ok( $s->size('/opt/apache22-worker/sbin/httpd')==408, 'summary size' );
ok( $s->rss('/opt/apache22-worker/sbin/httpd')==32, 'summary rss' );
ok( $s->shared_clean('/opt/apache22-worker/sbin/httpd')==12, 'summary shared_clean' );
ok( $s->shared_dirty('/opt/apache22-worker/sbin/httpd')==0, 'summary shared_dirty' );
ok( $s->private_clean('/opt/apache22-worker/sbin/httpd')==12, 'summary private_clean' );
ok( $s->private_dirty('/opt/apache22-worker/sbin/httpd')==8, 'summary private_dirty' );
ok( $s->referenced==25, 'summary referenced' );

SKIP: {
  skip "Your kernel lacks /proc/PID/smaps support", 8
    unless( -r '/proc/self/smaps' );

  $s=Linux::Smaps->new;

  $old=Linux::Smaps->new;

  ok $s, 'constructor';

  ok scalar grep( {$_->file_name=~/perl/} $s->vmas), 'perl found';

  my ($newlist, $difflist, $oldlist)=$s->diff( $s );

  ok @$newlist==0 && @$difflist==0 && @$oldlist==0, 'no diff';

  my $dirty=$s->private_dirty;
  {
    no warnings qw{void};
    "a"x(1024*1024);
  }
  $s->update;
  print "# dirty grows from $dirty to ".$s->private_dirty."\n";
  ok $s->private_dirty>$dirty+1024, 'dirty has grown';

  ($newlist, $difflist, $oldlist)=$s->diff( $old );
  my ($newlist2, $difflist2, $oldlist2)=$old->diff( $s );

  ok eq_set($newlist, $oldlist2), 'newlist=oldlist2';
  ok eq_set($difflist, [map {[@{$_}[1,0]]} @$difflist2]), 'difflist=difflist2';
  ok eq_set($oldlist, $newlist2), 'oldlist=newlist2';

  my $pid; sleep 1 until defined( $pid=fork );
  unless( $pid ) {
    exec $^X, '-MPOSIX', '-e', 'sleep 10';
    die;
  }
  select undef, undef, undef, .2;  # let the child start up
  $s->pid=$pid; $s->update;
  ok scalar( grep {$_->file_name=~/POSIX\.so$/} $s->vmas ), 'other process';
  kill 'KILL', $pid;
}

eval {Linux::Smaps->new(0)};
ok $@ eq "Linux::Smaps: Cannot open /proc/0/smaps: No such file or directory\n",
  'error1';

$s=Linux::Smaps->new(uninitialized=>1);
$s->pid=-1; $s->update;
ok $s->lasterror eq "Cannot open /proc/-1/smaps: No such file or directory",
  'error2';

$s->lasterror=undef;
$s->pid=undef;
$s->filename=$fn.'/t/smaps';
$s->update;
ok( ($s->vmas)[0]->file_name eq '/opt/apache22-worker/sbin/httpd',
    'filename parameter to new()' );

$s=Linux::Smaps->new(procdir=>$fn, pid=>'t');
ok( ($s->vmas)[0]->file_name eq '/opt/apache22-worker/sbin/httpd',
    'procdir parameter to new()' );

ok( ($s->vmas)[8]->file_name eq '/home/r2/work/mp2/trunk/trunk/blib/arch/auto/APR/Pool/Pool.so',
    '(deleted) vma file_name' );

ok( !($s->vmas)[0]->is_deleted, 'existing vma is not deleted' );

ok( ($s->vmas)[8]->is_deleted, '(deleted) vma is deleted' );
ok( $s->stack->size==92, 'size check' );
ok( $s->stack->vma_end-$s->stack->vma_start==92*1024, 'size check 2' );

eval {require Config};
SKIP: {
  skip "64bit support not checked on non-64bit perl", 4
    unless( $Config::Config{use64bitint} || $Config::Config{use64bitall} );
  $s=Linux::Smaps->new(filename=>$fn.'/t/smaps64');
  $s=($s->vmas)[431];
  ok( $s->file_name eq '/dev/zero', 'smaps64 name is /dev/zero' );
  ok( $s->is_deleted, 'smaps64 is_deleted==1' );
  ok( $s->size==88, 'smaps64 size=88' );
  ok( $s->vma_end-$s->vma_start==88*1024, 'smaps64 vma_end-vma_start=88*1024' );
}

SKIP: {
  skip "64bit overflow not checked on 64bit perl", 1
    if( $Config::Config{use64bitint} || $Config::Config{use64bitall} );
  eval {$s=Linux::Smaps->new(filename=>$fn.'/t/smaps64')};
  ok( $@=~/Integer overflow in hexadecimal number/, "integer overflow" );
}

# Local Variables:
# mode: perl
# End:
