=head1 NAME

EnsEMBL::Web::Component::DAS::Annotation

=head1 SYNOPSIS

Show information about the webserver

=head1 DESCRIPTION

A series of functions used to render server information

=head1 CONTACT

Contact the EnsEMBL development mailing list for info <ensembl-dev@ebi.ac.uk>

=head1 AUTHOR

Eugene Kulesha, ek3@sanger.ac.uk

=cut

package EnsEMBL::Web::Component::DAS::Annotation;

use HTML::Entities qw(encode_entities);
use base qw(EnsEMBL::Web::Component::DAS);
use strict;
use warnings;

sub features {
  my( $panel, $model ) = @_;
  my $object = $model->object;

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
  (my $url = lc($ENV{SERVER_PROTOCOL})) =~ s/\/.+//;
  $url .= "://$ENV{SERVER_NAME}";
#  $url .= "\:$ENV{SERVER_PORT}" unless $ENV{SERVER_PORT} == 80;
  $url = $object->species_defs->ENSEMBL_BASE_URL. encode_entities($ENV{REQUEST_URI});
  $panel->print(qq{<GFF version="1.01" href="$url">});
  foreach my $segment (@{$features || []}) {
    if ($segment->{'TYPE'} && $segment->{'TYPE'} eq 'ERROR') {
      $panel->printf( qq(\n<ERRORSEGMENT id="%s" start="%s" stop="%s" />),
        $segment->{'REGION'}, $segment->{'START'} || '', $segment->{'STOP'} || '' );
      next;
    }

    $panel->printf( qq(\n<SEGMENT id="%s" start="%s" stop="%s">),
      $segment->{'REGION'}, $segment->{'START'} || '', $segment->{'STOP'} || '' );

    foreach my $feature (@{$segment->{'FEATURES'} || []}) {
      my $extra_tags = '';

## Firstly dump tag information for each group.....
      foreach my $g (@{$feature->{'GROUP'}||[]}) {
        $extra_tags .= sprintf qq(\n    <GROUP id="%s" %s %s>),
          $g->{'ID'},
          $g->{'TYPE'}  ? qq(type="$g->{'TYPE'}") : '',
          $g->{'LABEL'} ? qq(label="$g->{LABEL}")  : '';
        foreach my $l ( @{$g->{'LINK'}||[]} ) {
          $extra_tags .= sprintf qq(\n      <LINK href="%s">%s</LINK>), encode_entities( $l->{href} ), encode_entities( $l->{text} || $l->{href} );
        }
        foreach my $n ( @{$g->{'NOTE'}||[]} ) {
          $extra_tags .= sprintf qq(\n      <NOTE>%s</NOTE>), encode_entities( $n );
        }
        $extra_tags .= qq(\n    </GROUP>);
      }
      foreach my $l ( @{$feature->{'LINK'}||[]} ) {
        $extra_tags .=  sprintf qq(\n    <LINK href="%s">%s</LINK>), encode_entities( $l->{href} ), encode_entities( $l->{text} || $l->{href} );
      }
      foreach my $n ( @{$feature->{'NOTE'}||[]} ) {
        $extra_tags .= sprintf qq(\n    <NOTE>%s</NOTE>), encode_entities( $n );
      }
      if( exists $feature->{'TARGET'} ) {
        $extra_tags .= sprintf qq(\n    <TARGET id="%s" start="%s" stop="%s" />), encode_entities($feature->{'TARGET'}{'ID'}),$feature->{'TARGET'}{'START'},$feature->{'TARGET'}{'STOP'};
      }
      $panel->printf( $feature_template, 
        $feature->{'ID'}      || '', exists $feature->{'LABEL'}   ? qq( label="$feature->{'LABEL'}") : '',
        $feature->{'START'}   || '',
        $feature->{'END'}     || '',
        $feature->{'TYPE'}    || '', $feature->{'CATEGORY'}   ? qq( category="$feature->{'CATEGORY'}") : '', $feature->{'TYPE'}    || '',
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
  my( $panel, $model ) = @_;
  my $object = $model->object;

  $panel->print($object->Stylesheet());
}

1;
