package Texmake;

use 5.010001;
use strict;
use warnings;

use constant EVAL_FAIL      => -1;
use constant EVAL_NOACTION  => 0;
use constant EVAL_NEWER     => 1;
use constant EVAL_BUILDME   => 2;

use constant BUILD_FAIL     => -1;
use constant BUILD_SUCCESS  => 0;
use constant BUILD_REBUILD  => 1;

use constant DEP_DROP => -1;
use constant DEP_KEEP => 0;
use constant DEP_NEW  => 1;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Texmake ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	EVAL_FAIL
	EVAL_NOACTION
	EVAL_NEWER
	EVAL_BUILDME
	BUILD_FAIL
	BUILD_SUCCESS
	BUILD_REBUILD
	DEP_DROP
	DEP_KEEP
	DEP_NEW
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = '0.01';


# Preloaded methods go here.

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Texmake - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Texmake;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Texmake, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Josh BIalkowski, E<lt>josh@E<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Josh BIalkowski

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.1 or,
at your option, any later version of Perl 5 you may have available.


=cut
