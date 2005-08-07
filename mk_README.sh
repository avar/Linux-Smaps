#!/bin/bash

(perldoc -tU ./lib/Linux/Smaps.pm
 perldoc -tU $0
) >README

exit 0

=head1 INSTALLATION

 perl Makefile.PL
 make
 make test
 make install

=head1 DEPENDENCIES

 perl 5.8.0
 Class::Member 1.3

=cut