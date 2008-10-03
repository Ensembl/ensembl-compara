package Acme::FASTA;

use strict;
our $class   = __PACKAGE__;
our %dict = reverse( our %inv = map { ($_,sprintf "%02b",ord($_)>>1&3) } split //,'ACGT' );

sub encode($$) {
### Encode perl into FASTA - class name becomes FASTA header
  local $_ = shift;
  my $t = shift;
  my $hash_bang = $t =~ /^(#\!.*)/m ? "$1\n\n" : "";
  ($t = $t =~ /package\s+(\S+)/ || /package\s+(\S+)/ ? "::$1" : '' ) =~s/;$//;
  $_ = unpack "b*", $_;
  s/(..)/$dict{$1}/g;
  s/(.{60})/$1\n/g;
  "${hash_bang}use $class;\n\n>$class$t\n$_\n";
}

sub decode($) {
### Decode FASTA back into perl
  local $_ = shift;
  s/.*^>$class//sm;
  s/(.)/$inv{$1}/ges;
  warn pack "b*", $_;
  pack "b*", $_;
}

open 0 or print "Can't open '$0'\n" and exit;
($_ = join "", <0>) =~ s/(.*^\s*)use\s+$class;\n+//sm;

if( /^>$class/ ) {
  do { eval decode $_; exit }
} else {
  no strict 'refs';
  open 0, ">$0" or print "Cannot encode '$0'\n" and exit;
  print {0} encode $_,$1 and exit;
}

1;
__END__

=head1 NAME

Acme::FASTA - Genetic programming

=head1 SYNOPSIS

  use Acme::FASTA;
  print "Hello";

=head1 DESCRIPTION

Acme::FASTA obfuscates code by converting the script into a FASTA file.
The header of the FASTA file incorporates the package name in the module
if one is included.

This is inspired by Apache::DoubleHelix and Conway's Acme::Bleach.

The script also keeps intact the #! line so that you can still execute
the script with out having to "perl" it!

=head1 DIAGNOSTICS

=over 2

=item * Can't open '%s'

Acme::FASTA cannot access the source.

=item * Can't encode '%s'

Acme::FASTA cannot convert the source.

=back

=head1 AUTHOR

James Smith <js5@sanger.ac.uk>

=head1 LICENSE

Released under The Artistic License

=head1 SEE ALSO

L<Acme::Bleach>, L<Acme::Buffy>, L<Acme::Pony>

=cut

