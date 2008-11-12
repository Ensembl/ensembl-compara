package EnsEMBL::Web::Component::Variation::FlankingSequence;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Variation);
use CGI qw(escapeHTML);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $html = '';
  ## first check we have a location
 return  unless ($object->core_objects->{'parameters'}{'vf'} );


  ## Add flanking sequence
  my $f_label = "Flanking Sequence";
  my $f_html ;

  my $status   = 'status_ambig_sequence';
  my $URL = _flip_URL( $object, $status );
  #if( $object->param( $status ) eq 'off' ) { $panel->add_row( $label, '', "$URL=on" ); return 0; }

  my $ambig_code = $object->vari->ambig_code;
  unless ($ambig_code) {
    $ambig_code = "[".$object->alleles."]";
  }
  my $downstream = $object->flanking_seq("down");

  #  my $ambiguity_seq = $object->ambiguity_flank;
  # genomic context with ambiguities

  # Make the flanking sequence and wrap it
  $f_html = uc( $object->flanking_seq("up") ) .lc( $ambig_code ).uc( $downstream );
  $f_html =~ s/(.{60})/$1\n/g;
  $f_html =~ s/(([a-z]|\/|-|\[|\])+)/'<span class="alt_allele">'.uc("$1").'<\/span>'/eg;
  $f_html =~ s/\n/\n/g;


  $html .=  qq(<dl class="summary">
      <dt>$f_label</dt>
      <dd><pre>$f_html</pre>
      <blockquote><em>(Variation feature highlighted)</em></blockquote></dd></dl>);


  return $html;
}

sub _flip_URL {
  my( $object, $code ) = @_;
  return sprintf '/%s/%s?snp=%s;db=%s;%s', $object->species, $object->script, $object->name, $object->param('source'), $code;
}

1;
