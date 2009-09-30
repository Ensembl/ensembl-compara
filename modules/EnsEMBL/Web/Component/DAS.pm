=head1 NAME

EnsEMBL::Web::Component::DAS

=head1 SYNOPSIS

Show information about the webserver

=head1 DESCRIPTION

A series of functions used to render server information

=head1 CONTACT

Contact the EnsEMBL development mailing list for info <ensembl-dev@ebi.ac.uk>

=head1 AUTHOR

Eugene Kulesha, ek3@sanger.ac.uk

=cut

package EnsEMBL::Web::Component::DAS;

use EnsEMBL::Web::Component;
our @ISA = qw( EnsEMBL::Web::Component);
use CGI qw(escapeHTML);
use strict;
use warnings;

sub types {
  my( $panel, $object ) = @_;

  my $features = $object->Types();

  my $template = qq{<TYPE id="%s"%s%s>%s</TYPE>\n};
  (my $url = lc($ENV{SERVER_PROTOCOL})) =~ s/\/.+//;
  $url .= "://$ENV{SERVER_NAME}";
#    $url .= "\:$ENV{SERVER_PORT}" unless $ENV{SERVER_PORT} == 80;
  $url .="$ENV{REQUEST_URI}";

  $panel->printf( qq(\n<GFF href=\"%s\" version=\"1.0\">), CGI::escapeHTML($url));

  foreach my $segment (@{$features || []}) {
    if ($segment->{'TYPE'} && $segment->{'TYPE'} eq 'ERROR') {
      if ($segment->{'START'} && $segment->{'END'}) {
        $panel->printf( qq(\n<ERRORSEGMENT id="%s" start="%s" stop="%s" />),
          $segment->{'REGION'}, $segment->{'START'}, $segment->{'STOP'} );
      }
      else {
        $panel->printf( qq(\n<ERRORSEGMENT id="%s" />), $segment->{'REGION'} );
      }
      next;
    }
    if ($segment->{'TYPE'} && $segment->{'TYPE'} eq 'UNKNOWN') {
      if ($segment->{'START'} && $segment->{'END'}) {
        $panel->printf( qq(\n<UNKNOWNSEGMENT id="%s" start="%s" stop="%s" />),
          $segment->{'REGION'}, $segment->{'START'} || '', $segment->{'STOP'} || '' );
      }
      else {
        $panel->printf( qq(\n<UNKNOWNSEGMENT id="%s" />), $segment->{'REGION'} );
      }
      next;
    }
    if( $segment->{'REGION'} ) { 
      $panel->printf( qq(\n<SEGMENT id="%s" start="%s" stop="%s"%s>),
        $segment->{'REGION'}, $segment->{'START'} || '', $segment->{'STOP'} || '',
        $segment->{'TYPE'} ? qq( type="$segment->{'TYPE'}") : '' );
    } else {
      $panel->print( qq(\n<SEGMENT>) );
    }
    foreach my $feature (@{$segment->{'FEATURES'}||[]}) {
      my $extra = '';
      $extra .= qq( method="$feature->{'method'}")     if exists $feature->{'method'};
      $extra .= qq( category="$feature->{'category'}") if exists $feature->{'category'};
      $panel->printf( qq(\n  <TYPE id="%s"%s>%s</TYPE>), $feature->{'id'}, $extra, $feature->{'text'});
    }
    $panel->print( qq(\n</SEGMENT>) );
  }
  $panel->print( qq(\n</GFF>\n) );
}

sub features {
  my( $panel, $object ) = @_;

  my $feature_template = qq(
  <FEATURE id="%s"%s>
    <START>%d</START>
    <END>%d</END>
    <TYPE id="%s"%s>%s</TYPE>
    <METHOD id="%s">%s</METHOD>
    <SCORE>%s</SCORE>
    <ORIENTATION>%s</ORIENTATION>%s
  </FEATURE>);

  my $features = $object->Features();
  my $url = $object->species_defs->ENSEMBL_BASE_URL. CGI->escapeHTML($ENV{REQUEST_URI});
  $panel->print(qq{<GFF version="1.01" href="$url">});
  foreach my $segment (@{$features || []}) {
    if ($segment->{'TYPE'} && $segment->{'TYPE'} eq 'ERROR') {
      $panel->printf( qq(\n<ERRORSEGMENT id="%s" start="%s" stop="%s" />),
        $segment->{'REGION'}, $segment->{'START'} || '', $segment->{'STOP'} || '' );
      next;
    }
    if ($segment->{'TYPE'} && $segment->{'TYPE'} eq 'UNKNOWN') {
      $panel->printf( qq(\n<UNKNOWNSEGMENT id="%s" start="%s" stop="%s" />),
        $segment->{'REGION'}, $segment->{'START'} || '', $segment->{'STOP'} || '' );
      next;
    }

    $panel->printf( qq(\n<SEGMENT id="%s" start="%s" stop="%s"%s>),
      $segment->{'REGION'}, $segment->{'START'} || '', $segment->{'STOP'} || '' ,
      $segment->{'TYPE'} ? qq( type="$segment->{'TYPE'}") : '' );

    foreach my $feature (@{$segment->{'FEATURES'} || []}) {
      my $extra_tags = '';

## Firstly dump tag information for each group.....
      foreach my $g (@{$feature->{'GROUP'}||[]}) {
        $extra_tags .= sprintf qq(\n    <GROUP id="%s" %s %s>),
          $g->{'ID'},
          $g->{'TYPE'}  ? qq(type="$g->{'TYPE'}") : '',
          $g->{'LABEL'} ? qq(label="$g->{LABEL}")  : '';
        foreach my $l ( @{$g->{'LINK'}||[]} ) {
          $extra_tags .= sprintf qq(\n      <LINK href="%s">%s</LINK>), CGI::escapeHTML( $l->{href} ), CGI::escapeHTML( $l->{text} || $l->{href} );
        }
        foreach my $n ( @{$g->{'NOTE'}||[]} ) {
          $extra_tags .= sprintf qq(\n      <NOTE>%s</NOTE>), CGI::escapeHTML( $n );
        }
        $extra_tags .= qq(\n    </GROUP>);
      }
      foreach my $l ( @{$feature->{'LINK'}||[]} ) {
        $extra_tags .=  sprintf qq(\n    <LINK href="%s">%s</LINK>), CGI::escapeHTML( $l->{href} ), CGI::escapeHTML( $l->{text} || $l->{href} );
      }
      foreach my $n ( @{$feature->{'NOTE'}||[]} ) {
        $extra_tags .= sprintf qq(\n    <NOTE>%s</NOTE>), CGI::escapeHTML( $n );
      }
      if( exists $feature->{'TARGET'} ) {
        $extra_tags .= sprintf qq(\n    <TARGET id="%s" start="%s" stop="%s" />), CGI::escapeHTML($feature->{'TARGET'}{'ID'}),$feature->{'TARGET'}{'START'},$feature->{'TARGET'}{'STOP'};
      }
      my $extra_type = '';
      if( $feature->{'REFERENCE'} ) {
        $extra_type .= sprintf qq( reference="yes" superparts="%s" subparts="%s"), $feature->{'SUPERPARTS'} || 'no', $feature->{'SUBPARTS'} || 'no';
      }
      $extra_type .= qq( category="$feature->{'CATEGORY'}") if exists $feature->{'CATEGORY'};
      $panel->printf( $feature_template,
        $feature->{'ID'}      || '', exists $feature->{'LABEL'}   ? qq( label="$feature->{'LABEL'}") : '',
        $feature->{'START'}   || '',
        $feature->{'END'}     || '',
        $feature->{'TYPE'}    || '', $extra_type, $feature->{'TYPE'}    || '',
        $feature->{'METHOD'}  || '', $feature->{'METHOD'}    || '',
        $feature->{'SCORE'}   || '-',
        $feature->{'ORIENTATION'} || '.',
        $extra_tags
      );
    }
    $panel->print( qq(\n</SEGMENT>) );
  }
  $panel->print( qq(\n</GFF>\n) );
}

sub stylesheet {
  my( $panel, $object ) = @_;
  $panel->print($object->Stylesheet());
}

1;
