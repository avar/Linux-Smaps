package Linux::Smaps;

use 5.008;
use strict;
no warnings qw(uninitialized);
use Class::Member::HASH qw{pid lasterror
			   _elem -CLASS_MEMBERS};

our $VERSION = '0.01';

sub new {
  my $class=shift;
  $class=ref($class) if( ref($class) );
  my $I=bless {}=>$class;

  if( @_==1 ) {
    $I->pid=shift;
  } else {
    our @CLASS_MEMBERS;
    my %h=@_;
    foreach my $k (@CLASS_MEMBERS) {
      $I->$k=$h{$k};
    }
  }

  return defined($I->pid) ? $I->update : $I;
}

sub update {
  my $I=shift;

  return unless( $I->pid>0 );

  my $name='/proc/'.$I->pid.'/smaps';
  #-f $name or $name='/proc/'.$I->pid.'/maps';
  open my $f, $name or do {
    $I->lasterror="Cannot open $name: $!";
    return;
  };

  # nasty hack: with my current linux kernel /proc/PID/smaps must be
  # read in 1024 byte chunks.
  my $buf="";
  my $off=0;
  my $n;
  while( $n=sysread $f, $buf, 1024, $off ) {$off+=$n;}

  my $current;
  $I->_elem=[];
  foreach my $l (split /\n/, $buf) {
    if( $l=~/([\da-f]+)-([\da-f]+)\s                # range
             ([r\-])([w\-])([x\-])([sp])\s          # access mode
             ([\da-f]+)\s                           # page offset in file
             ([\da-f]+):([\da-f]+)\s                # device
             (\d+)\s*                               # inode
             (.*)		                    # file name
	    /xi ) {
      push @{$I->_elem}, $current=Linux::Smaps::VMA->new;
      $current->vma_start=hex $1;
      $current->vma_end=hex $2;
      $current->r=($3 eq 'r');
      $current->w=($4 eq 'w');
      $current->x=($5 eq 'x');
      $current->mayshare=($6 eq 's');
      $current->file_off=hex $7;
      $current->dev_major=hex $8;
      $current->dev_minor=hex $9;
      $current->inode=$10;
      $current->file_name=$11;
    } elsif( $l=~/^(\w+):\s*(\d+) kB$/ ) {
      my $m=lc $1;
      $current->$m=$2;
    } else {
      die __PACKAGE__.":: not parsed: $l\n";
    }
  }

  close $f;

  return $I;
}

BEGIN {
  foreach my $n (qw{size rss shared_clean shared_dirty
		    private_clean private_dirty}) {
    eval <<"EOE";
    sub $n {
      my \$I=shift;
      my \$n=shift;
      my \$rc=0;
      my \@l;
      if( length \$n ) {
	local \$_;
	\@l=grep {\$_->file_name eq \$n} \@{\$I->_elem};
      } else {
	\@l=\@{\$I->_elem};
      }
      foreach my \$el (\@l) {
	\$rc+=\$el->$n;
      }
      return \$rc;
    }
EOE
    die "$@" if( $@ );
  }

  foreach my $n (qw{heap stack vdso}) {
    eval <<"EOE";
    sub $n {
      my \$I=shift;
      local \$_;
      return (grep {'[$n]' eq \$_->file_name} \@{\$I->_elem})[0];
    }
EOE
    die "$@" if( $@ );
  }
}

sub unnamed {
  my $I=shift;
  if( wantarray ) {
    local $_;
    return grep {!length $_->file_name} @{$I->_elem};
  } else {
    my $sum=Linux::Smaps::VMA->new;
    $sum->size=$sum->rss=$sum->shared_clean=$sum->shared_dirty=
      $sum->private_clean=$sum->private_dirty=0;
    foreach my $el (@{$I->_elem}) {
      next if( length $el->file_name );
      $sum->size+=$el->size;
      $sum->rss+=$el->rss;
      $sum->shared_clean+=$el->shared_clean;
      $sum->shared_dirty+=$el->shared_dirty;
      $sum->private_clean+=$el->private_clean;
      $sum->private_dirty+=$el->private_dirty;
    }
    return $sum;
  }
}

