package EnsEMBL::Web::Document::HTML::RSS;
use strict;
use HTML::Entities qw(encode_entities);
use EnsEMBL::Web::RegObj;
use baseqw(EnsEMBL::Web::Document::HTML);

sub new      {
  return shift->SUPER::new( 'feeds' => {} );
}

sub add      { 
  my( $self, $URL, $title, $type ) = @_;
  $self->{'feeds'}{$URL} = { 'title' => $title, 'type' => $type };
}

sub render   {
  my $self = shift;
  $self->printf(
    '  <link rel="search" href="'.
    $ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_BASE_URL.
    '/opensearchdescription.xml" type="application/opensearchdescription+xml" title="Ensembl" />'.
    "\n"
  );
  foreach (keys %{$self->{'feeds'}}) {
    $self->printf(
      qq(  <link rel="alternate" type="application/%s+xml" title="%s" href="%s" />\n),
      $self->{'feeds'}{$_}{'type'},
      encode_entities($self->{'feeds'}{$_}{'title'}),
      $_ 
    );
  }
}

1;

