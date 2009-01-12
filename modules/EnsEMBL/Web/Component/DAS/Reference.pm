=head1 NAME

EnsEMBL::Web::Component::DAS::Reference

=head1 SYNOPSIS

Show information about the webserver

=head1 DESCRIPTION

A series of functions used to render server information

=head1 CONTACT

Contact the EnsEMBL development mailing list for info <ensembl-dev@ebi.ac.uk>

=head1 AUTHOR

Eugene Kulesha, ek3@sanger.ac.uk

=cut

package EnsEMBL::Web::Component::DAS::Reference;

use EnsEMBL::Web::Component::DAS;
our @ISA = qw( EnsEMBL::Web::Component::DAS);
use strict;
use warnings;

my $strand = {
  '1' => '+',
  '0' => '-',
  '-1' => '-'
};

sub entry_points {
    my( $panel, $object ) = @_;

    my $features = $object->EntryPoints();

    my $template = qq{<SEGMENT id="%s" start="%s" stop="%s" orientation="%s">%s</SEGMENT>\n};
    (my $url = lc($ENV{SERVER_PROTOCOL})) =~ s/\/.+//;
    $url .= "://$ENV{SERVER_NAME}";
#    $url .= "\:$ENV{SERVER_PORT}" unless $ENV{SERVER_PORT} == 80;
    $url .="$ENV{REQUEST_URI}";

    $panel->print(sprintf("<ENTRY_POINTS href=\"%s\" version=\"1.0\">\n", $url));

    foreach my $e (@{$features || []}) {
    $panel->print(sprintf($template, @$e));
    }
 
    $panel->print(qq{</ENTRY_POINTS>\n});
}

sub dna {
  my( $panel, $object ) = @_;
  my $segment_tmp = qq{<SEQUENCE id="%s" start="%s" stop="%s" version="1.0">\n};
  my $error_tmp = qq{<ERRORSEGMENT id="%s" start="%s" stop="%s" />\n};

  my $feature_tmp = qq{<DNA length=\"%d\">\n};

  my $features = $object->DNA();

  foreach my $segment (@{$features || []}) {
    if($segment->{'TYPE'} && $segment->{'TYPE'} eq 'ERROR') {
      $panel->print( sprintf ($error_tmp, $segment->{'REGION'}, $segment->{'START'} || '', $segment->{'STOP'} || ''));
      next;
    }
    $panel->print( sprintf ($segment_tmp, $segment->{'REGION'}, $segment->{'START'} || '', $segment->{'STOP'} || ''));
    $panel->print( sprintf ($feature_tmp, $segment->{'STOP'}  - $segment->{'START'} + 1 )); 

    my $block_start = $segment->{'START'}; 
    while($block_start <= $segment->{'STOP'} ) {
      my $block_end = $block_start - 1 + 600000; # do in 600K chunks to simplify memory usage...
      $block_end = $segment->{'STOP'} if $block_end > $segment->{'STOP'};
# warn "$segment->{'REGION'} - $block_start - $block_end";
      my $slice = $object->subslice( $segment->{'REGION'}, $block_start, $block_end );
      my $seq = $slice->seq;
      $seq =~ s/(.{60})/$1\n/g;
      $panel->print( lc($seq) );
      $panel->print( "\n" ) unless $seq =~ /\n$/;
      $block_start = $block_end + 1;
    }
    $panel->print( qq{</DNA>\n</SEQUENCE>\n} );
  }
}

sub sequence {
  my( $panel, $object ) = @_;
  my $segment_tmp = qq{<SEQUENCE id="%s" start="%s" stop="%s" version="1.0">\n};
  my $error_tmp = qq{<ERRORSEGMENT id="%s" start="%s" stop="%s" />\n};

  my $features = $object->DNA();

  foreach my $segment (@{$features || []}) {
    if($segment->{'TYPE'} && $segment->{'TYPE'} eq 'ERROR') {
      $panel->print( sprintf ($error_tmp, $segment->{'REGION'}, $segment->{'START'} || '', $segment->{'STOP'} || ''));
      next;
    }
    $panel->print( sprintf ($segment_tmp, $segment->{'REGION'}, $segment->{'START'} || '', $segment->{'STOP'} || ''));

    my $block_start = $segment->{'START'};
    while($block_start <= $segment->{'STOP'} ) {
      my $block_end = $block_start - 1 + 600000; # do in 600K chunks to simplify memory usage...
      $block_end = $segment->{'STOP'} if $block_end > $segment->{'STOP'};
# warn "$segment->{'REGION'} - $block_start - $block_end";
      my $slice = $object->subslice( $segment->{'REGION'}, $block_start, $block_end );
      my $pattern = '.{60}';
      my $seq = $slice->seq;
      $seq =~ s/(.{60})/$1\n/g;
      $panel->print( lc($seq) );
      $panel->print( "\n" ) unless $seq =~ /\n$/;
      $block_start = $block_end + 1;
    }
    $panel->print( qq{</SEQUENCE>\n} );
  }
}

1;