sub named {
  my $I=shift;
  if( wantarray ) {
    local $_;
    return grep {length $_->file_name} @{$I->_elem};
  } else {
    my $sum=Linux::Smaps::VMA->new;
    $sum->size=$sum->rss=$sum->shared_clean=$sum->shared_dirty=
      $sum->private_clean=$sum->private_dirty=0;
    foreach my $el (@{$I->_elem}) {
      next if( !length $el->file_name );
      $sum->size+=$el->size;
      $sum->rss+=$el->rss;
      $sum->shared_clean+=$el->shared_clean;
      $sum->shared_dirty+=$el->shared_dirty;
      $sum->private_clean+=$el->private_clean;
      $sum->private_dirty+=$el->private_dirty;
    }
    return $sum;
  }
}

sub all {
  my $I=shift;
  if( wantarray ) {
    local $_;
    return @{$I->_elem};
  } else {
    my $sum=Linux::Smaps::VMA->new;
    $sum->size=$sum->rss=$sum->shared_clean=$sum->shared_dirty=
      $sum->private_clean=$sum->private_dirty=0;
    foreach my $el (@{$I->_elem}) {
      $sum->size+=$el->size;
      $sum->rss+=$el->rss;
      $sum->shared_clean+=$el->shared_clean;
      $sum->shared_dirty+=$el->shared_dirty;
      $sum->private_clean+=$el->private_clean;
      $sum->private_dirty+=$el->private_dirty;
    }
    return $sum;
  }
}

sub names {
  my $I=shift;
  local $_;
  my %h=map {($_->file_name=>1)} @{$I->_elem};
  delete @h{'','[heap]','[stack]','[vdso]'};
  return keys %h;
}

sub vmas {return @{$_[0]->_elem};}

package Linux::Smaps::VMA;

use strict;
use Class::Member::HASH qw(vma_start vma_end r w x mayshare file_off
			   dev_major dev_minor inode file_name
			   size rss shared_clean shared_dirty
			   private_clean private_dirty);

sub new {bless {}=>(ref $_[0] ? ref $_[0] : $_[0]);}

1;
__END__

=head1 NAME

Linux::Smaps - a Perl interface to /proc/PID/smaps

=head1 SYNOPSIS

  use Linux::Smaps;
  my $map=Linux::Smaps->new($pid);
  my @maps=$map->maps;
  my $private_dirty=$map->private_dirty;
  ...

=head1 DESCRIPTION

The /proc/PID/smaps files in modern linuxes provides very detailed information
about a processes memory consumption. It particularly includes a way to
estimate the effect of copy-on-write. This module implements a Perl
interface.

=head2 CONSTRUCTOR, OBJECT INITIALIZATION, etc.

=over 4

=item B<< Linux::Smaps->new($pid) >>

creates and initializes a C<Linux::Smaps> object. Returns the object
or C<undef> if a PID was given and C<update> has failed.

=item B<< $self->pid($pid) >> or B<< $self->pid=$pid >>

get/set the PID.

=item B<< $self->update >>

reinitializes the object; rereads /proc/PID/smaps. Returns the object
on success or C<undef> otherwize.

=item B<< $self->lasterror >>

C<update()> and C<new()> return C<undef> on failure. C<lasterror()> returns
a more verbose reason. Also C<$!> can be checked.

=back

=head2 INFORMATION RETRIEVAL

=over 4

=item B<< $self->vmas >>

returns a list of C<Linux::Smaps::VMA> objects each describing a vm area,
see below.

=item B<< $self->size >>

=item B<< $self->rss >>

=item B<< $self->shared_clean >>

=item B<< $self->shared_dirty >>

=item B<< $self->private_clean >>

=item B<< $self->private_dirty >>

these methods compute the sums of the appropriate values of all vmas.

=item B<< $self->stack >>

=item B<< $self->heap >>

=item B<< $self->vdso >>

these are shortcuts to the appropiate C<Linux::Smaps::VMA> objects.

=item B<< $self->all >>

=item B<< $self->named >>

=item B<< $self->unnamed >>

In array context these functions return a list of C<Linux::Smaps::VMA>
objects representing named or unnamed maps or simply all vmas. Thus, in
array context C<all()> is equivalent to C<vmas()>.

In scalar context these functions create a fake C<Linux::Smaps::VMA> object
containing the summaries of the C<size>, C<rss>, C<shared_clean>,
C<shared_dirty>, C<private_clean> and C<private_dirty> fields.

=item B<< $self->names >>

returns a list of vma names, i.e. the files that are mapped.

=back

=head1 Linux::Smaps::VMA objects

normally these objects represent a single vm area:

=over 4

=item B<< $self->vma_start >>

=item B<< $self->vma_end >>

start and end address

=item B<< $self->r >>

=item B<< $self->w >>

=item B<< $self->x >>

=item B<< $self->mayshare >>

these correspond to the VM_READ, VM_WRITE, VM_EXEC and VM_MAYSHARE flags.
see Linux kernel for more information.

=item B<< $self->file_off >>

=item B<< $self->dev_major >>

=item B<< $self->dev_minor >>

=item B<< $self->inode >>

=item B<< $self->filename >>

describe the file area that is mapped.

=item B<< $self->size >>

the same as vma_end - vma_start.

=item B<< $self->rss >>

what part is resident.

=item B<< $self->shared_clean >>

=item B<< $self->shared_dirty >>

=item B<< $self->private_clean >>

=item B<< $self->private_dirty >>

C<shared> means C<< page_count(page)>=2 >> (see Linux kernel), i.e. the page
is shared between several processes. C<private> pages belong only to one
process.

C<dirty> pages are written to in RAM but not to the corresponding file.

=back

=head1 Example: The copy-on-write effect

 use strict;
 use Linux::Smaps;

 my $x="a"x(1024*1024);		# a long string of "a"
 if( fork ) {
   my $s=Linux::Smaps->new($$);
   my $before=$s->all;
   $x=~tr/a/b/;			# change "a" to "b" in place
   #$x="b"x(1024*1024);		# assignment
   $s->update;
   my $after=$s->all;
   foreach my $n (qw{rss size shared_clean shared_dirty
                     private_clean private_dirty}) {
     print "$n: ",$before->$n," => ",$after->$n,": ",
            $after->$n-$before->$n,"\n";
   }
   wait;
 } else {
   sleep 1;
 }

This script may give the following output:

 rss: 4160 => 4252: 92
 size: 6916 => 7048: 132
 shared_clean: 1580 => 1596: 16
 shared_dirty: 2412 => 1312: -1100
 private_clean: 0 => 0: 0
 private_dirty: 168 => 1344: 1176

C<$x> is changed in place. Hence, the overall process size (size and rss)
would not grow much. But before the C<tr> operation C<$x> was shared by
copy-on-write between the 2 processes. Hence, we see a loss of C<shared_dirty>
(only a little more than our 1024 kB string) and almost the same growth of
C<private_dirty>.

Exchanging the C<tr>-operation to an assingment of a MB of "b" yields the
following figures:

 rss: 4160 => 5276: 1116
 size: 6916 => 8076: 1160
 shared_clean: 1580 => 1592: 12
 shared_dirty: 2432 => 1304: -1128
 private_clean: 0 => 0: 0
 private_dirty: 148 => 2380: 2232

Now we see the overall process size grows a little more than a MB.
C<shared_dirty> drops almost a MB and C<private_dirty> adds almost 2 MB.
That means perl first constructs a 1 MB string of C<b>. This adds 1 MB to
C<size>, C<rss> and C<private_dirty> and then copies it to C<$x>. This
takes another MB from C<shared_dirty> and adds it to C<private_dirty>.

=head2 EXPORT

Not an Exporter;

=head1 SEE ALSO

Linux Kernel.

=head1 AUTHOR

Torsten Foertsch, E<lt>torsten.foertsch@gmx.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005 by Torsten Foertsch

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.5 or,
at your option, any later version of Perl 5 you may have available.


=cut
